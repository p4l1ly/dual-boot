#!/bin/bash

# Fix boot entries to use PARTUUID instead of UUID

set -e

echo "=== Fix Boot Entries - Use PARTUUID ==="

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

DISK="/dev/nvme0n1"
BOOT_PART="/dev/nvme0n1p5"
ROOT_PART="/dev/nvme0n1p6"
SWAP_PART="/dev/nvme0n1p8"

BOOT_MOUNT="/mnt/boot"

# Mount boot partition
mkdir -p "$BOOT_MOUNT"
if ! mountpoint -q "$BOOT_MOUNT"; then
    mount "$BOOT_PART" "$BOOT_MOUNT"
    echo "✓ Boot partition mounted"
fi

# Get correct UUIDs
echo "Getting partition identifiers..."
ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_PART")
echo "Root PARTUUID: $ROOT_PARTUUID"

# Try to open swap to get its UUID
if [[ ! -b /dev/mapper/swap ]]; then
    echo "Opening swap container to get UUID..."
    echo "Enter LUKS password:"
    cryptsetup open "$SWAP_PART" swap
    SWAP_UUID=$(blkid -s UUID -o value /dev/mapper/swap)
    echo "Swap UUID: $SWAP_UUID"
    cryptsetup close swap
else
    SWAP_UUID=$(blkid -s UUID -o value /dev/mapper/swap)
    echo "Swap UUID: $SWAP_UUID"
fi

# Update boot entries
echo
echo "Updating boot entries..."

cat > "$BOOT_MOUNT/loader/entries/arch.conf" << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options cryptdevice=PARTUUID=$ROOT_PARTUUID:root root=/dev/mapper/root resume=UUID=$SWAP_UUID rw
EOF

cat > "$BOOT_MOUNT/loader/entries/arch-fallback.conf" << EOF
title   Arch Linux (fallback initramfs)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options cryptdevice=PARTUUID=$ROOT_PARTUUID:root root=/dev/mapper/root resume=UUID=$SWAP_UUID rw
EOF

echo "✓ Boot entries updated"
echo

echo "Verifying entries:"
echo "--- arch.conf ---"
cat "$BOOT_MOUNT/loader/entries/arch.conf"
echo
echo "--- arch-fallback.conf ---"
cat "$BOOT_MOUNT/loader/entries/arch-fallback.conf"
echo

read -p "Unmount boot partition? (Y/n): " -r UNM
if [[ ! "$UNM" =~ ^[Nn]$ ]]; then
    umount "$BOOT_MOUNT"
    echo "✓ Unmounted"
fi

echo
echo "=== Done ==="
echo "The boot entries now use PARTUUID for cryptdevice."
echo "Reboot and test!"

