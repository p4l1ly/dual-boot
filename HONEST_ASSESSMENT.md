# Honest Assessment: Lunar Lake Webcam Support

## Your Question

> "My kernel is very new (6.16.10), are you sure that 6.17 will support my webcam? Is it worth installing linux-mainline from AUR because of one minor version?"

## Honest Answer

**You're right to be skeptical.** After investigation, I found:

### What We Know for Certain

1. **Your hardware needs**: GPIO controller with ACPI ID `INTC10B5`
2. **What's missing**: A pinctrl driver that supports INTC10B5
3. **What exists in 6.16.10**:
   - `pinctrl-meteorlake` (supports INTC1082, INTC1083, INTC105E)
   - `pinctrl-alderlake` (supports INTC1085, INTC1057, INTC1056)
   - **NO driver for INTC10B5**

### What We DON'T Know

❓ **Is INTC10B5 support in kernel 6.17?** - Unknown
❓ **When will it be added?** - Unknown
❓ **Is it being worked on?** - Need to check kernel mailing lists

## Recommendation: DON'T Install linux-mainline Yet

**Reasons NOT to install 6.17:**
1. **Only minor version difference** (6.16 → 6.17)
2. **No evidence it has INTC10B5 support**
3. **AUR mainline kernels can be less stable**
4. **Risk vs reward is poor for one minor version**

## Better Approach: Research First

### Step 1: Check if the Driver Exists

Visit these links to see if anyone is working on Lunar Lake GPIO support:

1. **Linux kernel commits** (search for "lunar lake" or "INTC10B5"):
   ```
   https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/log/drivers/pinctrl/intel
   ```

2. **Kernel mailing list** (search for "INTC10B5" or "Lunar Lake GPIO"):
   ```
   https://lore.kernel.org/linux-gpio/
   ```

3. **Bug reports** (see if others have this issue):
   ```
   https://bugzilla.kernel.org/
   Search: "Lunar Lake camera" or "INTC10B5"
   ```

### Step 2: Check Arch Linux Kernel Plans

Check the changelog of upcoming Arch kernel releases:
```
https://archlinux.org/packages/core/x86_64/linux/
```

### Step 3: Monitor Your Current Kernel

Just run regular system updates:
```bash
sudo pacman -Syu
```

Check kernel version after each update:
```bash
uname -r
cat /proc/version
```

## The Likely Timeline

Based on typical Linux hardware support cycles:

- **Lunar Lake released**: September 2024
- **Initial kernel support**: Usually 3-6 months after CPU release
- **Full hardware support**: Usually 6-12 months after CPU release
- **Expected timeframe**: Q2-Q3 2025 (April-September 2025)

We're in October 2025 now, so support **should** be coming soon if it's not already there.

## What You Should Do Right Now

### Option 1: Research (Recommended)
1. Search kernel git logs for "Lunar Lake" or "INTC10B5"
2. Check if patches exist but aren't merged yet
3. See if anyone filed a bug report
4. Find out which kernel version will have it

### Option 2: Report the Issue
If no one has reported this yet, file a bug report:
- **Linux Kernel Bugzilla**: https://bugzilla.kernel.org/
- **Arch Linux Forums**: Post your findings
- **Intel Linux GitHub**: https://github.com/intel/linux-intel-lts/issues

### Option 3: Wait and Monitor
- Run `sudo pacman -Syu` every week
- Check kernel version: `uname -r`
- When you see 6.17, 6.18, etc., check release notes
- Test with: `./check-gpio-after-mainline.sh`

### Option 4: Use External Webcam (Temporary)
Buy a USB webcam that's known to work with Linux while you wait.

## How to Track When Support is Added

I'll create a monitoring script for you that checks if INTC10B5 is supported in your current kernel.


