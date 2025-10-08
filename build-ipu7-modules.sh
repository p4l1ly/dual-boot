#!/bin/bash
# Script to build and install IPU7 DKMS modules

set -e

echo "==== Building IPU7 DKMS Modules ===="
echo

KERNEL_VERSION=$(uname -r)
IPU7_VERSION="0.0.0"
IPU7_DIR="ipu7-drivers-r42.62a3704"
IPU7_SRC="/usr/src/${IPU7_DIR}"

# Check if source exists
if [ ! -d "$IPU7_SRC" ]; then
    echo "ERROR: IPU7 source not found at $IPU7_SRC"
    echo "Please install intel-ipu7-dkms-git package first"
    exit 1
fi

echo "Found IPU7 source at $IPU7_SRC"
echo "Kernel version: $KERNEL_VERSION"
echo

# Check if DKMS is installed
if ! command -v dkms > /dev/null 2>&1; then
    echo "DKMS is not installed. Installing..."
    sudo pacman -S --needed dkms
fi

# Remove old DKMS builds if they exist
echo "Cleaning up old DKMS builds..."
sudo dkms remove -m ipu7-drivers -v ${IPU7_VERSION} --all 2>/dev/null || true

# Add to DKMS
echo "Adding IPU7 drivers to DKMS..."
if [ ! -d "/var/lib/dkms/ipu7-drivers/${IPU7_VERSION}" ]; then
    sudo dkms add -m ipu7-drivers -v ${IPU7_VERSION} -k ${KERNEL_VERSION} --sourcetree ${IPU7_SRC}
else
    echo "Already added"
fi

echo "Building IPU7 drivers for kernel $KERNEL_VERSION..."
sudo dkms build -m ipu7-drivers -v ${IPU7_VERSION} -k ${KERNEL_VERSION}

echo "Installing IPU7 drivers..."
sudo dkms install -m ipu7-drivers -v ${IPU7_VERSION} -k ${KERNEL_VERSION} --force

echo
echo "==== Build complete ===="
echo "IPU7 modules should now be available. Run ./fix-webcam.sh to load them."

