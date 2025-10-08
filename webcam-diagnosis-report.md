# Dell XPS 13 Webcam Diagnosis Report

## Hardware Configuration
- **Model**: Dell XPS 13 with Intel Lunar Lake (Core Ultra 7 155H or similar)
- **Graphics**: Intel Arc 130V/140V (Lunar Lake)
- **IPU**: Lunar Lake IPU at PCI 00:05.0
- **Camera Sensor**: OmniVision OV02C10
- **Camera Controller**: Lattice AI USB 2.0 (SLS, ID 2ac1:20c9)

## Current Status
- ✅ Camera hardware detected
- ✅ Camera sensor driver loaded (ov02c10)
- ✅ IPU6 modules loaded (intel_ipu6, intel_ipu6_isys)
- ✅ IVSC modules loaded (ivsc_ace, ivsc_csi)
- ✅ IPU7 DKMS modules built and installed
- ✅ Firmware present (/lib/firmware/intel/ipu/)
- ❌ **No /dev/video* devices created**

## Root Cause

**Missing GPIO Controller Driver**: INTC10B5

The camera power management chip (INT3472) cannot initialize because it cannot find the GPIO controller `INTC10B5:00`. This is the Lunar Lake GPIO/pinctrl controller.

### Evidence from dmesg:
```
[    9.633598] int3472-discrete INT3472:00: cannot find GPIO chip INTC10B5:00, deferring
[   22.601789] platform INT3472:00: deferred probe pending: int3472-discrete: Failed to get GPIO
```

### Available Intel pinctrl drivers in kernel 6.16.10:
- pinctrl-alderlake (Alder Lake, 12th gen)
- pinctrl-meteorlake (Meteor Lake, 14th gen)
- pinctrl-meteorpoint (related to Meteor Lake)
- **NO pinctrl-lunarlake** ❌

## Why This Matters

The INT3472 device is responsible for:
1. Camera power management (turning the camera on/off)
2. Camera reset control
3. Privacy LED control
4. Clock generation for the camera sensor

Without the GPIO controller, INT3472 cannot control these functions, so the camera sensor never gets powered on and initialized, which means no /dev/video* devices are created.

## Solution Options

### Option 1: Try Linux Mainline 6.17 (RECOMMENDED)
Lunar Lake is very new (released 2024), and GPIO/pinctrl support may have been added in newer kernels.

**Steps:**
```bash
# Install mainline kernel from AUR
yay -S linux-mainline linux-mainline-headers

# Edit /boot/loader/entries/ to add mainline boot entry
sudo cp /boot/loader/entries/arch.conf /boot/loader/entries/arch-mainline.conf
# Edit the file to point to linux-mainline kernel

# Reboot and select mainline kernel
sudo reboot
```

### Option 2: Check for Out-of-Tree Driver
Look for Intel or community-provided Lunar Lake GPIO drivers.

### Option 3: Wait for Kernel Updates
Arch Linux kernel will eventually include Lunar Lake GPIO support once it's merged into mainline.

### Option 4: Use External Webcam (Temporary Workaround)
While waiting for driver support, use a USB webcam.

## Technical Details

### ACPI Device Information
- **Device**: INTC10B5:00
- **ACPI Path**: `_SB_.PC00.XHCI.RHUB.HS02.VGPO`
- **Location**: /sys/bus/platform/devices/INTC10B5:00
- **Status**: Device present but no driver bound

### Camera-Related ACPI Devices
- INT3472:00-0b (Camera GPIO/power management)
- INTC10B5:00 (GPIO controller - MISSING DRIVER)
- INTC10B6:00-01 (Related devices)
- OV02C10 sensor (needs power from INT3472)

### Module Dependencies
```
Camera Sensor (ov02c10)
    ↓ requires power/control from
INT3472 (camera power management)
    ↓ requires GPIO from
INTC10B5 (GPIO controller) ← MISSING DRIVER!
```

## Next Steps

1. **Try linux-mainline 6.17** - Most likely to have Lunar Lake support
2. **Monitor Arch Linux kernel updates** - Check release notes for Lunar Lake GPIO support
3. **Check Intel Linux Graphics repository** - May have patches or information
4. **Report to Arch Linux forums** - Help others with same hardware

## Additional Resources

- Intel IPU6/IPU7 drivers: https://github.com/intel/ipu6-drivers
- Intel Linux graphics: https://github.com/intel/linux-intel-lts
- Arch Linux Dell XPS 13 Wiki: https://wiki.archlinux.org/title/Dell_XPS_13


