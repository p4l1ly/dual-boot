#!/bin/bash

# Arch Linux Dual Boot Installation Script for Dell XPS 13" 9350
# This script automates the installation process after manual partitioning

set -e

# Configuration variables - Updated for existing Windows layout
DISK="/dev/nvme0n1"
EFI_PART="/dev/nvme0n1p1"      # EFI System Partition (260MB, existing)
MS_RESERVED_PART="/dev/nvme0n1p2" # Microsoft Reserved (16MB, existing)
WINDOWS_PART="/dev/nvme0n1p3"   # Windows Data Partition (shrunk, existing)
BOOT_PART="/dev/nvme0n1p5"      # Linux Boot Partition
ROOT_PART="/dev/nvme0n1p6"      # Linux Root Partition (LUKS encrypted)
SHARED_PART="/dev/nvme0n1p7"    # Shared Storage Partition (LUKS encrypted)
SWAP_PART="/dev/nvme0n1p8"      # Linux Swap Partition (LUKS encrypted)
RECOVERY_PART="/dev/nvme0n1p4"  # Windows Recovery (990MB, physically moved to end)
HOSTNAME="palypc"
USERNAME=""
TIMEZONE="Europe/Prague"
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

# Open encrypted containers (formatting done by partition-setup.sh)
open_encrypted_containers() {
    log "Opening encrypted containers..."
    
    # Open encrypted containers
    cryptsetup open "$ROOT_PART" root
    cryptsetup open "$SWAP_PART" swap
    cryptsetup open "$SHARED_PART" shared
    
    # Activate swap
    swapon /dev/mapper/swap
}

# Mount partitions
mount_partitions() {
    log "Mounting partitions..."
    
    # Create installation mount point
    mkdir -p /install
    
    # Mount root partition
    mount /dev/mapper/root /install
    
    # Mount EFI partition at /boot (systemd-boot requirement)
    mkdir -p /install/boot
    mount "$EFI_PART" /install/boot
    
    # Mount Linux boot partition at /boot/linux
    mkdir -p /install/boot/linux
    mount "$BOOT_PART" /install/boot/linux
    
    # Create shared storage mount point (will be configured later)
    mkdir -p /install/mnt/shared
}

# Install base system from packages.txt
install_base_system() {
    log "Installing base system from packages.txt..."
    
    # Check if packages.txt exists
    if [[ ! -f "packages.txt" ]]; then
        error "packages.txt not found in current directory"
        exit 1
    fi
    
    # Extract package names from packages.txt (ignore comments, versions, and commented lines)
    local packages=$(grep -v '^#' packages.txt | grep -v '^$' | sed 's/#.*//' | awk '{print $1}' | grep -v '^$' | tr '\n' ' ')
    
    if [[ -z "$packages" ]]; then
        error "No packages found in packages.txt"
        exit 1
    fi
    
    log "Found $(echo $packages | wc -w) packages to install"
    info "Installing packages from packages.txt..."
    
    # Install all packages at once
    pacstrap /install $packages
    
    log "Base system installation completed"
}

# Generate fstab
generate_fstab() {
    log "Generating fstab..."
    genfstab -U /install >> /install/etc/fstab
}

# Configure system
configure_system() {
    log "Configuring system..."
    
    # Set timezone
    arch-chroot /install ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
    arch-chroot /install hwclock --systohc
    
    # Configure locale
    echo "$LOCALE UTF-8" >> /install/etc/locale.gen
    arch-chroot /install locale-gen
    echo "LANG=$LOCALE" > /install/etc/locale.conf
    
    # Set hostname
    echo "$HOSTNAME" > /install/etc/hostname
    
    # Configure hosts file
    cat >> /install/etc/hosts << EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	$HOSTNAME.localdomain	$HOSTNAME
EOF
    
    # Create user account
    arch-chroot /install useradd -m -G wheel -s /bin/zsh "$USERNAME"
    
    # Configure sudo
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /install/etc/sudoers
    
    log "System configuration completed"
}

