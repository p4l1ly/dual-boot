# Dell XPS 13" 9350 Dual Boot Installation Guide

## Overview

This guide sets up **Arch Linux + Windows dual boot** with:
- **BitLocker Windows** (existing, untouched)
- **LUKS encrypted Linux** (root + swap)
- **LUKS encrypted shared storage** (accessible via WSL)
- **Hibernation support** (40GB swap)

## Prerequisites

- Dell XPS 13" 9350 with Windows + BitLocker
- 8GB+ USB drive for Arch Linux
- **Windows partition already shrunk** (you must do this first)

## Step 1: Shrink Windows Partition (REQUIRED)

### In Windows:
1. **Open Disk Management** (`diskmgmt.msc`)
2. **Right-click Windows partition** (475.7GB BitLocker)
3. **Select "Shrink Volume"**
4. **Shrink by 325GB** (leaves ~150GB for Windows)
5. **Leave space unallocated** (don't create new partitions)

**Note**: BitLocker partitions can be resized from Windows without disabling encryption.

## Step 2: Create Arch Linux USB

```bash
# Download Arch Linux ISO
wget https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso

# Create bootable USB (replace /dev/sdX with your USB)
sudo dd bs=4M if=archlinux-x86_64.iso of=/dev/sdX status=progress oflag=sync
```

## Step 3: Boot Arch Linux

1. **Insert USB drive**
2. **Boot from USB** (F12 on Dell XPS)
3. **Connect to internet**:
   ```bash
   iwctl
   station wlan0 connect "NetworkName"
   exit
   ping -c 3 archlinux.org
   ```

## Step 4: Create Linux Partitions

```bash
# Run partition script
./partition-setup.sh

# Select option 2: "Add Linux partitions"
# This creates:
# p5: 171GB Shared (LUKS encrypted)
# p6: 512MB Linux Boot
# p7: 150GB Linux Root (LUKS encrypted)  
# p8: 40GB Linux Swap (LUKS encrypted)
```

## Step 5: Format Linux Partitions

```bash
# Format Linux partitions only (Windows untouched)
./partition-setup.sh

# Select option 3: "Format Linux partitions"
# Enter LUKS passwords when prompted
```

## Step 6: Install Arch Linux

```bash
# Run installation script
sudo ./arch-install.sh

# Script automatically:
# - Mounts encrypted partitions
# - Installs base system + packages
# - Configures GRUB for dual boot
# - Sets up hibernation support
# - Configures automatic mounting
```

## Step 7: Post-Installation Setup

```bash
# Boot into Arch Linux
# Login with your user account
# Run post-installation script
./post-install.sh

# This configures:
# - Shell and development environment
# - GNOME desktop
# - Hibernation
# - WSL access helpers
```

## Step 8: Set Up WSL Access (Windows)

### Install WSL:
```powershell
# In Windows PowerShell (Admin)
wsl --install
```

### Configure WSL for encrypted partition:
```bash
# In WSL Ubuntu
sudo apt update && sudo apt install cryptsetup

# Mount encrypted shared partition
sudo cryptsetup open /dev/nvme0n1p5 shared
sudo mkdir -p /mnt/shared
sudo mount /dev/mapper/shared /mnt/shared
ln -s /mnt/shared ~/shared
```

### Access from Windows:
Navigate to: `\\wsl$\Ubuntu\home\username\shared`

## Final Partition Layout

```
/dev/nvme0n1p1  EFI System              260MB   FAT32 (existing)
/dev/nvme0n1p2  Microsoft Reserved      16MB    NTFS (existing)
/dev/nvme0n1p3  Windows Data            150GB   BitLocker (shrunk)
/dev/nvme0n1p4  Windows Recovery        990MB   NTFS (existing)
/dev/nvme0n1p5  Shared Storage          171GB   LUKS (new)
/dev/nvme0n1p6  Linux Boot              512MB   EXT4 (new)
/dev/nvme0n1p7  Linux Root              150GB   LUKS (new)
/dev/nvme0n1p8  Linux Swap              40GB    LUKS (new)
```

## Key Features

### Security:
- ✅ **BitLocker Windows**: Existing encryption preserved
- ✅ **LUKS Linux**: Full encryption for all Linux partitions
- ✅ **LUKS Shared**: Encrypted shared storage

### Functionality:
- ✅ **Dual boot**: GRUB manages both Windows and Linux
- ✅ **Hibernation**: 40GB swap supports 32GB RAM + buffer
- ✅ **WSL access**: Shared partition accessible from Windows
- ✅ **Auto-mounting**: Encrypted partitions mount automatically

### Performance:
- ✅ **SSD optimized**: TRIM enabled for all partitions
- ✅ **Intel drivers**: Optimized for Dell XPS hardware
- ✅ **Power management**: TLP configured for laptop use

## Usage

### Daily Operations:

#### Linux:
```bash
# Shared storage automatically mounted at:
/mnt/shared/

# Hibernation:
sudo systemctl hibernate
```

#### Windows:
```bash
# Access shared storage via WSL:
\\wsl$\Ubuntu\home\username\shared

# Standard Windows hibernation works independently
```

### File Sharing:
```bash
# Linux → Windows
cp document.pdf /mnt/shared/

# Windows → Linux  
# Save to \\wsl$\Ubuntu\home\username\shared
# Appears in Linux at /mnt/shared/
```

## Troubleshooting

### Boot Issues:
- **Windows won't boot**: Use Windows Recovery USB
- **Linux won't boot**: Check GRUB configuration
- **Dual boot menu missing**: Run `grub-mkconfig`

### Encryption Issues:
- **Wrong password**: Check LUKS password
- **Mount fails**: Verify partition UUIDs in `/etc/crypttab`
- **WSL can't access**: Ensure cryptsetup installed in WSL

### WSL Issues:
- **Partition not visible**: Check WSL version (need WSL2)
- **Permission denied**: Fix ownership with `chown`
- **Mount fails**: Verify partition path in WSL

## Commands Summary

```bash
# Partition setup
./partition-setup.sh

# Installation
sudo ./arch-install.sh

# Post-installation
./post-install.sh

# WSL setup helper
~/bin/mount-shared-wsl

# Hibernation test
sudo systemctl hibernate
```

This setup provides a secure, encrypted dual boot system with seamless file sharing between Windows and Linux via WSL.
