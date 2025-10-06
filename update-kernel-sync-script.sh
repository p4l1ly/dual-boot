#!/bin/bash
# Update the kernel sync script on the Dell XPS with better error handling

set -e

echo "=== Updating Kernel Sync Script ==="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Create the improved copy script
echo "Creating improved kernel sync script..."
cat > /usr/local/bin/copy-kernels-to-efi.sh << 'EOFSCRIPT'
#!/bin/bash
# Copy kernel files from /boot to /boot/efi after kernel updates

ESP="/boot/efi"
BOOT="/boot"

# Check if EFI partition is mounted
if ! mountpoint -q "$ESP"; then
    echo "Error: EFI partition not mounted at $ESP"
    echo "Kernel files NOT copied to EFI partition!"
    echo "Run manually: sudo mount /dev/nvme0n1p1 $ESP && sudo $0"
    exit 1
fi

# Check if boot partition is mounted
if ! mountpoint -q "$BOOT"; then
    echo "Error: Boot partition not mounted at $BOOT"
    exit 1
fi

echo "Copying kernel files to EFI partition..."

# Copy main kernel and microcode (fail if source doesn't exist)
if [[ ! -f "$BOOT/vmlinuz-linux" ]]; then
    echo "Error: Kernel not found at $BOOT/vmlinuz-linux"
    exit 1
fi

cp "$BOOT/vmlinuz-linux" "$ESP/" || exit 1
cp "$BOOT/intel-ucode.img" "$ESP/" 2>/dev/null || echo "Warning: intel-ucode.img not found"
cp "$BOOT/initramfs-linux.img" "$ESP/" || exit 1

echo "✓ Copied kernel and main initramfs"

# Try to copy fallback if there's space
FALLBACK="$BOOT/initramfs-linux-fallback.img"
if [[ -f "$FALLBACK" ]]; then
    EFI_AVAIL=$(df --output=avail -B1 "$ESP" | tail -1)
    FALLBACK_SIZE=$(stat -c%s "$FALLBACK")
    
    if (( EFI_AVAIL > FALLBACK_SIZE + 10485760 )); then
        echo "Copying fallback initramfs..."
        cp "$FALLBACK" "$ESP/"
        echo "✓ Copied fallback initramfs"
    else
        echo "⚠ Not enough space for fallback initramfs on EFI partition"
        echo "  Available: $((EFI_AVAIL / 1048576))MB, Needed: $((FALLBACK_SIZE / 1048576))MB"
    fi
fi

echo "✓ Kernel files synchronized successfully"
EOFSCRIPT

chmod +x /usr/local/bin/copy-kernels-to-efi.sh
echo "✓ Script updated at /usr/local/bin/copy-kernels-to-efi.sh"

# Verify the pacman hook exists
if [[ -f /etc/pacman.d/hooks/95-copy-to-efi.hook ]]; then
    echo "✓ Pacman hook already exists"
else
    echo "Creating pacman hook..."
    mkdir -p /etc/pacman.d/hooks
    cat > /etc/pacman.d/hooks/95-copy-to-efi.hook << 'EOFHOOK'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux
Target = linux-lts
Target = linux-zen
Target = intel-ucode
Target = amd-ucode

[Action]
Description = Copying kernel files to EFI partition...
When = PostTransaction
Exec = /usr/local/bin/copy-kernels-to-efi.sh
EOFHOOK
    echo "✓ Pacman hook created at /etc/pacman.d/hooks/95-copy-to-efi.hook"
fi

# Test the script
echo
echo "Testing the script..."
if /usr/local/bin/copy-kernels-to-efi.sh; then
    echo
    echo "✓ Script works correctly!"
else
    echo
    echo "⚠ Script failed - check the error messages above"
    exit 1
fi

echo
echo "=== Update Complete ==="
echo
echo "The kernel sync script will now:"
echo "  1. Check if partitions are mounted before copying"
echo "  2. Fail gracefully with helpful error messages"
echo "  3. Run automatically after kernel updates"
echo
echo "To test manually: sudo /usr/local/bin/copy-kernels-to-efi.sh"

