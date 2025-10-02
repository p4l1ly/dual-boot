# WSL + LUKS Encrypted Shared Storage Guide

## Overview

You've chosen an excellent approach: **LUKS encryption + WSL access**. This gives you:

- ✅ **Strong encryption**: Linux-native LUKS encryption
- ✅ **Linux access**: Direct, native access from Arch Linux
- ✅ **Windows access**: Via WSL (Windows Subsystem for Linux)
- ✅ **Security**: Full disk encryption for shared data
- ✅ **Performance**: No overhead on Linux side

## How It Works

### **Architecture:**
```
┌─────────────────┐    ┌─────────────────┐
│   Arch Linux    │    │     Windows     │
│                 │    │                 │
│  /mnt/shared ←──┼────┼──→ WSL Ubuntu   │
│  (native LUKS)  │    │    /mnt/shared  │
│                 │    │    ~/shared     │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────────────────┘
              LUKS Encrypted
           /dev/nvme0n1p5 (171GB)
```

### **Access Methods:**
- **Linux**: Direct mounting via `/mnt/shared`
- **Windows**: Via WSL → `\\wsl$\Ubuntu\home\username\shared`

## Installation Configuration

### **Partition Layout:**
```
/dev/nvme0n1p5  Shared Storage (LUKS)  171GB   EXT4 (encrypted)
```

### **Automatic Setup:**
The scripts now automatically:
1. **Create LUKS encrypted partition**
2. **Add to crypttab** for automatic decryption
3. **Add to fstab** for automatic mounting
4. **Configure keyfile** for passwordless boot
5. **Create WSL helper scripts**

## Linux Side Setup (Automatic)

### **Crypttab Configuration:**
```bash
# /etc/crypttab
shared UUID=<partition-uuid> /etc/keys/root.key luks
```

### **Fstab Configuration:**
```bash
# /etc/fstab  
/dev/mapper/shared /mnt/shared ext4 defaults,noatime 0 2
```

### **Result:**
- ✅ **Automatic decryption** on boot
- ✅ **Automatic mounting** to `/mnt/shared`
- ✅ **No password required** (uses keyfile)

## Windows Side Setup (Manual)

### **Step 1: Install WSL**
```powershell
# Run as Administrator in PowerShell
wsl --install
```

### **Step 2: Install Ubuntu (or preferred distro)**
```powershell
# Install Ubuntu (default)
wsl --install -d Ubuntu

# Or choose another distro
wsl --list --online
wsl --install -d <DistroName>
```

### **Step 3: Configure WSL for Encrypted Access**

#### **In WSL Ubuntu:**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install cryptsetup
sudo apt install cryptsetup -y

# List available disks
lsblk

# Open encrypted partition (enter LUKS password)
sudo cryptsetup open /dev/nvme0n1p5 shared

# Create mount point
sudo mkdir -p /mnt/shared

# Mount the partition
sudo mount /dev/mapper/shared /mnt/shared

# Create user-accessible symlink
ln -s /mnt/shared ~/shared

# Set permissions (if needed)
sudo chown -R $USER:$USER /mnt/shared
```

### **Step 4: Access from Windows**

#### **File Explorer:**
Navigate to: `\\wsl$\Ubuntu\home\<username>\shared`

#### **Command Prompt:**
```cmd
# Access via UNC path
dir \\wsl$\Ubuntu\home\username\shared

# Or map as network drive
net use Z: \\wsl$\Ubuntu\home\username\shared
```

## Automation Scripts

### **Linux Helper Script:**
The post-install script creates `~/bin/mount-shared-wsl` with WSL setup instructions.

### **WSL Mount Script:**
Create in WSL for easy mounting:

```bash
# ~/mount-shared.sh
#!/bin/bash
echo "Mounting encrypted shared partition..."

# Check if already mounted
if mountpoint -q /mnt/shared; then
    echo "Shared partition already mounted at /mnt/shared"
    exit 0
fi

# Open LUKS container
if [ ! -b /dev/mapper/shared ]; then
    echo "Opening LUKS container..."
    sudo cryptsetup open /dev/nvme0n1p5 shared
fi

# Create mount point if needed
sudo mkdir -p /mnt/shared

# Mount partition
sudo mount /dev/mapper/shared /mnt/shared

# Create symlink if needed
if [ ! -L ~/shared ]; then
    ln -s /mnt/shared ~/shared
fi

