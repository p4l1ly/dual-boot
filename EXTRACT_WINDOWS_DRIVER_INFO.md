# How to Extract Windows Driver Information for INTC10B5

## If You Have Windows Dual-Boot

Since you mentioned "dual-boot" in your folder name, if you have Windows installed, we can extract driver information WITHOUT reverse engineering!

### Method 1: Get INF File from Windows

**Boot into Windows**, then:

1. **Find the device in Device Manager**:
   - Open Device Manager (devmgmt.msc)
   - Look for "INTC10B5" or "Virtual GPIO" or "Lattice"
   - Right-click → Properties → Details tab
   - Change dropdown to "Hardware Ids"
   - Screenshot or copy the IDs

2. **Export driver INF**:
   - Still in Properties → Driver tab
   - Click "Driver Details"
   - Note the .inf file location (e.g., `C:\Windows\System32\DriverStore\...`)
   - Copy the .inf file to a USB drive

3. **Get the driver package**:
   ```
   C:\Windows\System32\DriverStore\FileRepository\
   ```
   - Find folder with the INF
   - Copy entire folder to USB

### Method 2: Download from Dell

Visit Dell's support site:
```
https://www.dell.com/support/home/en-us/product-support/product/xps-13-9350/drivers
```

Look for:
- "Intel Serial IO Driver"
- "Intel Chipset Driver"  
- "Camera Driver"
- "GPIO Driver"

Download and extract (use 7-zip or similar to extract .exe files).

### Method 3: Windows Update Catalog

Visit: https://www.catalog.update.microsoft.com/

Search for:
- "INTC10B5"
- "Intel GPIO Lunar Lake"
- "Intel Serial IO Lunar Lake"

### What to Look For in INF Files

Once you have the INF file, look for:

```ini
[INTC10B5.NT]
; This section shows hardware configuration

[Strings]
; This shows device descriptions

[AddReg]
; Registry settings may reveal configuration details
```

### Information We Need

From INF file we can learn:
1. **Register offsets** - Memory-mapped register addresses
2. **Pin count** - How many GPIO pins
3. **Pin functions** - What each pin does
4. **Dependencies** - What other drivers it needs
5. **Configuration** - Default settings
6. **ACPI methods** - Which ACPI calls it uses

### How to Get INF to Linux

**If you boot into Windows**:
1. Copy driver files to USB stick
2. Boot back to Linux
3. Mount USB: `sudo mount /dev/sdX1 /mnt`
4. Copy INF files: `cp /mnt/*.inf ~/`
5. I can analyze them!

## If You DON'T Have Windows

### Method 1: Windows Driver Catalog Search

I can search for you:
```bash
curl "https://www.catalog.update.microsoft.com/Search.aspx?q=INTC10B5"
```

### Method 2: Dell Driver Download (from Linux)

```bash
# Search Dell's driver repository
curl -s "https://www.dell.com/support/home/product-support/product/xps-13-9350/drivers" | grep -i gpio
```

### Method 3: Community Sources

Check if anyone uploaded the drivers:
- Station-Drivers.com (driver repository)
- DevID.info (driver database)
- GitHub (someone might have uploaded)

## What We Can Learn From INF

**Example from typical Intel GPIO INF**:
```ini
[INTC10B5.NT]
CopyFiles=Drivers_Dir

[Drivers_Dir]
IntelGpioUsb.sys

[INTC10B5.NT.HW]
AddReg=GPIO_AddReg

[GPIO_AddReg]
HKR,,GpioCount,0x00010001,10          ; 10 GPIO pins
HKR,,GpioBaseAddress,0x00010001,0x0   ; Base address
HKR,,Protocol,0x00000000,"LJCA"       ; Uses LJCA protocol (or custom?)
```

This would tell us:
- Number of pins
- Protocol used
- Whether it's compatible with LJCA or needs custom driver

## Quick Check You Can Do NOW

If you have Windows partition accessible from Linux:

```bash
# Mount Windows partition
sudo mkdir -p /mnt/windows
sudo mount /dev/nvme0n1pX /mnt/windows  # Replace X with Windows partition number

# Search for INTC10B5 in Windows drivers
find /mnt/windows/Windows/System32/DriverStore -name "*.inf" -exec grep -l "INTC10B5" {} \; 2>/dev/null

# If found, copy it
cp /path/to/found.inf ~/intc10b5-driver.inf

# Unmount
sudo umount /mnt/windows
```

Then I can analyze the INF file!

## Why This Is Better Than Reverse Engineering

**INF files are**:
- ✅ Plain text (no decompiling needed)
- ✅ Documented format (Microsoft INF spec exists)
- ✅ Legal to read (not binary reverse engineering)
- ✅ Contain hardware configuration details
- ✅ Show what the Windows driver expects

**With INF, we can write Linux driver**:
- Know exact hardware configuration
- Understand pin mappings
- See protocol details (LJCA vs custom)
- Much faster development (days not weeks)

## Next Steps

**Do you have Windows installed?**

**YES** → Boot Windows, export driver, analyze INF
**NO** → Try downloading from Dell/Microsoft catalog
**MAYBE** → Check if Windows partition is accessible

Let me know and I'll guide you through extraction and analysis!

