#!/bin/bash
set -e

echo "=== Fixing systemd-boot to use XBOOTLDR entries ==="
echo

# Partition definitions
DISK="/dev/nvme0n1"
EFI_PART="${DISK}p1"
BOOT_PART="${DISK}p5"

echo "Mounting partitions..."
sudo mkdir -p /mnt/efi /mnt/boot
sudo mount "$EFI_PART" /mnt/efi 2>/dev/null || true
sudo mount "$BOOT_PART" /mnt/boot 2>/dev/null || true
echo "✓ Partitions mounted"

echo
echo "Removing duplicate boot entries from EFI partition..."
sudo rm -f /mnt/efi/loader/entries/*.conf
echo "✓ Entries removed from EFI"

echo
echo "Updating loader.conf on EFI partition..."
sudo tee /mnt/efi/loader/loader.conf > /dev/null << 'EOF'
default arch.conf
timeout 4
console-mode max
editor no
EOF
echo "✓ loader.conf updated"

echo
echo "Verifying boot configuration..."
sudo bootctl --esp-path=/mnt/efi --boot-path=/mnt/boot list | head -20

echo
echo "=== Fix complete! ==="
echo
echo "systemd-boot will now use entries from XBOOTLDR partition (p5)"
echo "where the kernel files actually exist."
echo
echo -n "Unmount and reboot? (y/N): "
read -r REBOOT
if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
    sudo umount /mnt/boot 2>/dev/null || true
    sudo umount /mnt/efi 2>/dev/null || true
    sudo reboot
else
    echo "Remember to unmount before rebooting:"
    echo "  sudo umount /mnt/boot /mnt/efi"
fi

