#!/bin/bash
set -e

echo "=== Setting up XBOOTLDR for systemd-boot ==="
echo

# Partition definitions
DISK="/dev/nvme0n1"
EFI_PART="${DISK}p1"
BOOT_PART="${DISK}p5"

echo "This script will:"
echo "1. Set p5 partition type to XBOOTLDR (Linux Extended Boot)"
echo "2. Mount both EFI and boot partitions correctly"
echo "3. Copy loader config to EFI partition"
echo "4. Verify systemd-boot can find everything"
echo

echo -n "Continue? (y/N): "
read -r CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo
echo "Step 1: Setting partition type for p5 to XBOOTLDR..."
# XBOOTLDR partition type GUID: bc13c2ff-59e6-4262-a352-b275fd6f7172
sudo sgdisk "$DISK" --typecode=5:bc13c2ff-59e6-4262-a352-b275fd6f7172
sudo partprobe "$DISK"
echo "✓ Partition type set"

echo
echo "Step 2: Mounting partitions..."
sudo mkdir -p /mnt/efi /mnt/boot
sudo mount "$EFI_PART" /mnt/efi
sudo mount "$BOOT_PART" /mnt/boot
echo "✓ Partitions mounted"

echo
echo "Step 3: Verifying kernel files are on boot partition..."
if [[ ! -f /mnt/boot/vmlinuz-linux ]]; then
    echo "✗ Kernel not found on boot partition!"
    exit 1
fi
echo "✓ Kernel files found:"
ls -lh /mnt/boot/*.img /mnt/boot/vmlinuz-*

echo
echo "Step 4: Copying loader.conf to EFI partition..."
sudo cp /mnt/boot/loader/loader.conf /mnt/efi/loader/loader.conf
echo "✓ loader.conf copied"

echo
echo "Step 5: Copying boot entries to EFI partition..."
sudo mkdir -p /mnt/efi/loader/entries
sudo cp /mnt/boot/loader/entries/*.conf /mnt/efi/loader/entries/
echo "✓ Entries copied"

echo
echo "Step 6: Verifying configuration..."
echo "EFI loader config:"
cat /mnt/efi/loader/loader.conf
echo
echo "Boot entries:"
ls -la /mnt/efi/loader/entries/
echo
echo "First boot entry:"
cat /mnt/efi/loader/entries/arch.conf

echo
echo "=== Configuration complete! ==="
echo
echo "systemd-boot will now:"
echo "  1. Load from EFI partition (p1)"
echo "  2. Find kernels on XBOOTLDR partition (p5)"
echo "  3. Show the boot menu with Arch Linux entries"
echo
echo -n "Unmount and reboot? (y/N): "
read -r REBOOT
if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
    sudo umount /mnt/boot
    sudo umount /mnt/efi
    sudo reboot
else
    echo "Remember to unmount before rebooting:"
    echo "  sudo umount /mnt/boot /mnt/efi"
fi

