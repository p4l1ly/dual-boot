# Windows UsbGpio Driver Analysis - Key Findings

## What We Extracted from Windows Driver

### Driver Metadata
- **Filename**: UsbGpio.sys
- **Size**: 54,360 bytes (54 KB)
- **Version**: 1.0.2.733
- **Date**: May 8, 2024
- **Type**: Windows Kernel-Mode Driver (PE32+)
- **Framework**: KMDF (Kernel-Mode Driver Framework) v1.15
- **Manufacturer**: Intel Corporation

### Supported Hardware (from INF)
```
ACPI\INTC1074  ; Tiger Lake
ACPI\INTC1096  ; Alder Lake
ACPI\INTC100B  ; Raptor Lake
ACPI\INTC1007  ; Meteor Lake
ACPI\INTC10B2  ; Arrow Lake
ACPI\INTC10B5  ; Lunar Lake ← YOUR HARDWARE
ACPI\INTC10D1  ; Meteor Lake CVF
ACPI\INTC10E2  ; Panther Lake
```

### Key Function Names Found
```c
GpioReadWrite()              // Main GPIO operation
UsbGpioIntCallback()         // Interrupt callback
UsbBridgeIntfcChangeNotificationCb()  // USB bridge notifications
UsbGpioEvtDriverUnload()     // Cleanup
Read()                       // Read operation
Write()                      // Write operation
```

### Critical Architecture Detail

**"USB Bridge Target Handle is NULL"**

This reveals the driver architecture:
```
ACPI Platform (INTC10B5)
    ↓
UsbGpio.sys (Platform driver)
    ↓
"USB Bridge" (Abstraction layer)
    ↓
USB Device (Lattice 2ac1:20c9)
```

The driver uses an intermediate "USB Bridge" layer - it doesn't talk directly to USB!

### What This Means

**The Windows driver has TWO components**:

1. **UsbGpio.sys** - Platform driver (ACPI side)
   - We found this ✅
   - Registers as ACPI driver for INTC10B5
   - Provides GPIO operations
   - Communicates via "USB Bridge" interface

2. **USB Bridge Driver** - USB device side
   - We haven't found this yet ❌
   - Handles actual USB communication
   - Probably for Lattice device (2ac1:20c9)
   - Provides "USB Bridge" interface to UsbGpio.sys

### Linux Equivalent

For Linux, we'd need BOTH:

1. **Platform driver** (like pinctrl-meteorlake):
   - Binds to ACPI device INTC10B5
   - Registers GPIO chip
   - Uses USB bridge interface

2. **USB driver** (like usb-ljca):
   - Binds to USB device 2ac1:20c9
   - Implements USB protocol
   - Provides abstraction for platform driver

**This explains why LJCA failed!**
- LJCA is the right architecture (USB bridge)
- But uses Intel's LJCA protocol
- Lattice device probably uses different protocol
- Protocol mismatch = timeout error

## What We Learned

### Good News ✅
- Driver is small (54KB) - not complex
- Architecture is clear (platform + USB bridge)
- Intel maintains this across platforms
- Clean separation of concerns

### Bad News ❌
- Need TWO drivers (platform + USB)
- USB protocol unknown (no USB ID in platform driver)
- USB bridge layer is separate (need to find it)
- No technical details about protocol

## Next Steps for Investigation

### Find the USB Bridge Driver

**Search Windows drivers for**:
1. USB device 2ac1:20c9
2. "Lattice" driver
3. USB bridge component

Let me search:

