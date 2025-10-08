# GitHub Comment Draft for Issue #26

Copy and paste this into: https://github.com/intel/ipu7-drivers/issues/26

---

## Intel's Windows Drivers Exist - 17 Months Old, Still No Linux Port

I'm experiencing the exact same issue on **Dell XPS 13 9350 (2024)** with Lunar Lake and have done extensive investigation.

### Key Finding: Intel Already Has The Drivers (For Windows)

By examining my Windows dual-boot partition, I found **two Intel drivers** that solve this problem:

#### 1. UsbBridge.sys v4.0.1.346 (May 9, 2024)
```
Location: C:\Windows\System32\DriverStore\FileRepository\usbbridge.inf_amd64_...\
Supports: USB\VID_2AC1&PID_20C9 (Lattice NX33 FPGA)
Purpose: USB-GPIO bridge driver
```

#### 2. UsbGpio.sys v1.0.2.733 (May 8, 2024)
```
Location: C:\Windows\System32\DriverStore\FileRepository\usbgpio.inf_amd64_...\
Supports: ACPI\INTC10B5 (Lunar Lake virtual GPIO)
Platforms: TGL, ADL, RPL, MTL, ARL, LNL, MTL CVF, PTL
Purpose: Platform driver connecting ACPI device to USB GPIO
```

### What This Means

1. **This is NOT Dell-specific hardware** - It's official Intel platform support
2. **This is NOT experimental** - Production drivers (v4.0 and v1.0)  
3. **This is NOT a new problem** - Drivers have existed since **May 2024**
4. **This is NOT a maybe** - Intel **already solved this** for Windows

We're now in **October 2025** - **17 months** since the Windows drivers were released, and still no Linux port.

### Community Proof of Concept

To demonstrate this is technically feasible, I reverse-engineered the Windows drivers and created a Linux port:

**What I built**:
- `lattice-bridge.c` - USB driver for Lattice NX33 (VID_2AC1, PID_20C9)
- `usbgpio-platform.c` - Platform driver for ACPI\INTC10B5
- Both compile and load successfully

**Status**: ~70% complete
- ✅ USB driver detects Lattice device
- ✅ GPIO chip registers (gpiochip5, 10 pins)
- ✅ Platform driver binds to INTC10B5
- ⚠️ Remaining: INT3472 integration architecture

**Time to create**: A few hours of reverse engineering
**Time for Intel to port**: Probably a few days (they have source code)

### Technical Details

**USB Protocol Commands** (found in binary):
- `GPIOD` (0x444F4950) - GPIO Direction control
- `GPIOI` (0x494F4950) - GPIO I/O operations

**Architecture**:
```
Camera → INT3472 power mgmt → INTC10B5 (ACPI) → UsbGpio driver → 
→ USB Bridge interface → UsbBridge driver → Lattice NX33 (USB 2ac1:20c9)
```

**Device**: Lattice NX33 FPGA used as USB-to-GPIO bridge

### Request to Intel

@intel Given that:
- ✅ You've already implemented this for Windows (May 2024)
- ✅ It's been **17 months** with no Linux port
- ✅ Multiple users are affected
- ✅ Community has proven it's technically feasible
- ✅ This is core platform support (not optional feature)

**Please**:
1. **Port UsbBridge.sys and UsbGpio.sys to Linux**, or
2. **Provide timeline** for when this will be available, or
3. **Provide technical guidance** so community can complete the port, or
4. **Explain** why this won't be supported on Linux

Silence for **17 months** while Windows drivers exist is not acceptable for platform-level hardware support.

### For Other Affected Users

If you're experiencing this issue:
- 👍 React to this comment to show demand
- 💬 Add your hardware details (laptop model, CPU)
- 🔗 Share on forums/social media for visibility

The more people affected we can show, the higher priority this becomes.

**Hardware affected**:
- Dell XPS 13 9350 (2024) - Lunar Lake
- Dell Pro Plus 14 PB14250 - Lunar Lake  
- [Add yours!]

---

**Thank you** to @glennmorris for filing this issue and the other community members investigating this!

---


