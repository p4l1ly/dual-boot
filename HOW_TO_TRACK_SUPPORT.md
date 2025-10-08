# How to Track When Lunar Lake GPIO Support Will Be in Linux Kernel

## The Exact Driver You Need

- **ACPI Device ID**: `INTC10B5`
- **Driver Type**: Intel pinctrl (pin control/GPIO driver)
- **Expected Driver Name**: `pinctrl-lunarlake` or similar
- **File**: Would be `drivers/pinctrl/intel/pinctrl-lunarlake.c` in kernel source

## Current Status (as of October 7, 2025)

✅ **Confirmed**: No pinctrl driver for Lunar Lake exists in current Linux kernel (checked mainline master branch)
❌ **NOT in kernel 6.16.10** (your current kernel)
❌ **NOT in kernel 6.17** (mainline development)

## How to Track Development

### Method 1: Monitor Linux Kernel Git (Most Reliable)

**Check for new Lunar Lake pinctrl commits:**

1. Visit: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/log/drivers/pinctrl/intel

2. Search the page (Ctrl+F) for:
   - "Lunar Lake"
   - "lunarlake"
   - "LNL"
   - "INTC10B5"

3. If you find a commit, check which kernel version it's targeting

**Example of what to look for:**
```
commit abc123...
Author: Developer Name
Date: Mon Oct 15 2025

    pinctrl: intel: Add Lunar Lake pin controller support
    
    Add pinctrl driver for Intel Lunar Lake SoC...
```

### Method 2: Search Kernel Mailing Lists

**Linux GPIO mailing list:**
https://lore.kernel.org/linux-gpio/

Search for: "Lunar Lake" OR "INTC10B5"

This shows patches **before** they're merged, so you can see what's coming.

### Method 3: Check Intel's Repository

Intel sometimes develops drivers here first:
https://github.com/intel/linux-intel-lts

Search issues and commits for "Lunar Lake" or "INTC10B5"

### Method 4: Monitor Arch Linux Kernel Updates

**Arch Linux kernel package:**
https://archlinux.org/packages/core/x86_64/linux/

Steps:
1. Check this page weekly
2. Look for new versions (6.17, 6.18, etc.)
3. Click on "View Changes" or "Commits"
4. Search for "Lunar Lake" or "pinctrl"

### Method 5: Use the Monitor Script

Run this weekly after system updates:
```bash
./monitor-kernel-for-lunarlake.sh
```

This script checks your current kernel for INTC10B5 support.

## How to Know Which Kernel Version Will Have It

Once you find a commit (Method 1 above):

1. **Check the commit date** - Kernel versions are released roughly every 2-3 months

2. **Check which kernel it's targeting:**
   - Commits to `master` or `next` branch → next kernel release
   - Commits with "for-6.18" or similar → that specific version

3. **Kernel release cycle:**
   - 6.16 released: ~December 2024
   - 6.17 expected: ~March 2025
   - 6.18 expected: ~May 2025
   - 6.19 expected: ~August 2025

4. **Arch Linux lag**: Usually 1-7 days after kernel.org release

## Alternative: File a Bug Report

If no one is working on this, report it:

### Linux Kernel Bugzilla
https://bugzilla.kernel.org/

**How to report:**
1. Create account
2. File new bug
3. Component: "Drivers/Other"
4. Title: "Missing pinctrl driver for Intel Lunar Lake (INTC10B5)"
5. Attach: `dmesg` output showing the errors
6. Include: Your Dell XPS 13 model number

### Arch Linux Forums
https://bbs.archlinux.org/

Post in Hardware category with title:
"Dell XPS 13 Lunar Lake - Webcam not working (missing INTC10B5 driver)"

## What Response Time to Expect

Based on typical Intel hardware support:

- **Best case**: Driver already exists in development, will be in kernel 6.18-6.19 (1-3 months)
- **Typical case**: Being developed, will be in kernel 6.19-6.20 (3-6 months)
- **Worst case**: Not yet started, could be 6-12 months

Since Lunar Lake was released in September 2024 and we're in October 2025, support should be coming **very soon** if it's not already in development.

## Automated Monitoring

Create a cron job to check weekly:

```bash
# Add to crontab (crontab -e)
0 10 * * 1 /home/paly/hobby/dual-boot/monitor-kernel-for-lunarlake.sh | mail -s "Lunar Lake Support Check" your@email.com
```

Or just run manually after each system update:
```bash
sudo pacman -Syu
./monitor-kernel-for-lunarlake.sh
```

## Bottom Line

**Don't install linux-mainline 6.17** - it doesn't have support either.

**Instead**:
1. Run `sudo pacman -Syu` every 1-2 weeks
2. Run `./monitor-kernel-for-lunarlake.sh` after each update
3. Check the kernel git log (Method 1) once a month
4. Be patient - support is likely coming in the next few kernel releases

When support arrives, you'll know immediately and can test with the existing scripts.


