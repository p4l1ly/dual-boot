#!/bin/bash
# Script to identify exactly what driver is needed for INTC10B5

echo "==== Identifying Missing Driver for INTC10B5 ===="
echo

echo "Step 1: What hardware needs the driver?"
echo "ACPI ID: INTC10B5"
echo "Purpose: GPIO controller for Lunar Lake platform"
echo

echo "Step 2: Checking kernel source for INTC10B5 support..."
echo

# Check if any current module supports INTC10B5
echo "Checking current kernel modules for INTC10B5 support:"
for module in /lib/modules/$(uname -r)/kernel/drivers/pinctrl/intel/*.ko.zst; do
    if zcat "$module" 2>/dev/null | strings | grep -q "INTC10B5"; then
        echo "✅ Found in: $(basename $module)"
    fi
done

# Check meteorlake and other related modules
echo
echo "Checking specific modules for ACPI aliases:"
for module in pinctrl-meteorlake pinctrl-alderlake pinctrl-tigerlake; do
    if modinfo "$module" 2>/dev/null | grep -q "alias.*INTC"; then
        echo
        echo "Module: $module"
        modinfo "$module" | grep "alias.*acpi.*INTC"
    fi
done

echo
echo "Step 3: Searching Linux kernel git for INTC10B5..."
echo "(This requires internet connection)"
echo

# Search kernel.org for INTC10B5
if command -v git &> /dev/null; then
    echo "Checking if INTC10B5 support exists in Linux git..."
    
    # Try to query kernel.org via web
    SEARCH_RESULT=$(curl -s "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/log/drivers/pinctrl/intel" 2>/dev/null | grep -i "lunar\|lnl" | head -3)
    
    if [ -n "$SEARCH_RESULT" ]; then
        echo "Found Lunar Lake references:"
        echo "$SEARCH_RESULT"
    else
        echo "No direct Lunar Lake references found in quick search"
    fi
fi

echo
echo "Step 4: Manual search instructions"
echo
echo "To find when INTC10B5 support was/will be added to the kernel:"
echo
echo "1. Search Linux kernel git log:"
echo "   https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/log/drivers/pinctrl/intel"
echo "   Search for: 'Lunar Lake', 'LNL', or 'INTC10B5'"
echo
echo "2. Check kernel.org mailing lists:"
echo "   https://lore.kernel.org/linux-gpio/"
echo "   Search for: 'INTC10B5' or 'Lunar Lake pinctrl'"
echo
echo "3. Check Intel's linux-firmware repository:"
echo "   https://github.com/intel/linux-intel-lts"
echo
echo "4. Monitor Arch Linux kernel releases:"
echo "   https://archlinux.org/packages/core/x86_64/linux/"
echo "   Check changelog for each new version"
echo

echo "==== Analysis Complete ===="
echo
echo "Next: Run the web search script to check current status"


