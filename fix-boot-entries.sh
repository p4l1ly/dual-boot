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

# Mount boot partition (no password needed!)
BOOT_MOUNT="/mnt/arch-boot"
if ! mountpoint -q "$BOOT_MOUNT"; then
    echo "Mounting boot partition (no password needed)..."
    mkdir -p "$BOOT_MOUNT"
    mount "$BOOT_PART" "$BOOT_MOUNT"
    
    # Also mount EFI if needed for bootctl commands
    mkdir -p "$BOOT_MOUNT/efi"
    mount "$EFI_PART" "$BOOT_MOUNT/efi"
    echo "✓ Boot partition mounted at $BOOT_MOUNT"
fi

echo "Checking boot configuration..."
echo

# Check what's in /boot
echo "Files in /boot:"
ls -lh $BOOT_MOUNT/*.img $BOOT_MOUNT/vmlinuz-* 2>/dev/null || echo "  No kernel files found!"
echo

# Check what's in /boot/efi
echo "Files in /boot/efi:"
ls -lh $BOOT_MOUNT/efi/*.img $BOOT_MOUNT/efi/vmlinuz-* 2>/dev/null || echo "  No kernel files in EFI partition (this is OK)"
echo

# Check loader configuration
echo "Loader configuration (/boot/loader/loader.conf):"
if [[ -f $BOOT_MOUNT/loader/loader.conf ]]; then
    cat $BOOT_MOUNT/loader/loader.conf
else
    echo "  NOT FOUND!"
fi
echo

# Check boot entries
echo "Boot entries in /boot/loader/entries/:"
ls -la $BOOT_MOUNT/loader/entries/ 2>/dev/null || echo "  Directory not found!"
echo

if [[ -f $BOOT_MOUNT/loader/entries/arch.conf ]]; then
    echo "Content of arch.conf:"
    cat $BOOT_MOUNT/loader/entries/arch.conf
    echo
else
    echo "arch.conf NOT FOUND!"
    echo
fi

# Check if kernels exist
KERNEL_EXISTS=false
INITRD_EXISTS=false
UCODE_EXISTS=false

if [[ -f $BOOT_MOUNT/vmlinuz-linux ]]; then
    KERNEL_EXISTS=true
    echo "✓ Kernel found: /boot/vmlinuz-linux"
else
    echo "✗ Kernel NOT found: /boot/vmlinuz-linux"
fi

if [[ -f $BOOT_MOUNT/initramfs-linux.img ]]; then
    INITRD_EXISTS=true
    echo "✓ Initramfs found: /boot/initramfs-linux.img"
else
    echo "✗ Initramfs NOT found: /boot/initramfs-linux.img"
fi

if [[ -f $BOOT_MOUNT/intel-ucode.img ]]; then
    UCODE_EXISTS=true
    echo "✓ Microcode found: /boot/intel-ucode.img"
else
    echo "✗ Microcode NOT found: /boot/intel-ucode.img"
fi

echo

# If files missing, they need to be regenerated from within the installed system
if ! $KERNEL_EXISTS || ! $INITRD_EXISTS; then
    echo "⚠ Required kernel files are missing!"
    echo "You'll need to boot from the Arch USB and run:"
    echo "  1. Mount root: cryptsetup open /dev/nvme0n1p6 root && mount /dev/mapper/root /mnt"
    echo "  2. Mount boot: mount /dev/nvme0n1p5 /mnt/boot"  
    echo "  3. Reinstall: arch-chroot /mnt pacman -S --noconfirm linux"
    echo "  4. Regenerate: arch-chroot /mnt mkinitcpio -P"
    echo
    echo "For now, let's create the boot entries anyway..."
    echo
fi

# Ensure loader configuration exists
if [[ ! -f $BOOT_MOUNT/loader/loader.conf ]]; then
    echo "Creating loader configuration..."
    mkdir -p $BOOT_MOUNT/loader
    cat > $BOOT_MOUNT/loader/loader.conf << 'EOF'
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
mkdir -p $BOOT_MOUNT/loader/entries

cat > $BOOT_MOUNT/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options cryptdevice=UUID=$ROOT_UUID:root root=/dev/mapper/root resume=UUID=$SWAP_UUID rw
EOF
echo "✓ Created arch.conf"

cat > $BOOT_MOUNT/loader/entries/arch-fallback.conf << EOF
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
ls -la $BOOT_MOUNT/loader/entries/

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
    umount -R $BOOT_MOUNT 2>/dev/null || true
    rmdir $BOOT_MOUNT 2>/dev/null || true
    reboot
else
    echo "Boot partition still mounted at $BOOT_MOUNT. Unmount with:"
    echo "  umount -R $BOOT_MOUNT"
fi
