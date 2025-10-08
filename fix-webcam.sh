#!/bin/bash
# Script to diagnose and fix Dell XPS 13 webcam issues

set -e

echo "==== Dell XPS 13 Webcam Fix Script ===="
echo

# Check if libcamera is installed
echo "Checking for libcamera packages..."
if ! pacman -Qs libcamera > /dev/null 2>&1; then
    echo "libcamera is not installed. Installing libcamera and pipewire-libcamera..."
    sudo pacman -S --needed libcamera pipewire-libcamera libcamera-ipa
else
    echo "libcamera is already installed."
fi

echo

# Load necessary kernel modules
echo "Loading kernel modules..."
sudo modprobe mei_gsc_proxy 2>/dev/null || echo "mei_gsc_proxy already loaded or not needed"
sudo modprobe mei_me 2>/dev/null || echo "mei_me already loaded or not needed"
sudo modprobe ivsc-ace 2>/dev/null || echo "ivsc-ace already loaded or failed"
sudo modprobe ivsc-csi 2>/dev/null || echo "ivsc-csi already loaded or failed"
sudo modprobe ipu-bridge 2>/dev/null || echo "ipu-bridge already loaded or failed"
sudo modprobe intel-ipu6 2>/dev/null || echo "intel-ipu6 already loaded or failed"
sudo modprobe intel-ipu6-isys 2>/dev/null || echo "intel-ipu6-isys already loaded or failed"

echo

# Check for IPU7 modules (if IPU7 packages are installed)
if [ -d "/lib/modules/$(uname -r)/updates/dkms" ]; then
    echo "Checking for IPU7 DKMS modules..."
    if find /lib/modules/$(uname -r)/updates/dkms -name "*ipu7*" 2>/dev/null | grep -q .; then
        echo "Loading IPU7 modules..."
        sudo modprobe intel-ipu7 2>/dev/null || echo "intel-ipu7 already loaded or failed"
        sudo modprobe intel-ipu7-isys 2>/dev/null || echo "intel-ipu7-isys already loaded or failed"
    fi
fi

echo

# Wait a moment for devices to appear
echo "Waiting for video devices to appear..."
sleep 2

echo

# List loaded camera-related modules
echo "Currently loaded camera modules:"
lsmod | grep -E "ipu|ivsc|ov02|mei"

echo

# Check for video devices
echo "Video devices:"
if ls /dev/video* > /dev/null 2>&1; then
    ls -la /dev/video*
    echo
    echo "Detailed device information:"
    v4l2-ctl --list-devices
else
    echo "No /dev/video* devices found!"
fi

echo

# Check journal for errors
echo "Recent camera-related kernel messages:"
journalctl -b -k | grep -i -E "camera|ov02|ivsc|ipu|mei" | tail -20

echo
echo "==== Diagnostic complete ===="
echo
echo "If no video devices appeared, you may need to:"
echo "1. Install libcamera: sudo pacman -S libcamera pipewire-libcamera libcamera-ipa"
echo "2. Reboot the system for all modules to load properly"
echo "3. Check if firmware is missing: dmesg | grep -i firmware"



