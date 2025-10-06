#!/bin/bash

set -euo pipefail

echo "=== Reinstall systemd-boot (simplified single ESP) ==="

# Require root
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root" >&2
	exit 1
fi

DISK="/dev/nvme0n1"
BOOT_PART="/dev/nvme0n1p5"    # Linux ESP (FAT32, 512MB)
ROOT_PART="/dev/nvme0n1p6"    # For UUID
SWAP_PART="/dev/nvme0n1p8"    # For resume UUID

BOOT_MOUNT="/mnt/boot"

mkdir -p "$BOOT_MOUNT"

# Mount Linux ESP
if ! mountpoint -q "$BOOT_MOUNT"; then
	mount "$BOOT_PART" "$BOOT_MOUNT"
fi

echo
echo "Linux ESP (p5) mounted at: $BOOT_MOUNT"

# Verify filesystem
BOOT_FS=$(blkid -s TYPE -o value "$BOOT_PART" || true)
echo "Boot fs: ${BOOT_FS:-unknown}"

if [[ "$BOOT_FS" != vfat ]]; then
	echo "ERROR: Boot partition ($BOOT_PART) is not vfat. Re-run partition-setup to format p5 as FAT32." >&2
	exit 1
fi

# Ensure directories exist
mkdir -p "$BOOT_MOUNT/loader/entries"

# Reinstall systemd-boot to p5
if ! bootctl --esp-path="$BOOT_MOUNT" install; then
	echo "bootctl install failed. Check that systemd is installed on the live ISO and Secure Boot is disabled." >&2
	exit 1
fi

echo "✓ systemd-boot installed to p5"

# Build loader.conf
cat > "$BOOT_MOUNT/loader/loader.conf" << 'EOF'
default  arch.conf
timeout  4
console-mode max
editor   no
EOF

echo "✓ loader.conf written"

# Gather UUIDs for entries
ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_PART" || true)

# Try to get swap UUID from opened mapper (if available)
if [[ -b /dev/mapper/swap ]]; then
	SWAP_UUID=$(blkid -s UUID -o value /dev/mapper/swap || true)
else
	SWAP_UUID=""
	echo "WARNING: /dev/mapper/swap not open. Swap resume may not work until you update the boot entry."
fi

if [[ -z "$ROOT_PARTUUID" ]]; then
	echo "WARNING: Could not determine ROOT PARTUUID. Entries will use placeholder."
fi

# Create entries
cat > "$BOOT_MOUNT/loader/entries/arch.conf" << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options cryptdevice=PARTUUID=${ROOT_PARTUUID:-<ROOT-PARTUUID>}:root root=/dev/mapper/root resume=UUID=${SWAP_UUID:-<SWAP-UUID>} rw
EOF

cat > "$BOOT_MOUNT/loader/entries/arch-fallback.conf" << EOF
title   Arch Linux (fallback initramfs)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options cryptdevice=PARTUUID=${ROOT_PARTUUID:-<ROOT-PARTUUID>}:root root=/dev/mapper/root resume=UUID=${SWAP_UUID:-<SWAP-UUID>} rw
EOF

echo "✓ loader entries written"

# Ensure a UEFI NVRAM entry exists and is first (pointing to p5)
if ! efibootmgr | grep -q "Linux Boot Manager"; then
	efibootmgr --create \
		--disk "$DISK" \
		--part 5 \
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
echo "Contents of Linux ESP:"
ls -la "$BOOT_MOUNT/EFI/systemd/" || true

echo
echo "Loader entries:"
ls -la "$BOOT_MOUNT/loader/entries/" || true

# Advise on Secure Boot
echo
echo "NOTE: Ensure Secure Boot is disabled in BIOS on Dell XPS 9350 (systemd-boot is not signed)."
echo "Linux uses p5 as ESP, Windows uses p1 - completely separate"

# Offer unmount
echo
read -r -p "Unmount boot partition now? (Y/n): " UNM
if [[ ! "$UNM" =~ ^[Nn]$ ]]; then
	umount -R "$BOOT_MOUNT" 2>/dev/null || true
	echo "✓ Unmounted"
else
	echo "Mount left in place: $BOOT_MOUNT"
fi

echo "=== Done. Reboot and test systemd-boot ==="
