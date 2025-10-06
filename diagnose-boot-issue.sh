#!/bin/bash

# Diagnose boot/LUKS issues

set -e

echo "=== Boot Issue Diagnostics ==="
echo

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

ROOT_PART="/dev/nvme0n1p6"
BOOT_PART="/dev/nvme0n1p5"

# Mount boot partition (doesn't need decryption)
BOOT_MOUNT="/mnt/boot"
mkdir -p "$BOOT_MOUNT"

if ! mountpoint -q "$BOOT_MOUNT"; then
    mount "$BOOT_PART" "$BOOT_MOUNT"
    echo "✓ Boot partition mounted at $BOOT_MOUNT"
fi

echo
echo "=== 1. Check Boot Entry ==="
echo "File: $BOOT_MOUNT/loader/entries/arch.conf"
cat "$BOOT_MOUNT/loader/entries/arch.conf"
echo

# Extract the options line
OPTIONS=$(grep "^options" "$BOOT_MOUNT/loader/entries/arch.conf" | cut -d' ' -f2-)
echo "Parsed options: $OPTIONS"
echo

# Check if cryptdevice is present
if ! echo "$OPTIONS" | grep -q "cryptdevice="; then
    echo "❌ ERROR: No cryptdevice= parameter found!"
    echo "   The kernel doesn't know which partition to decrypt."
    exit 1
else
    echo "✓ cryptdevice parameter found"
fi

# Extract cryptdevice value
CRYPTDEV=$(echo "$OPTIONS" | grep -oP 'cryptdevice=\S+' | cut -d= -f2-)
echo "  Value: $CRYPTDEV"
echo

# Check if PARTUUID is used
if echo "$CRYPTDEV" | grep -q "PARTUUID="; then
    PARTUUID=$(echo "$CRYPTDEV" | cut -d: -f1 | cut -d= -f2)
    echo "✓ Using PARTUUID: $PARTUUID"
    
    # Verify it matches the partition
    ACTUAL_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_PART")
    echo "  Actual PARTUUID of $ROOT_PART: $ACTUAL_PARTUUID"
    
    if [[ "$PARTUUID" != "$ACTUAL_PARTUUID" ]]; then
        echo "❌ ERROR: PARTUUID mismatch!"
        echo "   Boot entry uses: $PARTUUID"
        echo "   Partition has:   $ACTUAL_PARTUUID"
        echo
        echo "Fix with:"
        echo "  sed -i 's|PARTUUID=$PARTUUID|PARTUUID=$ACTUAL_PARTUUID|' $BOOT_MOUNT/loader/entries/arch*.conf"
        exit 1
    else
        echo "✓ PARTUUID matches"
    fi
elif echo "$CRYPTDEV" | grep -q "UUID="; then
    echo "⚠️  WARNING: Using UUID instead of PARTUUID"
    echo "   This should work but PARTUUID is more reliable"
fi
echo

echo "=== 2. Check Initramfs Contents ==="
echo "Extracting initramfs to check for encrypt hook..."

# Create temp dir
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Extract initramfs
zcat "$BOOT_MOUNT/initramfs-linux.img" | cpio -id 2>/dev/null

# Check for encrypt hook
if [[ -f "hooks/encrypt" ]]; then
    echo "✓ encrypt hook found in initramfs"
else
    echo "❌ ERROR: encrypt hook NOT found in initramfs!"
    echo "   The initramfs was built without the encrypt hook."
    echo
    echo "This means mkinitcpio.conf doesn't have 'encrypt' in HOOKS,"
    echo "or initramfs wasn't regenerated after editing."
    cd /
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Check for cryptsetup binary
if [[ -f "usr/bin/cryptsetup" ]] || [[ -f "bin/cryptsetup" ]]; then
    echo "✓ cryptsetup binary found in initramfs"
else
    echo "❌ ERROR: cryptsetup binary NOT found in initramfs!"
fi

# Check for keyboard drivers
if ls lib/modules/*/kernel/drivers/input/keyboard/*.ko* >/dev/null 2>&1; then
    echo "✓ Keyboard drivers found in initramfs"
else
    echo "⚠️  WARNING: No keyboard drivers found"
fi

cd /
rm -rf "$TEMP_DIR"
echo

echo "=== 3. Check mkinitcpio.conf (need to mount root) ==="
echo "Would you like to mount the root partition to check mkinitcpio.conf? (y/N)"
read -r CHECK_ROOT

if [[ "$CHECK_ROOT" =~ ^[Yy]$ ]]; then
    if [[ ! -b /dev/mapper/root ]]; then
        echo "Opening root LUKS container..."
        echo "Enter LUKS password:"
        cryptsetup open "$ROOT_PART" root
    fi
    
    ROOT_MOUNT="/mnt/root"
    mkdir -p "$ROOT_MOUNT"
    mount /dev/mapper/root "$ROOT_MOUNT"
    
    echo
    echo "Current HOOKS in /etc/mkinitcpio.conf:"
    grep "^HOOKS=" "$ROOT_MOUNT/etc/mkinitcpio.conf"
    echo
    
    HOOKS=$(grep "^HOOKS=" "$ROOT_MOUNT/etc/mkinitcpio.conf" | cut -d= -f2)
    
    if ! echo "$HOOKS" | grep -q "encrypt"; then
        echo "❌ ERROR: 'encrypt' hook not in HOOKS!"
        echo "   Fix: Run ./fix-initramfs-hooks.sh"
    else
        echo "✓ encrypt hook present in HOOKS"
    fi
    
    if ! echo "$HOOKS" | grep -q "keyboard"; then
        echo "❌ ERROR: 'keyboard' hook not in HOOKS!"
    else
        echo "✓ keyboard hook present in HOOKS"
    fi
    
    # Check hook order
    if echo "$HOOKS" | grep -oE '\(.*\)' | grep -oE 'keyboard.*encrypt'; then
        echo "✓ keyboard comes before encrypt (correct)"
    else
        echo "⚠️  WARNING: keyboard should come before encrypt"
    fi
    
    umount "$ROOT_MOUNT"
    cryptsetup close root
fi

echo
echo "=== 4. Suggested Actions ==="
echo

if [[ -f "$BOOT_MOUNT/initramfs-linux-fallback.img" ]]; then
    echo "Try booting with the fallback initramfs:"
    echo "  - Select 'Arch Linux (fallback initramfs)' from boot menu"
    echo "  - Fallback includes more drivers"
    echo
fi

echo "If you still don't see a password prompt:"
echo "  1. Check if 'quiet' is in kernel options (removes it for verbose boot)"
echo "  2. Add 'debug' to kernel options for more output"
echo "  3. Try different console output: add 'console=tty0'"
echo
echo "Manual fix boot entry for verbose output:"
echo "  Edit: $BOOT_MOUNT/loader/entries/arch.conf"
echo "  Remove 'quiet' from options line"
echo "  Add 'debug' to options line"
echo

read -p "Unmount boot partition? (Y/n): " -r UNMOUNT
if [[ ! "$UNMOUNT" =~ ^[Nn]$ ]]; then
    umount "$BOOT_MOUNT"
    echo "✓ Unmounted"
fi

echo
echo "=== Diagnostics Complete ==="

