# Arch Linux Dual Boot Installation Guide for Dell XPS 13" 9350

## Overview
This guide will help you set up Arch Linux alongside Windows on your Dell XPS 13" 9350 with encrypted partitions and a shared storage partition.

## Prerequisites
- Dell XPS 13" 9350 (258V, 32GB RAM, 512GB SSD, 13.4", OLED, 3K Touch)
- Windows 11/10 already installed
- USB drive (8GB+) for Arch Linux installation media
- Backup of important data

## Partition Strategy

### Recommended Layout (512GB SSD)
```
/dev/nvme0n1p1  EFI System Partition    512MB   FAT32
/dev/nvme0n1p2  Windows System          ~200GB  NTFS
/dev/nvme0n1p3  Shared Storage          ~100GB  NTFS
/dev/nvme0n1p4  Linux Boot             512MB   EXT4
/dev/nvme0n1p5  Linux Root (Encrypted) ~100GB  LUKS
/dev/nvme0n1p6  Linux Swap             8GB     LUKS
```

## Step 1: Prepare Windows

### 1.1 Disable Fast Startup and Secure Boot
1. Open PowerShell as Administrator
2. Run: `powercfg /h off`
3. Restart and enter BIOS/UEFI
4. Disable Secure Boot (temporarily)
5. Enable Legacy Boot if needed
6. Save and exit

### 1.2 Shrink Windows Partition
1. Open Disk Management (`diskmgmt.msc`)
2. Right-click Windows partition → Shrink Volume
3. Shrink by ~300GB (leave space for Linux + shared storage)
4. Create new partition for shared storage (100GB, NTFS)

## Step 2: Create Arch Linux Installation Media

### 2.1 Download Arch Linux ISO
```bash
# Download latest Arch Linux ISO
wget https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso
```

### 2.2 Create Bootable USB
```bash
# Using dd (replace /dev/sdX with your USB device)
sudo dd bs=4M if=archlinux-x86_64.iso of=/dev/sdX status=progress oflag=sync
```

## Step 3: Boot from USB and Prepare Installation

### 3.1 Boot Arch Linux
1. Insert USB drive
2. Boot from USB (F12 on Dell XPS)
3. Select "Arch Linux install medium"

### 3.2 Connect to Internet
```bash
# Check network interface
ip link

# Connect to WiFi (if needed)
iwctl
station wlan0 connect "YourNetworkName"
exit

# Test connection
ping -c 3 archlinux.org
```

### 3.3 Update System Clock
```bash
timedatectl set-ntp true
```

## Step 4: Partition the Disk

### 4.1 Identify Disk
```bash
lsblk
# Note your NVMe device (likely /dev/nvme0n1)
```

### 4.2 Create Partitions
```bash
# Use cfdisk for interactive partitioning
cfdisk /dev/nvme0n1

# Or use parted for scripted approach
parted /dev/nvme0n1
```

### 4.3 Format Partitions
```bash
# Format EFI partition (if not already formatted)
mkfs.fat -F32 /dev/nvme0n1p1

# Format Linux boot partition
mkfs.ext4 /dev/nvme0n1p6

# Create encrypted containers
cryptsetup luksFormat /dev/nvme0n1p7
cryptsetup luksFormat /dev/nvme0n1p8

# Open encrypted containers
cryptsetup open /dev/nvme0n1p7 root
cryptsetup open /dev/nvme0n1p8 swap

# Format encrypted partitions
mkfs.ext4 /dev/mapper/root
mkswap /dev/mapper/swap
```

## Step 5: Install Arch Linux

### 5.1 Mount Partitions
```bash
# Mount root partition
mount /dev/mapper/root /mnt

# Create boot directory and mount
mkdir /mnt/boot
mount /dev/nvme0n1p6 /mnt/boot

# Create EFI directory and mount
mkdir /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
```

### 5.2 Install Base System
```bash
# Install base packages and essential tools
pacstrap /mnt base base-devel linux linux-firmware efibootmgr

# Install Intel-specific packages for Dell XPS
pacstrap /mnt intel-media-driver intel-ucode libva-intel-driver vulkan-intel

# Install audio system
pacstrap /mnt pipewire pipewire-alsa pipewire-jack pipewire-pulse gst-plugin-pipewire wireplumber sof-firmware

# Install network tools
pacstrap /mnt iwd wireguard-tools

# Install development tools
pacstrap /mnt git neovim rust-analyzer rustup go ghcup-hs-bin pyenv npm yarn uv

# Install desktop environment
pacstrap /mnt gdm gnome-control-center gnome-tweaks gnome-browser-connector nautilus

# Install system utilities
pacstrap /mnt htop ncdu tree less man-db net-tools usbutils pv trash-cli zram-generator

# Install package management
pacstrap /mnt yay-bin pkgfile

# Install shell and terminal
pacstrap /mnt zsh oh-my-zsh-git fzf direnv

# Install fonts
pacstrap /mnt noto-fonts-emoji ttf-fira-code ttf-fira-mono

# Install file system support
pacstrap /mnt ntfs-3g unrar zip

# Install web browsers
pacstrap /mnt firefox chromium

# Install communication tools
pacstrap /mnt discord slack-desktop zoom

# Install office suite
pacstrap /mnt libreoffice-fresh thunderbird

# Install media tools
pacstrap /mnt vlc gimp inkscape obs-studio

# Install PDF viewer
pacstrap /mnt zathura zathura-pdf-poppler

# Install virtualization (optional)
pacstrap /mnt virtualbox virtualbox-guest-iso
```

