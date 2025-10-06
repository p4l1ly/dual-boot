#!/bin/bash

# Fix systemd-boot installation and UEFI boot order

set -e

echo "=== systemd-boot Boot Fix ==="
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

# Check if partitions are already mounted
if mountpoint -q /install; then
    echo "✓ Partitions already mounted"
else
    echo "Mounting partitions..."
    
    # Open LUKS containers if needed
    if [[ ! -b /dev/mapper/root ]]; then
        echo "Opening root LUKS container..."
        cryptsetup open "$ROOT_PART" root
    fi
    
    # Create mount point
    mkdir -p /install
    
    # Mount root
    mount /dev/mapper/root /install
    
    # Mount boot
    mkdir -p /install/boot
    mount "$BOOT_PART" /install/boot
    
    # Mount EFI
    mkdir -p /install/boot/efi
    mount "$EFI_PART" /install/boot/efi
    
    echo "✓ Partitions mounted"
fi
echo

# Check current boot order
echo "Current UEFI boot order:"
efibootmgr -v
echo

# Check if systemd-boot is installed
echo "Checking systemd-boot installation:"
if [[ -f "/install/boot/efi/EFI/systemd/systemd-bootx64.efi" ]]; then
    echo "✓ systemd-boot binary found"
else
    echo "✗ systemd-boot binary NOT found"
    echo "  Installing systemd-boot..."
    arch-chroot /install bootctl install
fi
echo

# Check if boot entries exist
echo "Checking boot entries:"
if [[ -f "/install/boot/loader/entries/arch.conf" ]]; then
    echo "✓ Boot entry exists"
    cat /install/boot/loader/entries/arch.conf
else
    echo "✗ Boot entry NOT found"
fi
echo

# Try to create UEFI boot entry manually
echo "Creating UEFI boot entry for systemd-boot..."
efibootmgr --create \
    --disk /dev/nvme0n1 \
    --part 1 \
    --label "Linux Boot Manager" \
    --loader '\EFI\systemd\systemd-bootx64.efi'

echo
echo "New boot order:"
efibootmgr -v
echo

# Set Linux Boot Manager as first in boot order
LINUX_BOOT=$(efibootmgr | grep "Linux Boot Manager" | cut -c5-8)
if [[ -n "$LINUX_BOOT" ]]; then
    echo "Setting Linux Boot Manager (Boot$LINUX_BOOT) as first boot option..."
    CURRENT_ORDER=$(efibootmgr | grep BootOrder | cut -d' ' -f2)
    NEW_ORDER="$LINUX_BOOT,${CURRENT_ORDER//$LINUX_BOOT,/}"
    efibootmgr --bootorder "$NEW_ORDER"
    echo
    echo "Updated boot order:"
    efibootmgr
fi

echo
echo "=== Done ==="

# Ask if user wants to unmount
echo
echo -n "Unmount partitions now? (Y/n): "
read -r UNMOUNT
if [[ ! "$UNMOUNT" =~ ^[Nn]$ ]]; then
    echo "Unmounting partitions..."
    umount -R /install 2>/dev/null || true
    cryptsetup close root 2>/dev/null || true
    echo "✓ Unmounted"
fi

echo
echo "Please reboot and check if systemd-boot menu appears"
echo "You should see a menu with 'Arch Linux' and 'Arch Linux (fallback)' options"
