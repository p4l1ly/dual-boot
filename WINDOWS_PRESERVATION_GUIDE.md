# Windows Preservation Guide for Dell XPS 13" 9350

## Your Current Partition Layout

Based on your existing Windows installation:

```
/dev/nvme0n1p1  EFI System              260MB   FAT32   (KEEP)
/dev/nvme0n1p2  Microsoft Reserved      16MB    NTFS    (KEEP)
/dev/nvme0n1p3  Windows Data            475.7GB NTFS    (SHRINK)
/dev/nvme0n1p4  Windows Recovery        990MB   NTFS    (KEEP)
```

## Target Layout After Linux Installation

```
/dev/nvme0n1p1  EFI System              260MB   FAT32   (existing)
/dev/nvme0n1p2  Microsoft Reserved      16MB    NTFS    (existing)
/dev/nvme0n1p3  Windows Data            ~150GB  NTFS    (shrunk)
/dev/nvme0n1p4  Windows Recovery        990MB   NTFS    (existing)
/dev/nvme0n1p5  Shared Storage          150GB   NTFS    (new)
/dev/nvme0n1p6  Linux Boot              512MB   EXT4    (new)
/dev/nvme0n1p7  Linux Root (Encrypted)  150GB   LUKS    (new)
/dev/nvme0n1p8  Linux Swap              32GB    LUKS    (new)
```

## Step-by-Step Process

### Step 1: Shrink Windows Partition (Do this FIRST in Windows)

1. **Boot into Windows**
2. **Open Disk Management** (`diskmgmt.msc`)
3. **Right-click on the large Windows partition** (475.7GB)
4. **Select "Shrink Volume"**
5. **Shrink by approximately 325GB** (150GB + 512MB + 150GB + 32GB + some buffer)
6. **Leave the space unallocated** - don't create new partitions yet

### Step 2: Boot Arch Linux Installation Media

1. Create Arch Linux USB
2. Boot from USB
3. Connect to internet

### Step 3: Use the Updated Partition Script

The script now has two modes:

#### Option A: Safe Mode (Recommended)
```bash
# Run the partition script
./partition-setup.sh

# Select option 4: "Add Linux partitions (SAFE - preserves Windows)"
```

This will:
- ✅ Keep all your Windows partitions intact
- ✅ Only add Linux partitions in the free space
- ✅ Preserve your Windows installation

#### Option B: Destructive Mode (NOT recommended for you)
```bash
# Select option 5: "Create new partition layout (DESTRUCTIVE)"
```
⚠️ **DO NOT USE THIS** - it will destroy your Windows installation

### Step 4: Run Installation Script

```bash
# The installation script is now updated for your partition layout
sudo ./arch-install.sh
```

## Key Differences from Original Plan

### Updated Partition References
- **EFI**: `/dev/nvme0n1p1` (260MB, existing)
- **Windows**: `/dev/nvme0n1p3` (shrunk to ~150GB)
- **Shared**: `/dev/nvme0n1p5` (150GB, new)
- **Linux Boot**: `/dev/nvme0n1p6` (512MB, new)
- **Linux Root**: `/dev/nvme0n1p7` (150GB encrypted, new)
- **Linux Swap**: `/dev/nvme0n1p8` (32GB encrypted, new)

### What's Preserved
- ✅ Your existing Windows installation
- ✅ Windows Recovery partition
- ✅ EFI boot configuration
- ✅ Microsoft Reserved partition

### What's Added
- 🆕 Shared NTFS partition for file sharing
- 🆕 Linux boot partition
- 🆕 Encrypted Linux root partition
- 🆕 Encrypted Linux swap partition

## Important Notes

### Before Starting
1. **Backup your data** - always have backups
2. **Shrink Windows partition first** in Windows Disk Management
3. **Disable Fast Startup** in Windows power settings
4. **Disable Secure Boot** temporarily in BIOS

### During Installation
1. Use the **safe partitioning option** (option 4)
2. The script will verify existing Windows partitions
3. Linux partitions will be added after Windows Recovery

### After Installation
1. **GRUB will be configured** to dual boot
2. **Re-enable Secure Boot** if desired (may need additional setup)
3. **Test both operating systems** boot properly

## Troubleshooting

### If Windows Doesn't Boot
1. Boot from Windows Recovery USB
2. Use `bootrec /fixboot` and `bootrec /fixmbr`
3. Check EFI boot entries with `efibootmgr -v`

### If Linux Doesn't Boot
1. Boot from Arch USB
2. Check GRUB configuration
3. Verify encryption setup

### If Shared Partition Not Accessible
1. Install `ntfs-3g` in Linux
2. Mount with proper permissions
3. Check Windows hasn't locked the partition

## Configuration Files Updated

All scripts and documentation have been updated to match your existing Windows layout:

- ✅ `partition-setup.sh` - Safe partitioning mode added
- ✅ `arch-install.sh` - Updated partition references
- ✅ `ARCH_DUAL_BOOT_GUIDE.md` - Updated layout
- ✅ `README.md` - Updated documentation

## Summary

Your setup is now **Windows-preservation friendly**! The key changes:

1. **Safe partitioning mode** preserves your Windows installation
2. **Updated partition numbers** match your existing layout
3. **Proper verification** ensures all partitions exist before installation
4. **Clear warnings** prevent accidental Windows destruction

Use **option 4** in the partition script to safely add Linux partitions while keeping your Windows installation intact.