### 5.3 Generate Fstab
```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

### 5.4 Chroot into New System
```bash
arch-chroot /mnt
```

## Step 6: Configure the System

### 6.1 Set Timezone
```bash
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
hwclock --systohc
```

### 6.2 Configure Locale
```bash
# Edit /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

### 6.3 Set Hostname
```bash
echo "dell-xps" > /etc/hostname
```

### 6.4 Configure Hosts File
```bash
cat >> /etc/hosts << EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	dell-xps.localdomain	dell-xps
EOF
```

### 6.5 Set Root Password
```bash
passwd
```

### 6.6 Create User Account
```bash
useradd -m -G wheel -s /bin/zsh username
passwd username
```

### 6.7 Configure Sudo
```bash
# Uncomment the wheel group line
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
```

## Step 7: Configure Bootloader

### 7.1 Install GRUB
```bash
pacman -S grub
```

### 7.2 Configure GRUB
```bash
# Edit /etc/default/grub
cat >> /etc/default/grub << EOF
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"
GRUB_CMDLINE_LINUX="cryptdevice=UUID=$(blkid -s UUID -o value /dev/nvme0n1p7):root"
EOF
```

### 7.3 Install GRUB
```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

## Step 8: Configure Encryption

### 8.1 Create Keyfile
```bash
mkdir -p /etc/keys
dd bs=512 count=4 if=/dev/urandom of=/etc/keys/root.key
chmod 600 /etc/keys/root.key
```

### 8.2 Add Keyfile to LUKS
```bash
cryptsetup luksAddKey /dev/nvme0n1p7 /etc/keys/root.key
cryptsetup luksAddKey /dev/nvme0n1p8 /etc/keys/root.key
```

### 8.3 Configure mkinitcpio
```bash
# Edit /etc/mkinitcpio.conf
cat >> /etc/mkinitcpio.conf << EOF
HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
EOF

# Regenerate initramfs
mkinitcpio -P
```

## Step 9: Configure Services

### 9.1 Enable Essential Services
```bash
systemctl enable gdm
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable fstrim.timer
```

### 9.2 Configure Network
```bash
# Install NetworkManager
pacman -S networkmanager

# Enable NetworkManager
systemctl enable NetworkManager
```

## Step 10: Final Steps

### 10.1 Exit Chroot and Reboot
```bash
exit
umount -R /mnt
reboot
```

### 10.2 Post-Installation Setup
1. Boot into Arch Linux
2. Login with your user account
3. Install additional packages from your packages.txt
4. Configure GNOME settings
5. Set up your development environment

## Step 11: Configure Shared Storage

### 11.1 Mount Shared Partition
```bash
# Create mount point
sudo mkdir /mnt/shared

# Add to fstab for automatic mounting
echo "/dev/nvme0n1p5 /mnt/shared ntfs-3g defaults,uid=1000,gid=1000,umask=0022,noatime 0 0" >> /etc/fstab

# Mount the partition
sudo mount -a
```

### 11.2 Set Permissions
```bash
sudo chown username:username /mnt/shared
```

## Troubleshooting

### Common Issues
1. **Boot fails**: Check GRUB configuration and encryption setup
2. **WiFi not working**: Install `iwd` and configure network
3. **Audio not working**: Check PipeWire configuration
4. **Touchpad not working**: Install `xf86-input-libinput`

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
```

## Security Considerations

1. **Encryption**: All Linux partitions are encrypted with LUKS
2. **Secure Boot**: Can be re-enabled after installation
3. **Firewall**: Consider installing `ufw` or `firewalld`
4. **Updates**: Regularly update system with `pacman -Syu`

## Performance Optimization

1. **SSD Optimization**: Enable TRIM with `fstrim.timer`
2. **Memory**: Use `zram-generator` for swap compression
3. **Power Management**: Install `tlp` for laptop power management
4. **Graphics**: Intel graphics drivers are optimized for Dell XPS

## Next Steps

1. Install additional packages from your curated list
2. Configure development environment
3. Set up backup strategy
4. Configure system monitoring
5. Customize GNOME desktop environment