# Configure encryption
configure_encryption() {
    log "Configuring encryption..."
    
    # Create keyfile
    mkdir -p /install/etc/keys
    dd bs=512 count=4 if=/dev/urandom of=/install/etc/keys/root.key
    chmod 600 /install/etc/keys/root.key
    
    # Add keyfile to LUKS partitions
    arch-chroot /install cryptsetup luksAddKey "$ROOT_PART" /etc/keys/root.key
    arch-chroot /install cryptsetup luksAddKey "$SWAP_PART" /etc/keys/root.key
    arch-chroot /install cryptsetup luksAddKey "$SHARED_PART" /etc/keys/root.key
    
    # Configure mkinitcpio with hibernation support
    sed -i 's/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block filesystems fsck)/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 resume filesystems fsck)/' /install/etc/mkinitcpio.conf
    
    # Regenerate initramfs
    arch-chroot /install mkinitcpio -P
    
    log "Encryption configuration completed"
}

# Configure systemd-boot
configure_bootloader() {
    log "Configuring systemd-boot..."
    
    # Get UUID of root partition
    ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
    
    # Get swap partition UUID for hibernation
    SWAP_UUID=$(blkid -s UUID -o value "$SWAP_PART")
    
    # Install systemd-boot
    arch-chroot /install bootctl install
    
    # Configure systemd-boot loader
    cat > /install/boot/loader/loader.conf << EOF
default  arch.conf
timeout  4
console-mode max
editor   no
EOF
    
    # Create Arch Linux boot entry
    cat > /install/boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /linux/vmlinuz-linux
initrd  /intel-ucode.img
initrd  /linux/initramfs-linux.img
options cryptdevice=UUID=$ROOT_UUID:root root=/dev/mapper/root resume=UUID=$SWAP_UUID rw
EOF
    
    # Create Arch Linux fallback boot entry
    cat > /install/boot/loader/entries/arch-fallback.conf << EOF
title   Arch Linux (fallback initramfs)
linux   /linux/vmlinuz-linux
initrd  /intel-ucode.img
initrd  /linux/initramfs-linux-fallback.img
options cryptdevice=UUID=$ROOT_UUID:root root=/dev/mapper/root resume=UUID=$SWAP_UUID rw
EOF
    
    log "systemd-boot configuration completed"
}

# Configure services
configure_services() {
    log "Configuring services..."
    
    # Enable essential services
    arch-chroot /install systemctl enable gdm
    arch-chroot /install systemctl enable NetworkManager
    arch-chroot /install systemctl enable bluetooth
    arch-chroot /install systemctl enable fstrim.timer
    
    log "Services configuration completed"
}

# Configure encrypted shared storage
configure_shared_storage() {
    log "Configuring encrypted shared storage..."
    
    # Create mount point
    mkdir -p /install/mnt/shared
    
    # Create crypttab entry for shared partition
    SHARED_UUID=$(blkid -s UUID -o value "$SHARED_PART")
    echo "shared UUID=$SHARED_UUID /etc/keys/root.key luks" >> /install/etc/crypttab
    
    # Add to fstab for automatic mounting
    echo "/dev/mapper/shared /mnt/shared ext4 defaults,noatime 0 2" >> /install/etc/fstab
    
    log "Encrypted shared storage configuration completed"
    info "Shared partition will be automatically decrypted and mounted on boot"
    info "Accessible from Windows via WSL after proper setup"
}

# Set passwords
set_passwords() {
    log "Setting passwords..."
    
    info "Setting root password..."
    arch-chroot /install passwd root
    
    info "Setting user password for $USERNAME..."
    arch-chroot /install passwd "$USERNAME"
}

# Cleanup and reboot
cleanup_and_reboot() {
    log "Cleaning up..."
    
    # Deactivate swap
    swapoff /dev/mapper/swap
    
    # Close encrypted containers
    cryptsetup close root
    cryptsetup close swap
    cryptsetup close shared
    
    # Unmount partitions
    umount -R /install
    
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
    
    open_encrypted_containers
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
