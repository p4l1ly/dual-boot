#!/bin/bash

# Fix crypttab and fstab for automatic swap and shared decryption

set -e

echo "=== Fix crypttab and fstab ==="
echo

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

ROOT_PART="/dev/nvme0n1p6"
SWAP_PART="/dev/nvme0n1p8"
SHARED_PART="/dev/nvme0n1p7"

# Mount root
if [[ ! -b /dev/mapper/root ]]; then
    echo "Opening root LUKS container..."
    echo "Enter LUKS password:"
    cryptsetup open "$ROOT_PART" root
fi

ROOT_MOUNT="/mnt"
mkdir -p "$ROOT_MOUNT"
mount /dev/mapper/root "$ROOT_MOUNT"

echo "✓ Root mounted at $ROOT_MOUNT"
echo

# Get partition UUIDs (not LUKS UUIDs)
SWAP_UUID=$(blkid -s UUID -o value "$SWAP_PART")
SHARED_UUID=$(blkid -s UUID -o value "$SHARED_PART")

echo "Swap partition UUID: $SWAP_UUID"
echo "Shared partition UUID: $SHARED_UUID"
echo

# Backup existing files
cp "$ROOT_MOUNT/etc/crypttab" "$ROOT_MOUNT/etc/crypttab.bak" 2>/dev/null || true
cp "$ROOT_MOUNT/etc/fstab" "$ROOT_MOUNT/etc/fstab.bak" 2>/dev/null || true

echo "Backed up crypttab and fstab"
echo

# Create new crypttab
echo "Creating new /etc/crypttab..."
cat > "$ROOT_MOUNT/etc/crypttab" << EOF
# <name>  <device>                                  <password>          <options>
swap      UUID=$SWAP_UUID                           /etc/keys/root.key  luks
shared    UUID=$SHARED_UUID                         /etc/keys/root.key  luks
EOF

echo "✓ crypttab created"
cat "$ROOT_MOUNT/etc/crypttab"
echo

# Fix fstab - remove any swap/shared entries and add correct ones
echo "Fixing /etc/fstab..."

# Remove old swap/shared entries
sed -i '/\/dev\/mapper\/swap/d' "$ROOT_MOUNT/etc/fstab"
sed -i '/\/dev\/mapper\/shared/d' "$ROOT_MOUNT/etc/fstab"
sed -i '/\/mnt\/shared/d' "$ROOT_MOUNT/etc/fstab"

# Add new entries
echo "/dev/mapper/swap    none           swap    defaults        0 0" >> "$ROOT_MOUNT/etc/fstab"
echo "/dev/mapper/shared  /mnt/shared    ext4    defaults,noatime 0 2" >> "$ROOT_MOUNT/etc/fstab"

echo "✓ fstab updated"
echo

echo "Current /etc/fstab:"
cat "$ROOT_MOUNT/etc/fstab"
echo

# Cleanup
read -p "Unmount and close LUKS? (Y/n): " -r CLEANUP
if [[ ! "$CLEANUP" =~ ^[Nn]$ ]]; then
    umount "$ROOT_MOUNT"
    cryptsetup close root
    echo "✓ Cleaned up"
fi

echo
echo "=== Done ==="
echo
echo "Changes made:"
echo "  1. /etc/crypttab: Added swap and shared with keyfile"
echo "  2. /etc/fstab: Added /dev/mapper/swap and /dev/mapper/shared"
echo
echo "On next boot:"
echo "  - Enter password for root partition"
echo "  - Swap and shared will auto-decrypt using /etc/keys/root.key"
echo "  - System will boot normally"

