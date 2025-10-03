# Dell XPS 13" 9350 Dual Boot Setup

This repository contains everything you need to set up Arch Linux alongside Windows on your Dell XPS 13" 9350 with encrypted partitions and shared storage.

## Overview

Your new Dell XPS 13" 9350 (258V, 32GB RAM, 512GB SSD, 13.4", OLED, 3K Touch) will be configured with:

- **Dual Boot**: Windows + Arch Linux
- **Encryption**: Full disk encryption for Linux partitions using LUKS
- **Hibernation**: Full hibernation support with encrypted swap
- **Shared Storage**: NTFS partition accessible from both operating systems
- **Optimized Setup**: Intel-specific drivers and power management

## Files Overview

### 📋 `packages.txt`
Curated list of packages with comments indicating which ones are:
- Essential for your setup
- Intel-specific (keep for Dell XPS)
- Potentially outdated/unnecessary
- Experimental or legacy

### 📖 `INSTALLATION_GUIDE.md`
Streamlined installation guide with rigid steps:
- Windows partition shrinking (BitLocker safe)
- Linux partition creation and formatting
- Arch Linux installation
- WSL setup for shared storage access

### 🔧 `arch-install.sh`
Automated installation script that handles:
- Partition verification
- System installation
- Encryption configuration
- Bootloader setup
- Service configuration

### 💾 `partition-setup.sh`
Streamlined partition script for:
- Adding Linux partitions after Windows shrinking
- LUKS encryption setup
- No Windows partition modification

### ⚙️ `post-install.sh`
Post-installation configuration script for:
- Package installation
- Shell configuration
- Development environment setup
- GNOME desktop configuration
- Security hardening

## Quick Start

### 1. Shrink Windows Partition (REQUIRED FIRST)
```bash
# In Windows Disk Management (diskmgmt.msc)
# Right-click Windows partition → Shrink Volume
# Shrink by 325GB (BitLocker partitions can be resized safely)
```

### 2. Create Arch Linux USB
```bash
wget https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso
sudo dd bs=4M if=archlinux-x86_64.iso of=/dev/sdX status=progress oflag=sync
```

### 3. Install Linux Partitions
```bash
# Boot from USB, connect to internet
./partition-setup.sh  # Option 2: Add Linux partitions
./partition-setup.sh  # Option 3: Format Linux partitions
sudo ./arch-install.sh  # Install Arch Linux
./post-install.sh  # Configure system
```

### 4. Set Up WSL (Windows)
```powershell
wsl --install  # Install WSL
# In WSL: sudo cryptsetup open /dev/nvme0n1p5 shared
# Access: \\wsl$\Ubuntu\home\username\shared
```

## Partition Layout

```
/dev/nvme0n1p1  EFI System Partition    260MB   FAT32
/dev/nvme0n1p2  Microsoft Reserved      16MB    NTFS
/dev/nvme0n1p3  Windows System          150GB   NTFS
/dev/nvme0n1p4  Windows Recovery        990MB   NTFS
/dev/nvme0n1p5  Linux Boot             512MB   EXT4
/dev/nvme0n1p6  Linux Root (Encrypted) 150GB   LUKS
/dev/nvme0n1p7  Shared Storage (Encrypted) ~170GB LUKS (auto-sized)
/dev/nvme0n1p8  Linux Swap (Encrypted) 40GB    LUKS (sized for hibernation)
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
