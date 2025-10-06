#!/bin/bash

# Fix systemd-boot entries - ensure kernels and configs are in the right place

set -e

echo "=== Fixing systemd-boot Boot Entries ==="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

DISK="/dev/nvme0n1"
EFI_PART="/dev/nvme0n1p1"
BOOT_PART="/dev/nvme0n1p5"
ROOT_PART="/dev/nvme0n1p6"

# Mount if needed
if ! mountpoint -q /install; then
    echo "Mounting partitions..."
    cryptsetup open "$ROOT_PART" root 2>/dev/null || true
    mkdir -p /install
    mount /dev/mapper/root /install
    mount "$BOOT_PART" /install/boot
    mount "$EFI_PART" /install/boot/efi
fi

echo "Checking boot configuration..."
echo

# Check what's in /boot
echo "Files in /boot:"
ls -lh /install/boot/*.img /install/boot/vmlinuz-* 2>/dev/null || echo "  No kernel files found!"
echo

# Check what's in /boot/efi
echo "Files in /boot/efi:"
ls -lh /install/boot/efi/*.img /install/boot/efi/vmlinuz-* 2>/dev/null || echo "  No kernel files in EFI partition (this is OK)"
echo

# Check loader configuration
echo "Loader configuration (/boot/loader/loader.conf):"
if [[ -f /install/boot/loader/loader.conf ]]; then
    cat /install/boot/loader/loader.conf
else
    echo "  NOT FOUND!"
fi
echo

# Check boot entries
echo "Boot entries in /boot/loader/entries/:"
ls -la /install/boot/loader/entries/ 2>/dev/null || echo "  Directory not found!"
echo

if [[ -f /install/boot/loader/entries/arch.conf ]]; then
    echo "Content of arch.conf:"
    cat /install/boot/loader/entries/arch.conf
    echo
else
    echo "arch.conf NOT FOUND!"
    echo
fi

# Check if kernels exist
KERNEL_EXISTS=false
INITRD_EXISTS=false
UCODE_EXISTS=false

if [[ -f /install/boot/vmlinuz-linux ]]; then
    KERNEL_EXISTS=true
    echo "✓ Kernel found: /boot/vmlinuz-linux"
else
    echo "✗ Kernel NOT found: /boot/vmlinuz-linux"
fi

if [[ -f /install/boot/initramfs-linux.img ]]; then
    INITRD_EXISTS=true
    echo "✓ Initramfs found: /boot/initramfs-linux.img"
else
    echo "✗ Initramfs NOT found: /boot/initramfs-linux.img"
fi

if [[ -f /install/boot/intel-ucode.img ]]; then
    UCODE_EXISTS=true
    echo "✓ Microcode found: /boot/intel-ucode.img"
else
    echo "✗ Microcode NOT found: /boot/intel-ucode.img"
fi

echo

# If files missing, check if they need to be regenerated
if ! $KERNEL_EXISTS || ! $INITRD_EXISTS; then
    echo "⚠ Required files missing!"
    echo "Reinstalling kernel and regenerating initramfs..."
    arch-chroot /install pacman -S --noconfirm linux
    arch-chroot /install mkinitcpio -P
    echo "✓ Kernel reinstalled and initramfs regenerated"
    echo
fi

# Ensure loader configuration exists
if [[ ! -f /install/boot/loader/loader.conf ]]; then
    echo "Creating loader configuration..."
    mkdir -p /install/boot/loader
    cat > /install/boot/loader/loader.conf << 'EOF'
default  arch.conf
timeout  4
console-mode max
editor   no
EOF
    echo "✓ Created /boot/loader/loader.conf"
fi

# Get UUIDs
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
SWAP_PART="/dev/nvme0n1p8"
SWAP_UUID=$(blkid -s UUID -o value "$SWAP_PART")

echo "Root UUID: $ROOT_UUID"
echo "Swap UUID: $SWAP_UUID"
echo

# Create/fix boot entries
echo "Creating boot entries..."
mkdir -p /install/boot/loader/entries

cat > /install/boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options cryptdevice=UUID=$ROOT_UUID:root root=/dev/mapper/root resume=UUID=$SWAP_UUID rw
EOF
echo "✓ Created arch.conf"

cat > /install/boot/loader/entries/arch-fallback.conf << EOF
title   Arch Linux (fallback initramfs)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options cryptdevice=UUID=$ROOT_UUID:root root=/dev/mapper/root resume=UUID=$SWAP_UUID rw
EOF
echo "✓ Created arch-fallback.conf"

echo

# Verify everything
echo "Verifying boot configuration..."
arch-chroot /install bootctl list || true

echo
echo "=== Done ==="
echo
echo "Boot entries created. After reboot, you should see:"
echo "  - Arch Linux"
echo "  - Arch Linux (fallback initramfs)"
echo "  - Windows Boot Manager"
echo "  - Reboot Into Firmware Interface"
echo
echo -n "Unmount and reboot now? (y/N): "
read -r REBOOT
if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
    umount -R /install
    cryptsetup close root
    reboot
fi