echo "Shared partition mounted successfully!"
echo "Access from Windows: \\\\wsl\$\\Ubuntu\\home\\$USER\\shared"
```

### **WSL Unmount Script:**
```bash
# ~/unmount-shared.sh
#!/bin/bash
echo "Unmounting encrypted shared partition..."

# Unmount partition
sudo umount /mnt/shared 2>/dev/null || true

# Close LUKS container
sudo cryptsetup close shared 2>/dev/null || true

echo "Shared partition unmounted successfully!"
```

## Usage Workflows

### **Daily Usage:**

#### **From Linux:**
```bash
# Files automatically available at:
/mnt/shared/

# Example: Copy files
cp document.pdf /mnt/shared/
```

#### **From Windows:**
```bash
# 1. Open WSL
wsl

# 2. Mount shared partition (if not auto-mounted)
~/mount-shared.sh

# 3. Access files
ls ~/shared/

# 4. From Windows File Explorer
# Navigate to: \\wsl$\Ubuntu\home\username\shared
```

### **File Operations:**

#### **Linux → Windows:**
```bash
# Copy file to shared storage
cp /home/user/document.pdf /mnt/shared/

# Access from Windows via WSL path
```

#### **Windows → Linux:**
```bash
# Save file to \\wsl$\Ubuntu\home\username\shared
# File appears in Linux at /mnt/shared/
```

## Security Benefits

### **Encryption:**
- 🔒 **LUKS AES-256**: Military-grade encryption
- 🔒 **Key management**: Secure keyfile storage
- 🔒 **Boot integration**: Automatic decryption

### **Access Control:**
- 🔒 **Linux**: Full filesystem permissions
- 🔒 **WSL**: User-level access control
- 🔒 **Windows**: WSL security boundary

### **Data Protection:**
- 🔒 **At rest**: Encrypted on disk
- 🔒 **In transit**: Local access only
- 🔒 **Boot time**: Requires system access

## Performance Characteristics

### **Linux Access:**
- ⚡ **Native speed**: Direct LUKS access
- ⚡ **No overhead**: Kernel-level encryption
- ⚡ **SSD optimized**: TRIM support enabled

### **WSL Access:**
- ⚡ **Good performance**: WSL2 kernel-based
- ⚡ **Network speed**: ~1GB/s typical
- ⚡ **Cached access**: Windows file system cache

## Troubleshooting

### **WSL Cannot Access Partition:**
```bash
# Check if WSL can see the disk
lsblk

# Verify cryptsetup is installed
which cryptsetup

# Check WSL version (need WSL2 for disk access)
wsl --status
```

### **Permission Issues:**
```bash
# Fix ownership in WSL
sudo chown -R $USER:$USER /mnt/shared

# Fix permissions
sudo chmod -R 755 /mnt/shared
```

### **Mount Fails:**
```bash
# Check if LUKS container is open
ls /dev/mapper/

# Check filesystem
sudo fsck /dev/mapper/shared

# Remount with specific options
sudo mount -t ext4 /dev/mapper/shared /mnt/shared
```

### **Windows Cannot Access WSL Path:**
1. **Ensure WSL is running**: `wsl --list --running`
2. **Check WSL networking**: `wsl hostname -I`
3. **Restart WSL**: `wsl --shutdown` then `wsl`

## Advanced Configuration

### **Auto-mount in WSL:**
Add to WSL `~/.bashrc`:
```bash
# Auto-mount shared partition on WSL startup
if [ ! -d ~/shared ] && [ -b /dev/nvme0n1p5 ]; then
    ~/mount-shared.sh
fi
```

### **Windows Startup Script:**
Create batch file to auto-start WSL:
```batch
@echo off
wsl -d Ubuntu -e ~/mount-shared.sh
```

### **Backup Strategy:**
```bash
# Backup LUKS header
sudo cryptsetup luksHeaderBackup /dev/nvme0n1p5 --header-backup-file shared-header.backup

# Store backup securely (not on same disk!)
```

## Summary

Your **LUKS + WSL** setup provides:

- ✅ **Strong encryption**: Linux-native LUKS
- ✅ **Dual access**: Native Linux + WSL Windows
- ✅ **Automatic mounting**: Seamless Linux integration  
- ✅ **Good performance**: Minimal overhead
- ✅ **Security**: Full disk encryption
- ✅ **Flexibility**: Standard Linux tools

This is an excellent choice for secure, cross-platform file sharing!
