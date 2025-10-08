# Dell XPS 13 9350 (2024) Webcam - Final Status & Solution

## Current Situation (After All Debugging)

### ✅ What's Working

1. **Hardware Detection**: Camera hardware fully detected
   - Intel IPU7 at PCI 0000:00:05.0
   - OmniVision OV02C10 sensor (OVTI02C1:00)
   - Lattice AI USB controller (Bus 003 Device 003: ID 2ac1:20c9)

2. **Kernel Modules**: All camera modules loaded successfully
   - `intel_ipu7` + `intel_ipu7_isys` + `intel_ipu7_psys` 
   - `ipu-acpi` + `ipu-acpi-pdata` + `ipu-acpi-common` (manually built)
   - `ov02c10` sensor driver
   - `intel_skl_int3472` power management
   - `v4l2loopback` virtual camera

3. **Software Stack**: Complete Intel camera HAL installed
   - `libcamhal.so` - Intel camera HAL library
   - `icamerasrc` - GStreamer plugin for Intel cameras
   - Firmware in `/lib/firmware/intel/ipu/`
   - Configuration in `/etc/camera/ipu7x/`

4. **Video Devices**: IPU7 created all devices
   - `/dev/video0-31` - IPU7 capture devices
   - `/dev/media0` - Media controller
   - `/dev/video42` - v4l2loopback virtual camera

5. **IPU7 Driver**: Successfully initialized
   - "Found supported sensor OVTI02C1:00"
   - "Connected 1 cameras"
   - Firmware loaded
   - CSI2 pipeline configured

### ❌ What's NOT Working

**Single Blocker**: Missing GPIO driver for `INTC10B5` 

```
platform INT3472:00: deferred probe pending: int3472-discrete: Failed to get GPIO
```

**Impact**:
- INT3472 (camera power management) can't initialize
- Sensor never receives power/reset/clock
- No v4l2-subdev created for sensor
- HAL reports "No sensors available"
- Camera can't be accessed

## The Root Cause

### GPIO Controllers Present
- `INTC105D:00-04` - Working, using `intel-pinctrl` driver
- `INTC10B5:00` - **NO DRIVER** ← This is the problem

### What INTC10B5 Is
- **ACPI Path**: `_SB_.PC00.XHCI.RHUB.HS02.VGPO`
- **Purpose**: GPIO controller specifically for camera subsystem
- **Location**: Under USB hub (HS02 = High-Speed Port 2)
- **Why needed**: INT3472 uses these GPIO pins to control camera power/reset

### Current Kernel Support (6.16.10)
- `pinctrl-intel-platform`: Only supports `INTC105F`
- `pinctrl-meteorlake`: Only supports `INTC1082`, `INTC1083`, `INTC105E`
- **NO driver for INTC10B5**

## Research Findings (Web Searches)

### IPU7 Driver Status
✅ **IPU7 driver merged into Linux 6.17 (August 2025)**
- Source: Phoronix, kernel.org
- Available in staging area
- We already have this working!

### GPIO Driver Status  
❌ **NO Lunar Lake pinctrl driver found**
- Checked: Linux mainline (master branch)
- Checked: linux-next (development branch)
- Checked: Kernel 6.17, 6.18 changelogs
- Result: No `pinctrl-lunarlake.c` exists anywhere

### What Others Say
- Ubuntu/Fedora: Same IPU7 drivers, likely same GPIO issue
- No reports of Dell XPS 13 9350 (2024) webcam fully working on Linux yet
- Issue is hardware too new (Lunar Lake Sept 2024)

## Solutions Attempted

1. ✅ Installed all IPU7 packages and firmware
2. ✅ Built Intel camera HAL from source
3. ✅ Fixed DKMS bug (missing ipu-acpi modules)
4. ✅ Loaded LJCA USB GPIO modules (didn't help - different GPIO)
5. ✅ Created v4l2loopback bridge
6. ❌ Tried binding INTC10B5 to existing drivers (failed)
7. ❌ No GPIO driver supports INTC10B5

## What You Can Do Now

### Option 1: Monitor Kernel Updates (RECOMMENDED)

**Check weekly** after system updates:
```bash
sudo pacman -Syu
./monitor-kernel-for-lunarlake.sh
```

When support arrives, the script will detect it.

### Option 2: Check Kernel Development

Monitor these URLs monthly:
1. **Kernel git log**: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/log/drivers/pinctrl/intel
   - Search for: "Lunar Lake", "LNL", "INTC10B5"
   
2. **Mailing list**: https://lore.kernel.org/linux-gpio/
   - Search for: "INTC10B5" or "Lunar Lake GPIO"

### Option 3: File Bug Report

Help speed up development:
1. **Kernel Bugzilla**: https://bugzilla.kernel.org/
   - Component: "Drivers/GPIO"
   - Attach: dmesg output showing INTC10B5 errors
   
2. **Intel GitHub**: https://github.com/intel/ipu7-drivers/issues
   - Title: "Missing GPIO driver for INTC10B5 on Lunar Lake"

### Option 4: Use External Webcam

Temporary workaround:
- Buy any USB webcam (most work out-of-box on Linux)
- Use until kernel support arrives

## Expected Timeline

**Realistic estimate**:
- Lunar Lake released: September 2024
- Current date: October 2025 (13 months later)
- GPIO support: Should arrive soon (Q4 2025 or Q1 2026)
- Kernel version: Likely 6.18 or 6.19

**Why the delay**:
- Very new hardware
- GPIO/pinctrl drivers need careful testing
- Intel may be developing it now
- Could appear in next few kernel releases

## Summary for Arch Wiki

If you want to update the Arch Wiki XPS 9350 page:

**Current Status (Oct 2025)**:
- Webcam hardware: OV02C10 sensor with Intel IPU7
- IPU7 driver: ✅ Works in kernel >= 6.16
- Camera HAL: ✅ Can be built from Intel repos
- **Blocker**: Missing INTC10B5 GPIO driver
- **Status**: NOT WORKING due to kernel GPIO support gap
- **ETA**: Unknown, monitor kernel updates

## When It Will Work

The webcam will work when ONE of these happens:

1. **Kernel adds INTC10B5 support** (most likely)
   - Probably kernel 6.18 or 6.19
   - Will appear as `pinctrl-lunarlake` or similar
   - Check with: `./monitor-kernel-for-lunarlake.sh`

2. **Alternative driver emerges** (less likely)
   - Community or Intel out-of-tree driver
   - Check Intel GitHub repositories

3. **Workaround discovered** (unlikely)
   - Some way to bypass GPIO requirement
   - Not found after extensive debugging

## What We Learned

1. **DKMS bug**: intel-ipu7-dkms-git doesn't build ipu-acpi modules
2. **LJCA not the answer**: USB GPIO exists but doesn't provide INTC10B5
3. **HAL works**: Intel camera HAL builds and runs fine
4. **Hardware is fine**: Everything detected and working up to GPIO layer
5. **Kernel gap**: New hardware support takes 6-12 months typically

##Your Hardware is Perfect - Just Needs Kernel Support! 

The Dell XPS 13 9350 (2024) with Lunar Lake is **cutting edge** hardware. Linux support typically lags 6-12 months for new Intel platforms. You're experiencing a normal (if frustrating) part of using the latest hardware on Linux.

The good news: All your software is correctly installed and ready. The moment the kernel adds INTC10B5 support, your webcam will just work!


