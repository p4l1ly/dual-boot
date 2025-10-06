#!/bin/bash
# Clean up EFI partition before reinstalling Arch Linux

set -e

echo "=== Cleaning EFI Partition for Reinstall ==="
echo
echo "This will remove Linux-related files from the EFI partition"
echo "while preserving Windows and Dell firmware files."
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

EFI_PART="/dev/nvme0n1p1"
EFI_MOUNT="/mnt/efi"

# Mount EFI partition
echo "Mounting EFI partition..."
mkdir -p "$EFI_MOUNT"
mount "$EFI_PART" "$EFI_MOUNT" 2>/dev/null || {
    echo "EFI partition already mounted or mount failed"
    echo "Checking if it's already mounted..."
    if mountpoint -q "$EFI_MOUNT"; then
        echo "✓ Already mounted at $EFI_MOUNT"
    else
        echo "✗ Failed to mount. Is the partition correct?"
        exit 1
    fi
}

echo
echo "Current contents of EFI partition:"
ls -la "$EFI_MOUNT"
echo

echo "What will be preserved:"
echo "  ✓ EFI/Microsoft/ (Windows Boot Manager)"
echo "  ✓ EFI/Dell/ (Dell firmware)"
echo "  ✓ EFI/Boot/ (fallback bootloader)"
echo "  ✓ System Volume Information (Windows)"
echo

echo "What will be removed:"
echo "  ✗ EFI/systemd/ (systemd-boot binaries)"
echo "  ✗ linux/ (if exists)"
echo "  ✗ loader/ (boot entries)"
echo "  ✗ Any kernel files (vmlinuz-*, initramfs-*, intel-ucode.img)"
echo

echo -n "Continue with cleanup? (y/N): "
read -r CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    umount "$EFI_MOUNT" 2>/dev/null || true
    exit 0
fi

echo
echo "Removing Linux files from EFI partition..."

# Remove systemd-boot
if [[ -d "$EFI_MOUNT/EFI/systemd" ]]; then
    echo "  Removing EFI/systemd/..."
    rm -rf "$EFI_MOUNT/EFI/systemd"
fi

# Remove linux directory
if [[ -d "$EFI_MOUNT/linux" ]]; then
    echo "  Removing linux/..."
    rm -rf "$EFI_MOUNT/linux"
fi

# Remove loader directory
if [[ -d "$EFI_MOUNT/loader" ]]; then
    echo "  Removing loader/..."
    rm -rf "$EFI_MOUNT/loader"
fi

# Remove kernel files if they exist
echo "  Removing any kernel files..."
rm -f "$EFI_MOUNT/vmlinuz-linux" 2>/dev/null || true
rm -f "$EFI_MOUNT/initramfs-linux.img" 2>/dev/null || true
rm -f "$EFI_MOUNT/initramfs-linux-fallback.img" 2>/dev/null || true
rm -f "$EFI_MOUNT/intel-ucode.img" 2>/dev/null || true

echo
echo "✓ Cleanup complete!"
echo

echo "Remaining contents:"
ls -la "$EFI_MOUNT"
echo

# Also remove UEFI boot entry for Linux Boot Manager
echo "Removing UEFI boot entry for Linux Boot Manager..."
LINUX_BOOT_NUMS=$(efibootmgr | grep "Linux Boot Manager" | cut -c5-8 || true)
if [[ -n "$LINUX_BOOT_NUMS" ]]; then
    for NUM in $LINUX_BOOT_NUMS; do
        echo "  Removing Boot$NUM..."
        efibootmgr -b "$NUM" -B || true
    done
    echo "✓ UEFI entries removed"
else
    echo "  No Linux Boot Manager entries found"
fi

echo
echo "Current UEFI boot order:"
efibootmgr
echo

echo -n "Unmount EFI partition? (y/N): "
read -r UNMOUNT
if [[ "$UNMOUNT" =~ ^[Yy]$ ]]; then
    umount "$EFI_MOUNT"
    echo "✓ Unmounted"
else
    echo "EFI partition still mounted at $EFI_MOUNT"
fi

echo
echo "=== EFI Partition Ready for Reinstall ==="
echo
echo "You can now run:"
echo "  1. ./partition-setup.sh (if you need to reformat partitions)"
echo "  2. ./arch-install.sh (to install Arch Linux)"

