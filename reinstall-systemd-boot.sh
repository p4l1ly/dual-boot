#!/bin/bash

set -euo pipefail

echo "=== Reinstall systemd-boot (no chroot needed) ==="

# Require root
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root" >&2
	exit 1
fi

DISK="/dev/nvme0n1"
EFI_PART="/dev/nvme0n1p1"     # ESP (FAT32)
BOOT_PART="/dev/nvme0n1p5"    # XBOOTLDR (FAT32)
ROOT_PART="/dev/nvme0n1p6"    # Not used here
SWAP_PART="/dev/nvme0n1p8"    # For resume UUID

EFI_MOUNT="/mnt/efi"
BOOT_MOUNT="/mnt/boot"

mkdir -p "$EFI_MOUNT" "$BOOT_MOUNT"

# Mount ESP
if ! mountpoint -q "$EFI_MOUNT"; then
	mount "$EFI_PART" "$EFI_MOUNT"
fi

# Mount XBOOTLDR
if ! mountpoint -q "$BOOT_MOUNT"; then
	mount "$BOOT_PART" "$BOOT_MOUNT"
fi

echo
echo "ESP mounted at:   $EFI_MOUNT"
echo "BOOT mounted at:  $BOOT_MOUNT"

# Verify filesystems
EFI_FS=$(blkid -s TYPE -o value "$EFI_PART" || true)
BOOT_FS=$(blkid -s TYPE -o value "$BOOT_PART" || true)

echo "ESP fs:  ${EFI_FS:-unknown}"
echo "BOOT fs: ${BOOT_FS:-unknown}"

if [[ "$EFI_FS" != vfat ]]; then
	echo "ERROR: ESP ($EFI_PART) is not vfat. Aborting." >&2
	exit 1
fi
if [[ "$BOOT_FS" != vfat ]]; then
	echo "ERROR: XBOOTLDR ($BOOT_PART) is not vfat. Re-run partition-setup to format p5 as FAT32." >&2
	exit 1
fi

# Ensure directories exist on BOOT
mkdir -p "$BOOT_MOUNT/loader/entries"

# Reinstall systemd-boot directly using explicit paths
# This copies systemd-bootx64.efi to ESP and prepares loader dirs under BOOT
if ! bootctl --esp-path="$EFI_MOUNT" --boot-path="$BOOT_MOUNT" install; then
	echo "bootctl install failed. Check that systemd is installed on the live ISO and Secure Boot is disabled." >&2
	exit 1
fi

echo "✓ systemd-boot installed"

# Build loader.conf
cat > "$BOOT_MOUNT/loader/loader.conf" << 'EOF'
default  arch.conf
timeout  4
console-mode max
editor   no
EOF

echo "✓ loader.conf written"

# Gather UUIDs for entries
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART" || true)
SWAP_UUID=$(blkid -s UUID -o value "$SWAP_PART" || true)

if [[ -z "$ROOT_UUID" || -z "$SWAP_UUID" ]]; then
	echo "WARNING: Could not determine ROOT/SWAP UUIDs. Entries will still be created; adjust later if needed."
fi

# Create entries
cat > "$BOOT_MOUNT/loader/entries/arch.conf" << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options cryptdevice=UUID=${ROOT_UUID:-<ROOT-UUID>}:root root=/dev/mapper/root resume=UUID=${SWAP_UUID:-<SWAP-UUID>} rw
EOF

cat > "$BOOT_MOUNT/loader/entries/arch-fallback.conf" << EOF
title   Arch Linux (fallback initramfs)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options cryptdevice=UUID=${ROOT_UUID:-<ROOT-UUID>}:root root=/dev/mapper/root resume=UUID=${SWAP_UUID:-<SWAP-UUID>} rw
EOF

echo "✓ loader entries written"

# Ensure a UEFI NVRAM entry exists and is first
if ! efibootmgr | grep -q "Linux Boot Manager"; then
	efibootmgr --create \
		--disk "$DISK" \
		--part 1 \
		--label "Linux Boot Manager" \
		--loader '\EFI\systemd\systemd-bootx64.efi' || true
fi

# Move Linux Boot Manager first in the order
LBL_NUM=$(efibootmgr | awk '/Linux Boot Manager/{print substr($1,5,4)}' | head -n1 || true)
if [[ -n "${LBL_NUM:-}" ]]; then
	CUR_ORDER=$(efibootmgr | awk -F' ' '/BootOrder/{print $2}')
	NEW_ORDER="$LBL_NUM,${CUR_ORDER//$LBL_NUM,}"
	efibootmgr --bootorder "$NEW_ORDER" || true
	echo "✓ Set Linux Boot Manager (Boot$LBL_NUM) first"
else
	echo "WARNING: Could not find Linux Boot Manager in NVRAM. Some firmwares require manual selection in BIOS."
fi

echo
echo "Contents of $EFI_MOUNT/EFI/systemd:"
ls -la "$EFI_MOUNT/EFI/systemd" || true

echo
echo "Loader entries:"
ls -la "$BOOT_MOUNT/loader/entries" || true

# Advise on Secure Boot
echo
echo "NOTE: Ensure Secure Boot is disabled in BIOS on Dell XPS 9350 (systemd-boot is not signed)."

# Offer unmount
echo
read -r -p "Unmount EFI and BOOT mounts now? (Y/n): " UNM
if [[ ! "$UNM" =~ ^[Nn]$ ]]; then
	umount -R "$BOOT_MOUNT" 2>/dev/null || true
	umount -R "$EFI_MOUNT" 2>/dev/null || true
	echo "✓ Unmounted"
else
	echo "Mounts left in place: $EFI_MOUNT, $BOOT_MOUNT"
fi

echo "=== Done. Reboot and test systemd-boot ==="
