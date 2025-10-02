#!/bin/bash

# Arch Linux Dual Boot Installation Script for Dell XPS 13" 9350
# This script automates the installation process after manual partitioning

set -e

# Configuration variables - Updated for existing Windows layout
DISK="/dev/nvme0n1"
EFI_PART="/dev/nvme0n1p1"      # EFI System Partition (260MB, existing)
MS_RESERVED_PART="/dev/nvme0n1p2" # Microsoft Reserved (16MB, existing)
WINDOWS_PART="/dev/nvme0n1p3"   # Windows Data Partition (shrunk, existing)
RECOVERY_PART="/dev/nvme0n1p4"  # Windows Recovery (990MB, existing)
SHARED_PART="/dev/nvme0n1p5"    # Shared Storage Partition (new)
BOOT_PART="/dev/nvme0n1p6"      # Linux Boot Partition (new)
ROOT_PART="/dev/nvme0n1p7"      # Linux Root Partition (encrypted, new)
SWAP_PART="/dev/nvme0n1p8"      # Linux Swap Partition (encrypted, new)
HOSTNAME="dell-xps"
USERNAME=""
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Get user input
get_user_input() {
    read -p "Enter username: " USERNAME
    if [[ -z "$USERNAME" ]]; then
        error "Username cannot be empty"
        exit 1
    fi
    
    read -p "Enter timezone (default: America/New_York): " TIMEZONE_INPUT
    if [[ -n "$TIMEZONE_INPUT" ]]; then
        TIMEZONE="$TIMEZONE_INPUT"
    fi
}

# Verify partitions exist
verify_partitions() {
    log "Verifying partitions..."
    
    if [[ ! -b "$EFI_PART" ]]; then
        error "EFI partition $EFI_PART not found"
        exit 1
    fi
    
    if [[ ! -b "$BOOT_PART" ]]; then
        error "Boot partition $BOOT_PART not found"
        exit 1
    fi
    
    if [[ ! -b "$ROOT_PART" ]]; then
        error "Root partition $ROOT_PART not found"
        exit 1
    fi
    
    if [[ ! -b "$SWAP_PART" ]]; then
        error "Swap partition $SWAP_PART not found"
        exit 1
    fi
    
    if [[ ! -b "$SHARED_PART" ]]; then
        error "Shared partition $SHARED_PART not found"
        exit 1
    fi
    
    log "All partitions verified"
}

# Format partitions
format_partitions() {
    log "Formatting partitions..."
    
    # Format EFI partition
    if ! blkid "$EFI_PART" | grep -q "vfat"; then
        log "Formatting EFI partition..."
        mkfs.fat -F32 "$EFI_PART"
    else
        warning "EFI partition already formatted"
    fi
    
    # Format boot partition
    log "Formatting boot partition..."
    mkfs.ext4 -F "$BOOT_PART"
    
    # Create encrypted containers
    log "Setting up encryption..."
    
    if ! cryptsetup isLuks "$ROOT_PART"; then
        log "Creating LUKS container for root..."
        cryptsetup luksFormat "$ROOT_PART"
    else
        warning "Root partition already encrypted"
    fi
    
    if ! cryptsetup isLuks "$SWAP_PART"; then
        log "Creating LUKS container for swap..."
        cryptsetup luksFormat "$SWAP_PART"
    else
        warning "Swap partition already encrypted"
    fi
    
    # Open encrypted containers
    log "Opening encrypted containers..."
    cryptsetup open "$ROOT_PART" root
    cryptsetup open "$SWAP_PART" swap
    
    # Format encrypted partitions
    log "Formatting encrypted partitions..."
    mkfs.ext4 -F /dev/mapper/root
    mkswap /dev/mapper/swap
}

# Mount partitions
mount_partitions() {
    log "Mounting partitions..."
    
    # Mount root partition
    mount /dev/mapper/root /mnt
    
    # Create and mount boot directory
    mkdir -p /mnt/boot
    mount "$BOOT_PART" /mnt/boot
    
    # Create and mount EFI directory
    mkdir -p /mnt/boot/efi
    mount "$EFI_PART" /mnt/boot/efi
}

# Install base system
install_base_system() {
    log "Installing base system..."
    
    # Core packages
    pacstrap /mnt base base-devel linux linux-firmware efibootmgr
    
    # Intel-specific packages for Dell XPS
    pacstrap /mnt intel-media-driver intel-ucode libva-intel-driver vulkan-intel
    
    # Audio system
    pacstrap /mnt pipewire pipewire-alsa pipewire-jack pipewire-pulse gst-plugin-pipewire wireplumber sof-firmware
    
    # Network tools
    pacstrap /mnt iwd wireguard-tools networkmanager
    
    # Development tools
    pacstrap /mnt git neovim rust-analyzer rustup go ghcup-hs-bin pyenv npm yarn uv
    
    # Desktop environment
    pacstrap /mnt gdm gnome-control-center gnome-tweaks gnome-browser-connector nautilus
    
    # System utilities
    pacstrap /mnt htop ncdu tree less man-db net-tools usbutils pv trash-cli zram-generator
    
    # Package management
    pacstrap /mnt yay-bin pkgfile
    
    # Shell and terminal
    pacstrap /mnt zsh oh-my-zsh-git fzf direnv
    
    # Fonts
    pacstrap /mnt noto-fonts-emoji ttf-fira-code ttf-fira-mono
    
    # File system support
    pacstrap /mnt ntfs-3g unrar zip
    
    # Web browsers
    pacstrap /mnt firefox chromium
    
    # Communication tools
    pacstrap /mnt discord slack-desktop zoom
    
    # Office suite
    pacstrap /mnt libreoffice-fresh thunderbird
    
    # Media tools
    pacstrap /mnt vlc gimp inkscape obs-studio
    
    # PDF viewer
    pacstrap /mnt zathura zathura-pdf-poppler
    
    # Virtualization (optional)
    pacstrap /mnt virtualbox virtualbox-guest-iso
    
    # Additional useful packages
    pacstrap /mnt grub sudo vim nano wget curl
    
    log "Base system installation completed"
}

