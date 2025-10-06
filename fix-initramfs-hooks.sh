#!/bin/bash

# Fix mkinitcpio hooks for LUKS encryption prompt

set -e

echo "=== Fix initramfs hooks for LUKS password prompt ==="
echo

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

ROOT_PART="/dev/nvme0n1p6"

# Mount root partition
if [[ ! -d /mnt ]]; then
    mkdir -p /mnt
fi

if ! mountpoint -q /mnt; then
    echo "Opening root LUKS container..."
    echo "Enter LUKS password:"
    cryptsetup open "$ROOT_PART" root
    
    echo "Mounting root partition..."
    mount /dev/mapper/root /mnt
fi

# Mount boot partition
if [[ ! -d /mnt/boot ]]; then
    mkdir -p /mnt/boot
fi

if ! mountpoint -q /mnt/boot; then
    echo "Mounting boot partition..."
    mount /dev/nvme0n1p5 /mnt/boot
fi

echo "✓ Partitions mounted"
echo

# Show current hooks
echo "Current HOOKS configuration:"
grep "^HOOKS=" /mnt/etc/mkinitcpio.conf
echo

# Fix hooks
echo "Updating mkinitcpio.conf..."
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt lvm2 resume filesystems fsck)/' /mnt/etc/mkinitcpio.conf

echo "New HOOKS configuration:"
grep "^HOOKS=" /mnt/etc/mkinitcpio.conf
echo

# Regenerate initramfs
echo "Regenerating initramfs..."
arch-chroot /mnt mkinitcpio -P

echo "✓ initramfs regenerated"
echo

# Cleanup
read -p "Unmount and close LUKS? (Y/n): " -r CLEANUP
if [[ ! "$CLEANUP" =~ ^[Nn]$ ]]; then
    umount /mnt/boot
    umount /mnt
    cryptsetup close root
    echo "✓ Cleaned up"
fi

echo
echo "=== Done ==="
echo "The initramfs now has the correct hook order:"
echo "  - keyboard/keymap before encrypt (so you can type)"
echo "  - encrypt before filesystems (so root can be decrypted)"
echo
echo "Reboot and you should see a password prompt!"

