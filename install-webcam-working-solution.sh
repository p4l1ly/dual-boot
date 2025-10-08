#!/bin/bash
# Complete working solution for Dell XPS 13 9350 (2024) Lunar Lake webcam
# Based on: https://github.com/gfhdhytghd/XPS_9350_2024_ArchLinux_capability

set -e

echo "==== Dell XPS 13 9350 Webcam Setup (Working Solution) ===="
echo
echo "This script will:"
echo "1. Install required packages"
echo "2. Build and install IPU7 camera HAL from git"
echo "3. Set up v4l2loopback virtual camera"
echo "4. Configure automatic camera switching"
echo
echo "Note: This uses the WORKING method from GitHub, not the broken AUR packages"
echo
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Check if running zen kernel (recommended)
CURRENT_KERNEL=$(uname -r)
if [[ ! $CURRENT_KERNEL =~ zen ]]; then
    echo
    echo "⚠️  WARNING: You're not running linux-zen kernel"
    echo "Current kernel: $CURRENT_KERNEL"
    echo "Arch Wiki recommends linux-zen for best webcam support"
    echo
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Install linux-zen first: sudo pacman -S linux-zen linux-zen-headers"
        exit 1
    fi
fi

# Install base packages from official repos and AUR
echo
echo "Step 1: Installing required packages..."
echo

# Official packages
echo "Installing official packages..."
sudo pacman -S --needed \
    git base-devel autoconf automake libtool pkgconf cmake \
    gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad \
    libdrm glib2 v4l-utils i2c-tools dkms \
    libjpeg-turbo libtiff libevent inotify-tools lsof \
    meson ninja

# AUR packages (IPU7 drivers)
echo
echo "Installing AUR packages..."

# Check if already installed
if ! pacman -Q intel-ipu7-dkms-git >/dev/null 2>&1; then
    echo "Installing intel-ipu7-dkms-git..."
    yay -S --needed intel-ipu7-dkms-git
fi

if ! pacman -Q intel-ipu7-camera-bin >/dev/null 2>&1; then
    echo "Installing intel-ipu7-camera-bin..."
    yay -S --needed intel-ipu7-camera-bin
fi

if ! pacman -Q v4l2loopback-dkms >/dev/null 2>&1; then
    echo "Installing v4l2loopback-dkms..."
    yay -S --needed v4l2loopback-dkms
fi

if ! pacman -Q v4l2loopback-utils >/dev/null 2>&1; then
    echo "Installing v4l2loopback-utils..."
    yay -S --needed v4l2loopback-utils
fi

echo
echo "Step 2: Running the setup script from GitHub..."
echo

# Run the official setup script
./ipu7_cam_setup.sh

echo
echo "==== Installation Complete ===="
echo
echo "The webcam should now be working!"
echo
echo "To test:"
echo "  1. Check video devices: v4l2-ctl --list-devices"
echo "  2. Test with libcamera: cam -l"
echo "  3. Check service: systemctl --user status libcamera-bridge-smart.service"
echo "  4. View logs: journalctl --user -fu libcamera-bridge-smart.service"
echo
echo "Virtual camera device: /dev/video42 (default)"
echo "Use this device in video applications (Zoom, Chrome, etc.)"
echo
echo "If you don't see the camera, try rebooting: sudo reboot"