# Generate fstab
generate_fstab() {
    log "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
}

# Configure system
configure_system() {
    log "Configuring system..."
    
    # Set timezone
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
    arch-chroot /mnt hwclock --systohc
    
    # Configure locale
    echo "$LOCALE UTF-8" >> /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=$LOCALE" > /mnt/etc/locale.conf
    
    # Set hostname
    echo "$HOSTNAME" > /mnt/etc/hostname
    
    # Configure hosts file
    cat >> /mnt/etc/hosts << EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	$HOSTNAME.localdomain	$HOSTNAME
EOF
    
    # Create user account
    arch-chroot /mnt useradd -m -G wheel -s /bin/zsh "$USERNAME"
    
    # Configure sudo
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers
    
    log "System configuration completed"
}

# Configure encryption
configure_encryption() {
    log "Configuring encryption..."
    
    # Create keyfile
    mkdir -p /mnt/etc/keys
    dd bs=512 count=4 if=/dev/urandom of=/mnt/etc/keys/root.key
    chmod 600 /mnt/etc/keys/root.key
    
    # Add keyfile to LUKS
    arch-chroot /mnt cryptsetup luksAddKey "$ROOT_PART" /etc/keys/root.key
    arch-chroot /mnt cryptsetup luksAddKey "$SWAP_PART" /etc/keys/root.key
    
    # Configure mkinitcpio with hibernation support
    sed -i 's/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block filesystems fsck)/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 resume filesystems fsck)/' /mnt/etc/mkinitcpio.conf
    
    # Regenerate initramfs
    arch-chroot /mnt mkinitcpio -P
    
    log "Encryption configuration completed"
}

# Configure bootloader
configure_bootloader() {
    log "Configuring bootloader..."
    
    # Get UUID of root partition
    ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
    
    # Get swap partition UUID for hibernation
    SWAP_UUID=$(blkid -s UUID -o value "$SWAP_PART")
    
    # Configure GRUB with hibernation support
    cat >> /mnt/etc/default/grub << EOF
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"
GRUB_CMDLINE_LINUX="cryptdevice=UUID=$ROOT_UUID:root resume=UUID=$SWAP_UUID"
EOF
    
    # Install GRUB
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    
    log "Bootloader configuration completed"
}

# Configure services
configure_services() {
    log "Configuring services..."
    
    # Enable essential services
    arch-chroot /mnt systemctl enable gdm
    arch-chroot /mnt systemctl enable NetworkManager
    arch-chroot /mnt systemctl enable bluetooth
    arch-chroot /mnt systemctl enable fstrim.timer
    
    log "Services configuration completed"
}

# Configure shared storage
configure_shared_storage() {
    log "Configuring shared storage..."
    
    # Create mount point
    mkdir -p /mnt/mnt/shared
    
    # Add to fstab for automatic mounting
    echo "$SHARED_PART /mnt/shared ntfs-3g defaults,uid=1000,gid=1000,umask=0022,noatime 0 0" >> /mnt/etc/fstab
    
    log "Shared storage configuration completed"
}

# Set passwords
set_passwords() {
    log "Setting passwords..."
    
    info "Setting root password..."
    arch-chroot /mnt passwd root
    
    info "Setting user password for $USERNAME..."
    arch-chroot /mnt passwd "$USERNAME"
}

# Cleanup and reboot
cleanup_and_reboot() {
    log "Cleaning up..."
    
    # Close encrypted containers
    cryptsetup close root
    cryptsetup close swap
    
    # Unmount partitions
    umount -R /mnt
    
    log "Installation completed successfully!"
    info "You can now reboot into your new Arch Linux installation"
    info "Remember to remove the installation media before rebooting"
    
    read -p "Reboot now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        reboot
    fi
}

# Main installation function
main() {
    log "Starting Arch Linux dual boot installation..."
    
    check_root
    get_user_input
    verify_partitions
    
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Installation cancelled"
        exit 0
    fi
    
    format_partitions
    mount_partitions
    install_base_system
    generate_fstab
    configure_system
    configure_encryption
    configure_bootloader
    configure_services
    configure_shared_storage
    set_passwords
    cleanup_and_reboot
}

# Run main function
main "$@"
