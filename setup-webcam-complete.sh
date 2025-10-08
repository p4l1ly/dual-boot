#!/bin/bash
# Complete webcam setup script for Dell XPS 13 with Intel Lunar Lake

set -e

echo "==== Dell XPS 13 Webcam Complete Setup ===="
echo
echo "This script will:"
echo "1. Install required packages (libcamera, pipewire-libcamera, etc.)"
echo "2. Build IPU7 DKMS modules if needed"
echo "3. Load necessary kernel modules"
echo "4. Test the webcam"
echo
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo

# Step 1: Install packages
echo "Step 1: Installing required packages..."
sudo pacman -S --needed libcamera pipewire-libcamera libcamera-ipa libcamera-tools dkms linux-headers

echo
echo "Step 2: Checking IPU7 DKMS modules..."

# Check if IPU7 modules are already installed
if [ -d "/lib/modules/$(uname -r)/updates/dkms" ] && \
   find /lib/modules/$(uname -r)/updates/dkms -name "intel-ipu7*.ko*" 2>/dev/null | grep -q .; then
    echo "IPU7 modules already built and installed."
else
    echo "IPU7 modules not found. Building them now..."
    ./build-ipu7-modules.sh
fi

echo
echo "Step 3: Loading kernel modules and diagnosing..."
./fix-webcam.sh

echo
echo "Step 4: Testing webcam..."
if ls /dev/video* > /dev/null 2>&1; then
    echo "Video devices found! Testing..."
    ./test-webcam.sh
    
    echo
    echo "SUCCESS! The webcam should now be working."
    echo
    echo "To test in applications:"
    echo "- Firefox/Chrome: Visit https://webcamtests.com/"
    echo "- VLC: Media -> Open Capture Device"
    echo "- Cheese: sudo pacman -S cheese && cheese"
    echo "- libcamera-hello: libcamera-hello --qt-preview"
else
    echo "WARNING: No video devices found after setup."
    echo
    echo "Please try the following:"
    echo "1. Reboot your system: sudo reboot"
    echo "2. After reboot, check if /dev/video* devices exist"
    echo "3. Run ./fix-webcam.sh again after reboot"
    echo
    echo "If still not working, check kernel messages:"
    echo "sudo dmesg | grep -i -E 'camera|ipu|ivsc|ov02' | less"
fi

echo
echo "==== Setup Complete ===="



