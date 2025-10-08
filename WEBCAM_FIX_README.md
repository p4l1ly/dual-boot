# Dell XPS 13 Webcam Fix Guide

## Current Status

Your Dell XPS 13 with Intel Lunar Lake processor has the following:
- **Graphics**: Intel Arc 130V/140V (Lunar Lake)
- **Camera**: OmniVision OV02C10 sensor (detected via `ov02c10` module)
- **Camera Controller**: Lattice AI USB device (Bus 003 Device 002: ID 2ac1:20c9)

## Installed Packages

You've already installed:
- `intel-ipu7-dkms-git` (r42.62a3704) - IPU7 camera drivers
- `intel-ipu7-camera-bin` - IPU7 camera binaries
- `intel-ivsc-firmware` - Intel Video Services Client firmware

## Problem

The camera is detected but `/dev/video*` devices are not appearing. This is because:

1. **libcamera is not installed** - Needed for modern Intel MIPI cameras
2. **IPU7 DKMS modules are not built** - The source is installed but not compiled
3. **IVSC modules may not be loading** - Intel Video Services Client drivers

## Solution Steps

### Step 1: Install libcamera

```bash
sudo pacman -S --needed libcamera pipewire-libcamera libcamera-ipa libcamera-tools
```

### Step 2: Build IPU7 DKMS Modules (if needed)

The IPU7 drivers might need to be built with DKMS:

```bash
./build-ipu7-modules.sh
```

**Note**: Lunar Lake (your CPU) might actually use IPU7, not IPU6. The kernel has IPU6 built-in, but you installed IPU7 from AUR.

### Step 3: Load Kernel Modules and Diagnose

```bash
./fix-webcam.sh
```

This script will:
- Load necessary kernel modules (IVSC, IPU, MEI)
- Check for video devices
- Display diagnostic information

### Step 4: Test the Webcam

```bash
./test-webcam.sh
```

This will test if the camera is working with both v4l2 and libcamera.

## Alternative: Try Built-in IPU6 Modules

If IPU7 doesn't work, you might need to use the kernel's built-in IPU6 support instead:

```bash
# Remove IPU7 packages
sudo pacman -R intel-ipu7-dkms-git intel-ipu7-camera-bin

# Load IPU6 modules
sudo modprobe intel-ipu6
sudo modprobe intel-ipu6-isys
```

## Troubleshooting

### Check kernel messages for errors:
```bash
sudo dmesg | grep -i -E "camera|ipu|ivsc|ov02"
```

### Check if firmware is missing:
```bash
sudo dmesg | grep -i firmware
```

### List all camera-related modules:
```bash
lsmod | grep -E "ipu|ivsc|ov02|mei|video"
```

### Check USB devices:
```bash
lsusb -v | grep -A 20 "Lattice"
```

## Common Issues

1. **Missing firmware**: Install `linux-firmware` package
2. **Conflicting drivers**: Unload old modules before loading new ones
3. **Permissions**: Make sure your user is in the `video` group: `sudo usermod -aG video $USER`
4. **Reboot needed**: Sometimes a reboot is needed for everything to work

## Additional Resources

- Intel IPU6/IPU7 documentation: https://github.com/intel/ipu6-drivers
- Dell XPS 13 (9350) Linux support: https://wiki.archlinux.org/title/Dell_XPS_13
- libcamera documentation: https://libcamera.org/

## Quick Start

Run these commands in order:

```bash
# Install dependencies
sudo pacman -S --needed libcamera pipewire-libcamera libcamera-ipa libcamera-tools dkms

# Build IPU7 modules (may fail if not needed)
./build-ipu7-modules.sh

# Load modules and diagnose
./fix-webcam.sh

# Test camera
./test-webcam.sh
```

If the camera still doesn't work after these steps, you may need to reboot for all changes to take effect.



