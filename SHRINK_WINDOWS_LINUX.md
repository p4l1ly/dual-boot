# Shrinking Windows Partition from Linux

Since you don't have access rights to Windows Disk Management, we can safely shrink the Windows partition from Linux using `ntfsresize`.

## Prerequisites

1. **Boot from Arch Linux USB**
2. **Ensure Windows is properly shut down** (not hibernated)
3. **Install ntfs-3g** if not available: `pacman -S ntfs-3g`

## Method 1: Using the Partition Script (Recommended)

```bash
# Run the partition setup script
./partition-setup.sh

# Select option 4: "Shrink Windows partition (from Linux)"
```

This will:
- ✅ Check filesystem integrity
- ✅ Perform a dry run first
- ✅ Safely resize both filesystem and partition
- ✅ Show before/after layout

## Method 2: Manual Process

If you prefer to do it manually:

### Step 1: Check Current Layout
```bash
lsblk -f
parted /dev/nvme0n1 print
```

### Step 2: Check Windows Filesystem
```bash
# Check filesystem integrity
ntfsfix /dev/nvme0n1p3

# Get filesystem info
ntfsresize --info /dev/nvme0n1p3
```

### Step 3: Perform Dry Run
```bash
# Test resize to 151GB (150GB + 1GB buffer)
ntfsresize --no-action --size 154624M /dev/nvme0n1p3
```

### Step 4: Actual Resize
```bash
# Resize filesystem
ntfsresize --size 154624M /dev/nvme0n1p3

# Resize partition (get start sector first)
parted /dev/nvme0n1 unit s print
# Note the start sector of partition 3, then calculate new end
# For 151GB: new_end = start + (151 * 1024 * 1024 * 1024 / 512) - 1

# Resize partition
parted /dev/nvme0n1 resizepart 3 [new_end_sector]s
```

## Safety Features of the Script

### Pre-checks
- ✅ Verifies `ntfs-3g` is installed
- ✅ Checks filesystem integrity with `ntfsfix`
- ✅ Analyzes current partition info
- ✅ Performs dry run before actual resize

### Safe Sizing
- 🎯 Target: 150GB for Windows
- 🛡️ Buffer: +1GB safety margin
- 📊 Total: 151GB allocated to Windows

### Error Handling
- ❌ Stops if filesystem has errors
- ❌ Stops if dry run fails
- ❌ Provides clear error messages
- ❌ Suggests solutions for common issues

## Common Issues and Solutions

### "Dry run failed" Error
**Cause**: Files at the end of partition that can't be moved

**Solutions**:
1. Boot Windows and run disk defragmentation
2. Disable hibernation: `powercfg /h off`
3. Disable page file temporarily
4. Use a larger target size (e.g., 200GB instead of 150GB)

### "Access denied" or "Device busy"
**Cause**: Partition is mounted or in use

**Solutions**:
```bash
# Unmount if mounted
umount /dev/nvme0n1p3

# Check if any process is using it
lsof /dev/nvme0n1p3
fuser -v /dev/nvme0n1p3
```

### "Filesystem errors found"
**Cause**: NTFS filesystem corruption

**Solutions**:
1. Boot Windows and run `chkdsk C: /f`
2. Or use `ntfsfix` from Linux (limited repair capability)

## Verification

After shrinking, verify the results:

```bash
# Check new layout
parted /dev/nvme0n1 print
lsblk -f

# Verify filesystem
ntfsresize --info /dev/nvme0n1p3
```

## Next Steps

After successfully shrinking Windows:

1. **Run partition script**: `./partition-setup.sh`
2. **Select option 5**: "Add Linux partitions"
3. **Continue with installation**: `sudo ./arch-install.sh`

## Your Specific Case

Current layout:
```
p1: 260M EFI system
p2: 16M Microsoft reserved  
p3: 475.7G Windows data ← SHRINK THIS
p4: 990M Windows recovery
```

After shrinking:
```
p1: 260M EFI system
p2: 16M Microsoft reserved
p3: 150G Windows data ← SHRUNK
p4: 990M Windows recovery
[FREE SPACE: ~325GB for Linux partitions]
```

## Command Summary

```bash
# Quick shrink using the script
./partition-setup.sh shrink

# Or interactive menu
./partition-setup.sh
# Then select option 4
```

The script handles all the complexity and safety checks automatically!
