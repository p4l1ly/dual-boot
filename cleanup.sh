#!/bin/bash

# Cleanup script for Arch installation
# Run this if arch-install.sh fails or needs to be restarted

echo "=== Arch Installation Cleanup ==="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Deactivate any active swap
echo "Deactivating swap..."
swapoff -a 2>/dev/null || true

# Unmount any mounted filesystems under /install
echo "Unmounting filesystems..."
if mountpoint -q /install 2>/dev/null; then
    umount -R /install 2>/dev/null || true
fi

# Close any open LUKS containers
echo "Closing LUKS containers..."
for container in root swap shared; do
    if cryptsetup status "$container" >/dev/null 2>&1; then
        echo "  Closing $container..."
        cryptsetup close "$container"
    fi
done

# Remove installation directory
echo "Removing installation directory..."
if [[ -d "/install" ]]; then
    rmdir /install 2>/dev/null || true
fi

# Show current device mapper status
echo "Current device mappers:"
ls -la /dev/mapper/

echo "=== Cleanup completed ==="
echo "You can now run arch-install.sh again"
