#!/bin/bash
# Script to try installing and using the mainline kernel for Lunar Lake GPIO support

set -e

echo "==== Install Linux Mainline Kernel for Lunar Lake Support ===="
echo
echo "The current kernel (6.16.10) doesn't have Lunar Lake GPIO support."
echo "The mainline kernel (6.17) may include the necessary INTC10B5 driver."
echo
echo "This script will:"
echo "1. Install linux-mainline and linux-mainline-headers from AUR"
echo "2. Create a boot entry for the mainline kernel"
echo "3. Rebuild IPU7 DKMS modules for the new kernel"
echo
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Install mainline kernel
echo
echo "Step 1: Installing linux-mainline..."
yay -S --needed linux-mainline linux-mainline-headers

# Get the mainline kernel version
MAINLINE_VERSION=$(pacman -Q linux-mainline | awk '{print $2}' | cut -d'-' -f1)
echo
echo "Installed mainline kernel version: $MAINLINE_VERSION"

# Create boot entry
echo
echo "Step 2: Creating systemd-boot entry..."
BOOT_ENTRY="/boot/loader/entries/arch-mainline.conf"

if [ -f "/boot/loader/entries/arch.conf" ]; then
    sudo cp /boot/loader/entries/arch.conf "$BOOT_ENTRY"
    
    # Update the boot entry to use mainline kernel
    sudo sed -i "s/title.*/title   Arch Linux (Mainline Kernel)/" "$BOOT_ENTRY"
    sudo sed -i "s|/vmlinuz-linux|/vmlinuz-linux-mainline|" "$BOOT_ENTRY"
    sudo sed -i "s|/initramfs-linux.img|/initramfs-linux-mainline.img|" "$BOOT_ENTRY"
    sudo sed -i "s|/initramfs-linux-fallback.img|/initramfs-linux-mainline-fallback.img|" "$BOOT_ENTRY"
    
    echo "Created boot entry: $BOOT_ENTRY"
else
    echo "ERROR: /boot/loader/entries/arch.conf not found"
    echo "Please manually create a boot entry for linux-mainline"
    exit 1
fi

# Rebuild IPU7 modules for mainline kernel
echo
echo "Step 3: Rebuilding IPU7 DKMS modules for mainline kernel..."
if [ -d "/var/lib/dkms/ipu7-drivers/0.0.0" ]; then
    sudo dkms build -m ipu7-drivers -v 0.0.0 -k ${MAINLINE_VERSION}-mainline || echo "DKMS build failed (may need to run after reboot)"
    sudo dkms install -m ipu7-drivers -v 0.0.0 -k ${MAINLINE_VERSION}-mainline --force || echo "DKMS install failed (may need to run after reboot)"
fi

echo
echo "==== Installation Complete ===="
echo
echo "Next steps:"
echo "1. Reboot your system: sudo reboot"
echo "2. At the systemd-boot menu, select 'Arch Linux (Mainline Kernel)'"
echo "3. After booting, run: ./check-gpio-after-mainline.sh"
echo "4. If the webcam works, you can set mainline as default or wait for Arch kernel update"
echo
echo "To set mainline as default:"
echo "  sudo sed -i 's/default.*/default arch-mainline.conf/' /boot/loader/loader.conf"


