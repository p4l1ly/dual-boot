# Dell XPS 13" 9350 Dual Boot Setup

This repository contains everything you need to set up Arch Linux alongside Windows on your Dell XPS 13" 9350 with encrypted partitions and shared storage.

## Overview

Your new Dell XPS 13" 9350 (258V, 32GB RAM, 512GB SSD, 13.4", OLED, 3K Touch) will be configured with:

- **Dual Boot**: Windows + Arch Linux
- **Encryption**: Full disk encryption for Linux partitions using LUKS
- **Shared Storage**: NTFS partition accessible from both operating systems
- **Optimized Setup**: Intel-specific drivers and power management

## Files Overview

### 📋 `packages.txt`
Curated list of packages with comments indicating which ones are:
- Essential for your setup
- Intel-specific (keep for Dell XPS)
- Potentially outdated/unnecessary
- Experimental or legacy

### 📖 `ARCH_DUAL_BOOT_GUIDE.md`
Comprehensive step-by-step installation guide covering:
- Pre-installation preparation
- Partition strategy
- Arch Linux installation
- Encryption setup
- Bootloader configuration
- Post-installation configuration

### 🔧 `arch-install.sh`
Automated installation script that handles:
- Partition verification
- System installation
- Encryption configuration
- Bootloader setup
- Service configuration

### 💾 `partition-setup.sh`
Interactive partition management script for:
- Planning partition layout
- Creating partitions
- Formatting filesystems
- Setting up encryption

### ⚙️ `post-install.sh`
Post-installation configuration script for:
- Package installation
- Shell configuration
- Development environment setup
- GNOME desktop configuration
- Security hardening

## Quick Start

### 1. Prepare Windows
```bash
# Disable Fast Startup
powercfg /h off

# Shrink Windows partition in Disk Management
# Leave ~300GB for Linux + shared storage
```

### 2. Create Installation Media
```bash
# Download Arch Linux ISO
wget https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso

# Create bootable USB
sudo dd bs=4M if=archlinux-x86_64.iso of=/dev/sdX status=progress oflag=sync
```

### 3. Boot and Partition
```bash
# Boot from USB
# Connect to internet
ping -c 3 archlinux.org

# Run partition setup
sudo ./partition-setup.sh
```

### 4. Install Arch Linux
```bash
# Run automated installation
sudo ./arch-install.sh
```

### 5. Post-Installation Setup
```bash
# Boot into Arch Linux
# Run post-installation configuration
./post-install.sh
```

## Partition Layout

```
/dev/nvme0n1p1  EFI System Partition    512MB   FAT32
/dev/nvme0n1p2  Windows System          ~200GB  NTFS
/dev/nvme0n1p3  Shared Storage          ~100GB  NTFS
/dev/nvme0n1p4  Linux Boot             512MB   EXT4
/dev/nvme0n1p5  Linux Root (Encrypted) ~100GB  LUKS
/dev/nvme0n1p6  Linux Swap             8GB     LUKS
```

## Package Categories

### ✅ Keep These (Essential)
- Core system packages
- Intel-specific drivers
- Audio system (PipeWire)
- Development tools
- Desktop environment (GNOME)
- System utilities

### ⚠️ Review These (Consider Removing)
- AMD/Radeon graphics drivers (if Dell XPS doesn't have AMD GPU)
- NVIDIA graphics drivers (if Dell XPS doesn't have NVIDIA GPU)
- VMware graphics drivers (not needed for physical machine)
- LaTeX packages (large installation)
- Virtualization tools (if not needed)
- Wine/Windows compatibility (if not needed)

### ❌ Remove These (Unnecessary)
- `yay-bin-debug` (debug version)
- `unrar-free` (duplicate of unrar)
- `libpulse` (replaced by PipeWire)
- Fun utilities (`cowsay`, `fortune-mod`)

## Security Features

- **Full Disk Encryption**: All Linux partitions encrypted with LUKS
- **Secure Boot**: Can be re-enabled after installation
- **Firewall**: UFW configured with default deny incoming
- **Automatic Updates**: Unattended upgrades enabled
- **Backup**: Timeshift configured for system snapshots

## Performance Optimizations

- **SSD Optimization**: TRIM enabled with `fstrim.timer`
- **Memory Management**: ZRAM for swap compression
- **Power Management**: TLP configured for laptop optimization
- **Intel Graphics**: Optimized drivers for Dell XPS

## Troubleshooting

### Common Issues

1. **Boot fails after installation**
   - Check GRUB configuration
   - Verify encryption setup
   - Ensure EFI partition is properly mounted

2. **WiFi not working**
   - Install `iwd` package
   - Configure NetworkManager
   - Check firmware installation

3. **Audio not working**
   - Verify PipeWire installation
   - Check `sof-firmware` installation
   - Configure audio settings in GNOME

4. **Touchpad not working**
   - Install `xf86-input-libinput`
   - Check GNOME touchpad settings

### Useful Commands

```bash
# Check disk usage
df -h

# Check mounted filesystems
mount | grep nvme

# Check encryption status
cryptsetup status root

# Check boot entries
efibootmgr -v

# Check systemd services
systemctl list-unit-files --state=enabled

# Update system
sudo pacman -Syu
yay -Syu

# Create backup
sudo timeshift --create --comments "Manual backup"
```

## File System Performance

For the shared storage partition, NTFS is recommended over exFAT because:
- Better Linux compatibility with `ntfs-3g`
- More mature driver support
- Better performance for large files
- Windows compatibility maintained

## Next Steps After Installation

1. **Review Package List**: Go through `packages.txt` and remove unnecessary packages
2. **Configure Development Environment**: Set up your preferred tools and configurations
3. **Customize GNOME**: Install extensions and themes
4. **Set Up Backup Strategy**: Configure automated backups
5. **Security Hardening**: Review and enhance security settings
6. **Performance Tuning**: Optimize for your specific use case

## Support

If you encounter issues:
1. Check the troubleshooting section
2. Review the Arch Linux wiki
3. Check system logs: `journalctl -xe`
4. Verify hardware compatibility

## Contributing

Feel free to improve these scripts and documentation:
- Add more package categories
- Improve error handling
- Add more configuration options
- Enhance security features

---

**Note**: Always backup your data before proceeding with the installation. This setup will modify your disk partitions and may result in data loss if not done carefully.
