# Fix Windows Recovery Partition

## Problem
The Windows Recovery partition (p4) was accidentally formatted as ext4 during Linux partition creation, breaking Windows recovery functionality.

## Solution: Recreate Windows Recovery Partition

### Step 1: Boot into Windows

1. **Boot Windows normally** (if possible)
2. **Open Command Prompt as Administrator**

### Step 2: Check Current Partition Status

```cmd
diskpart
list disk
select disk 0
list partition
```

Look for:
- Partition 4: Should show as "Recovery" but may show wrong filesystem
- Note the size and position

### Step 3: Delete Corrupted Recovery Partition

⚠️ **CAUTION**: Only delete p4 if it's corrupted/formatted as ext4

```cmd
select partition 4
delete partition override
```

### Step 4: Create New Recovery Partition

```cmd
# Create recovery partition (adjust size as needed - typically 990MB)
create partition primary size=990
select partition 4
format fs=ntfs quick label="Recovery"
set id=de94bba4-06d1-4d40-a16a-bfd50179d6ac
active
assign letter=R
```

### Step 5: Populate Recovery Partition

#### Option A: Copy from Windows Installation Media
```cmd
# Insert Windows installation USB/DVD
# Copy recovery files
robocopy X:\Recovery R:\Recovery /E
robocopy X:\Boot R:\Boot /E
```

#### Option B: Create Recovery Environment
```cmd
# Create Windows RE
reagentc /setreimage /path R:\Recovery\WindowsRE
reagentc /enable
```

### Step 6: Update Boot Configuration

```cmd
# Update BCD for recovery
bcdedit /set {bootmgr} device partition=C:
bcdedit /set {default} recoveryenabled yes
bcdedit /set {default} recoverysequence {current}
```

### Step 7: Verify Recovery Partition

```cmd
reagentc /info
```

Should show:
- Windows RE status: Enabled
- Windows RE location: \\?\GLOBALROOT\device\harddisk0\partition4\Recovery\WindowsRE

## Alternative: Use Windows Recovery Tools

### Method 1: Windows Installation Media
1. **Boot from Windows installation USB**
2. **Choose "Repair your computer"**
3. **Advanced options** → **Command Prompt**
4. **Run the diskpart commands above**

### Method 2: Automatic Repair
1. **Boot Windows installation media**
2. **Repair your computer** → **Troubleshoot**
3. **Advanced options** → **Automatic Repair**
4. **Let Windows attempt to fix boot issues**

## Prevention for Future

### Update Partition Scripts
The partition creation script should:
1. **Detect existing recovery partition**
2. **Move it safely** instead of overwriting
3. **Preserve recovery data** during partition operations

### Backup Recovery Partition
Before any partition operations:
```cmd
# Create backup of recovery partition
dd if=/dev/nvme0n1p4 of=/backup/recovery_partition.img bs=1M
```

## Verification Steps

After fixing:

### 1. Test Windows Recovery
- **Settings** → **Update & Security** → **Recovery**
- **Reset this PC** → **Get started** (don't actually reset, just verify it starts)

### 2. Test Advanced Boot Options
- **Hold Shift** while clicking **Restart**
- **Troubleshoot** → **Advanced options** should be available

### 3. Check Recovery Agent
```cmd
reagentc /info
```

## If Recovery Can't Be Fixed

### Alternative: External Recovery Media
1. **Create Windows Recovery Drive**
   - **Settings** → **Update & Security** → **Recovery**
   - **Create a recovery drive**
   - **Use external USB drive**

2. **Keep Windows Installation Media**
   - **Download Windows Media Creation Tool**
   - **Create bootable USB**
   - **Use for recovery when needed**

## Notes

- **Recovery partition** is not critical for daily Windows operation
- **Windows will boot normally** without it
- **Recovery features** (Reset, System Restore from boot) won't work
- **External recovery media** can provide same functionality
