#!/bin/bash
# Monitor script to check if current kernel has Lunar Lake GPIO support

echo "==== Lunar Lake GPIO Support Monitor ===="
echo

CURRENT_KERNEL=$(uname -r)
echo "Current kernel: $CURRENT_KERNEL"
echo

# Check if INTC10B5 is supported
echo "Checking for INTC10B5 support in installed pinctrl drivers..."
FOUND=0

for module in /lib/modules/$(uname -r)/kernel/drivers/pinctrl/intel/*.ko.zst; do
    MODULE_NAME=$(basename "$module" .ko.zst)
    if modinfo "$MODULE_NAME" 2>/dev/null | grep -q "INTC10B5"; then
        echo "✅ FOUND! $MODULE_NAME supports INTC10B5"
        FOUND=1
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "❌ NOT FOUND - INTC10B5 is not supported in kernel $CURRENT_KERNEL"
    echo
    echo "Supported ACPI IDs in current kernel:"
    for module in pinctrl-meteorlake pinctrl-alderlake pinctrl-tigerlake; do
        if modinfo "$module" 2>/dev/null > /dev/null; then
            echo
            echo "  $module:"
            modinfo "$module" 2>/dev/null | grep "alias.*acpi" | sed 's/^/    /'
        fi
    done
    
    echo
    echo "What to do:"
    echo "1. Keep running 'sudo pacman -Syu' regularly"
    echo "2. After each kernel update, run this script again"
    echo "3. When INTC10B5 is found, run: ./fix-webcam.sh"
else
    echo
    echo "SUCCESS! Your kernel now supports Lunar Lake GPIO."
    echo "Run: ./fix-webcam.sh"
fi

echo
echo "To check if newer kernels have support:"
echo "Visit: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/pinctrl/intel"
echo "Look for: pinctrl-lunarlake.c or search Makefile for LUNARLAKE"
echo

# Check for pending kernel updates
echo "Checking for kernel updates..."
pacman -Qu | grep "^linux " && echo "⚠️ Kernel update available! Install and reboot to test." || echo "No kernel updates available right now."


