# Reinstall Checklist for Dell XPS

## Current State
- Previous installation attempt exists
- EFI partition (p1) has Linux files mixed with Windows
- Boot partition (p5) may have old files
- Root partition (p6) may have old LUKS container
- Other partitions (p7, p8) may have old LUKS containers

## Before Reinstalling

### Option A: Full Clean Reinstall (Recommended)
This will reformat everything and start fresh.

```bash
# On Dell XPS (from Arch USB):

# 1. Clean up EFI partition
sudo ./cleanup-efi-for-reinstall.sh

# 2. Run partition-setup.sh and choose:
#    - Option 2 if partitions don't exist yet, or
#    - Skip if partitions already exist (p5-p8)
sudo ./partition-setup.sh

# 3. Format Linux partitions (this will destroy old LUKS containers)
#    - Choose option 3 in partition-setup.sh
#    - This will:
#      - Format p5 as FAT32 (XBOOTLDR)
#      - Create new LUKS containers on p6, p7, p8
#      - Format encrypted volumes as ext4

# 4. Run installation
sudo ./arch-install.sh
```

### Option B: Partial Clean (Keep Encrypted Data)
If you want to keep data on shared storage (p7):

```bash
# 0. Create password file (if not already done)
echo -n 'YourPassword' > luks-password.txt && chmod 600 luks-password.txt

# 1. Clean EFI partition
sudo ./cleanup-efi-for-reinstall.sh

# 2. Manually clean boot partition (p5)
sudo mount /dev/nvme0n1p5 /mnt
sudo rm -rf /mnt/*
sudo umount /mnt

# 3. Reformat p5 as FAT32
sudo mkfs.vfat -F 32 -n "XBOOTLDR" /dev/nvme0n1p5

# 4. Keep existing LUKS on p7 (shared)
#    but reformat p6 (root) and p8 (swap):
sudo cryptsetup luksFormat /dev/nvme0n1p6  # Root
sudo cryptsetup luksFormat /dev/nvme0n1p8  # Swap

# 5. Run arch-install.sh
#    It will detect existing LUKS on p7 and ask for password
sudo ./arch-install.sh
```

## What Gets Cleaned

### EFI Partition (p1) - `cleanup-efi-for-reinstall.sh` removes:
- ✗ `EFI/systemd/` - systemd-boot binaries
- ✗ `linux/` - If it exists
- ✗ `loader/` - Boot configuration
- ✗ Kernel files (vmlinuz-*, initramfs-*, intel-ucode.img)
- ✗ UEFI boot entries for "Linux Boot Manager"

### EFI Partition (p1) - Preserved:
- ✓ `EFI/Microsoft/` - Windows Boot Manager
- ✓ `EFI/Dell/` - Dell firmware
- ✓ `EFI/Boot/` - Fallback bootloader
- ✓ `System Volume Information` - Windows metadata

### Boot Partition (p5) - `partition-setup.sh` option 3:
- Reformats as FAT32 (destroying all old files)
- Sets partition type to XBOOTLDR

### Root Partition (p6) - `partition-setup.sh` option 3:
- Creates new LUKS container (destroys old data)
- Formats as ext4

### Shared Partition (p7) - `partition-setup.sh` option 3:
- Creates new LUKS container (destroys old data)
- Formats as ext4

### Swap Partition (p8) - `partition-setup.sh` option 3:
- Creates new LUKS container
- Sets up as swap

## Important Notes

### 🔴 Data Loss Warning
Running `partition-setup.sh` option 3 will **destroy all data** on p5-p8!
- All files on boot partition
- All encrypted data on root, shared, swap
- **Backup anything important first!**

### ✅ Windows Safety
- Windows partitions (p1-p4) are **not touched**
- `cleanup-efi-for-reinstall.sh` only removes Linux files from p1
- Windows will remain bootable

### 🔑 LUKS Passwords
If you're creating new LUKS containers, you can:
- Use the same passwords as before
- Use different passwords
- The old LUKS containers will be completely destroyed

## Reinstall Steps (Detailed)

### 1. Boot from Arch USB
```bash
# Connect to WiFi
iwctl
> station wlan0 connect "YourWiFi"
> quit

# Sync time
timedatectl set-ntp true
```

### 2. Transfer Scripts
```bash
# Mount USB stick with scripts
mkdir -p /mnt/usb
mount /dev/sdX1 /mnt/usb  # Your USB stick
cp -r /mnt/usb/dual-boot /root/
cd /root/dual-boot
```

### 3. Clean EFI
```bash
sudo ./cleanup-efi-for-reinstall.sh
# Review output, confirm cleanup
```

### 4. Check Partitions
```bash
lsblk /dev/nvme0n1
# Verify p5-p8 exist
# If not, run: sudo ./partition-setup.sh (option 2)
```

### 5. Format Partitions
```bash
sudo ./partition-setup.sh
# Choose option 3: Format Linux partitions
# Enter new LUKS passwords when prompted
```

### 6. Install Arch
```bash
sudo ./arch-install.sh
# Follow prompts
# Enter LUKS passwords when needed
```

### 7. Reboot
```bash
# After installation completes:
reboot
```

### 8. Verify Boot
- Should see systemd-boot menu
- Two entries: Arch Linux, Arch Linux (fallback)
- Windows Boot Manager option
- Select Arch Linux
- Enter LUKS password
- Should boot to GNOME login

## Troubleshooting

### If systemd-boot doesn't show Arch entries:
```bash
# Boot from USB again
sudo mount /dev/nvme0n1p5 /mnt/boot
sudo mount /dev/nvme0n1p1 /mnt/boot/efi
ls -la /mnt/boot/          # Should see vmlinuz-linux, etc.
ls -la /mnt/boot/efi/EFI/  # Should see systemd/
# Check boot entries exist:
ls -la /mnt/boot/loader/entries/
```

### If boot partition isn't FAT32:
```bash
# Check filesystem:
sudo blkid /dev/nvme0n1p5
# Should show: TYPE="vfat"
# If not, reformat:
sudo mkfs.vfat -F 32 -n "XBOOTLDR" /dev/nvme0n1p5
```

## Summary

**Recommended approach:**
1. ✅ Run `cleanup-efi-for-reinstall.sh` to clean EFI
2. ✅ Run `partition-setup.sh` option 3 to reformat all Linux partitions
3. ✅ Run `arch-install.sh` with the now-corrected FAT32 boot partition
4. ✅ Boot into working Arch Linux with proper XBOOTLDR setup

This will give you a clean installation using FAT32 for p5, so systemd-boot will work correctly without any hooks!

