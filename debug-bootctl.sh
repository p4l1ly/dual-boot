#!/bin/bash

# Debug script for bootctl installation issues

echo "=== Bootctl Debug Information ==="
echo

echo "1. Mount points:"
mount | grep -E '/install|nvme0n1'
echo

echo "2. EFI partition info:"
blkid /dev/nvme0n1p1
echo

echo "3. Boot partition info:"
blkid /dev/nvme0n1p5
echo

echo "4. Check if /install/boot/efi is mounted:"
mountpoint /install/boot/efi && echo "✓ Mounted" || echo "✗ Not mounted"
echo

echo "5. EFI partition filesystem:"
df -h /install/boot/efi
echo

echo "6. Boot partition filesystem:"
df -h /install/boot
echo

echo "7. Contents of /install/boot:"
ls -la /install/boot/
echo

echo "8. Contents of /install/boot/efi:"
ls -la /install/boot/efi/
echo

echo "9. Check if system is booted in UEFI mode:"
if [ -d /sys/firmware/efi ]; then
    echo "✓ System is in UEFI mode"
    ls -la /sys/firmware/efi/
else
    echo "✗ System is NOT in UEFI mode (BIOS mode)"
fi
echo

echo "10. Try bootctl install manually:"
echo "Running: arch-chroot /install bootctl install"
arch-chroot /install bootctl install
RESULT=$?
echo "Exit code: $RESULT"
echo

if [ $RESULT -ne 0 ]; then
    echo "11. Try with explicit ESP path:"
    echo "Running: arch-chroot /install bootctl install --esp-path=/boot/efi"
    arch-chroot /install bootctl install --esp-path=/boot/efi
    echo "Exit code: $?"
    echo
fi

echo "12. Check systemd version:"
arch-chroot /install bootctl --version
echo

echo "13. Check efibootmgr:"
efibootmgr -v
echo

echo "=== End Debug Information ==="
