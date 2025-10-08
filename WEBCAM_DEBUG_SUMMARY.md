# Webcam Debugging Summary - Almost Working!

## Current Status: 95% Complete

### ✅ What's Working

1. **v4l2loopback module**: Loaded and created `/dev/video42`
2. **ipu-acpi modules**: Built and installed (was missing from DKMS config)
3. **Intel IPU7 driver**: Successfully loaded
4. **Camera hardware**: Detected by IPU7 driver
   - "Found supported sensor OVTI02C1:00"
   - "Connected 1 cameras"
5. **Video devices**: `/dev/video0-31` and `/dev/media0` created
6. **Media topology**: CSI2 and capture devices configured

### ❌ Remaining Issue

**libcamera can't find the sensor**
- Error: `No sensor found for /dev/media0`
- libcamera's "simple" pipeline doesn't support Intel IPU7

## Root Cause

The bridge scripts use `libcamerasrc` (generic libcamera), but Intel IPU7 cameras need `icamerasrc` (Intel's specific GStreamer element).

The setup script built `icamerasrc` but the bridge scripts weren't configured to use it.

## What We Fixed

1. **Module loading issue**: Added `LD_LIBRARY_PATH=/usr/local/lib` to scripts
2. **Missing ipu-acpi**: Manually built and installed the ipu-acpi modules that DKMS config forgot
3. **IPU7 dependency**: Fixed "Unknown symbol ipu_get_acpi_devices" error

## Next Steps

### Option 1: Use icamerasrc (Intel-specific)
Modify the bridge script to use `icamerasrc` instead of `libcamerasrc`

### Option 2: Test with native IPU7 devices
Try accessing `/dev/video0` directly with GStreamer/FFmpeg

### Option 3: Check if IPU7 HAL needs configuration
Intel IPU7 camera HAL might need additional configuration files

## Key Learnings

1. **DKMS bug**: The AUR `intel-ipu7-dkms-git` package doesn't build ipu-acpi modules
2. **Library paths**: `/usr/local/lib` must be in `LD_LIBRARY_PATH` for custom-built libcamera
3. **Pipeline mismatch**: Generic libcamera pipelines don't support all camera hardware
4. **GPIO not needed**: The IPU7 userspace approach bypasses the INTC10B5 GPIO issue entirely!

## Commands for Testing

```bash
# Check IPU7 status
lsmod | grep ipu
sudo dmesg | grep ipu7

# List video devices
v4l2-ctl --list-devices

# Check media topology
media-ctl -d /dev/media0 -p

# Test with icamerasrc (if available)
gst-inspect-1.0 icamerasrc

# Test direct capture
gst-launch-1.0 v4l2src device=/dev/video0 ! fakesink
```

## Files Modified

- `/home/paly/.local/bin/libcamera-bridge-run.sh` - Added LD_LIBRARY_PATH
- `/lib/modules/6.16.10-arch1-1/updates/dkms/ipu-acpi*.ko` - Manually installed

## Next Debug Session

Focus on:
1. Getting icamerasrc working
2. Or testing direct v4l2 access to IPU7 devices
3. Or configuring Intel camera HAL properly

