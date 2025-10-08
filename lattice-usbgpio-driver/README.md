# Lattice NX33 USB-GPIO Linux Driver (EXPERIMENTAL)

## Status: 70% Complete, Needs Testing

This is a **skeleton driver** for the Lattice NX33 USB-GPIO bridge (device ID 2ac1:20c9) used in Dell XPS 13 9350 (2024) Lunar Lake laptops.

## What This Driver Does

Provides GPIO operations over USB for the INTC10B5 virtual GPIO controller, enabling camera power management.

## Based On

- Intel's Windows drivers (UsbBridge.sys v4.0.1.346)
- Binary analysis revealing USB protocol commands
- LJCA driver architecture

## Known Facts ✅

- USB Device: 2ac1:20c9 (Lattice NX33)
- Protocol: 4-byte ASCII commands over USB bulk
- Commands: GPIOD (direction), GPIOI (I/O)
- Endpoints: Bulk IN + Bulk OUT

## Guesses ⚠️ (Need Verification)

- Command packet format
- Response packet format
- Pin count (guessed 10)
- No initialization needed

## How to Test

### Prerequisites
```bash
sudo pacman -S linux-headers base-devel
```

### Compile
```bash
cd /home/paly/hobby/dual-boot/lattice-usbgpio-driver
make
```

### Load Driver
```bash
# Remove ljca if loaded (conflicts)
sudo modprobe -r gpio-ljca i2c-ljca usb-ljca

# Load our driver
sudo insmod lattice-bridge.ko

# Check if it probed
dmesg | tail -30
```

### Expected Output (Success)
```
[   XX.XXXXXX] lattice-usbgpio: Lattice NX33 USB-GPIO bridge detected
[   XX.XXXXXX] lattice-usbgpio: Bulk IN: 0x81, Bulk OUT: 0x01
[   XX.XXXXXX] lattice-usbgpio: Lattice NX33 GPIO chip registered with 10 pins
```

### Expected Output (Failure - Protocol Wrong)
```
[   XX.XXXXXX] lattice-usbgpio: USB send failed: -110 (timeout)
[   XX.XXXXXX] lattice-usbgpio: USB send failed: -32 (pipe error)
```

### Check GPIO Chip
```bash
# Look for new gpiochip
cat /sys/kernel/debug/gpio

# Or
gpioinfo | grep lattice
```

### Test GPIO (If Chip Appears)
```bash
# Try to trigger INT3472 to reprobe
echo -n "INT3472:00" | sudo tee /sys/bus/platform/drivers/int3472-discrete/bind

# Check for errors
sudo dmesg | grep INT3472 | tail -10
```

## Debugging

### If Driver Loads But No GPIO Chip
- Protocol commands might be wrong
- Check dmesg for errors
- May need initialization sequence

### If USB Timeout Errors
- Command format wrong
- Try different packet sizes
- May need handshake first

### If Driver Doesn't Load
- Check: `dmesg | grep lattice`
- Compilation errors: check syntax
- USB binding: check lsusb shows device

## Next Steps for Development

1. **Test probe** - Does driver bind to USB device?
2. **Check GPIO registration** - Does gpio chip appear?
3. **Test commands** - Do GPIO operations work?
4. **Refine protocol** - Adjust based on errors
5. **Add initialization** - If device needs setup
6. **Handle interrupts** - For GPIO interrupts
7. **Add second driver** - Platform driver for INTC10B5

## WARNING

This is EXPERIMENTAL code that:
- ✅ Should compile
- ⚠️ Might crash (kernel module risks)
- ⚠️ Protocol is guessed
- ❌ Not tested on hardware

**Backup your data before testing!**

## Success Criteria

If this works, you should see:
1. Driver loads without errors
2. GPIO chip appears (lattice-nx33-gpio)
3. INT3472 stops complaining about missing GPIO
4. Sensor initializes
5. /dev/v4l-subdev* devices appear
6. icamerasrc finds sensors
7. **Webcam works!**

## Files

- `lattice-bridge.c` - Main driver code
- `Makefile` - Build system
- `README.md` - This file

## Current Limitations

- Only implements USB bridge (not ACPI platform driver yet)
- Protocol details guessed from binary analysis
- No interrupt support
- No error recovery
- Minimal testing

## If It Doesn't Work

We can:
1. Capture USB traffic on Windows
2. Decompile driver for exact protocol
3. Refine and iterate
4. File detailed bug report to Intel with our findings

Want to try it?

