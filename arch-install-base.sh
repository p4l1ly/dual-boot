#!/bin/bash

# Arch Linux Base Installation Script - Minimal Bootable System
# Run this from live USB to get a bootable system

set -e

# Configuration variables
DISK="/dev/nvme0n1"
EFI_PART="/dev/nvme0n1p1"      # EFI System Partition (Windows, not used)
BOOT_PART="/dev/nvme0n1p5"      # Linux Boot Partition (ESP)
ROOT_PART="/dev/nvme0n1p6"      # Linux Root Partition (LUKS encrypted)
SHARED_PART="/dev/nvme0n1p7"    # Shared Storage Partition (LUKS encrypted)
SWAP_PART="/dev/nvme0n1p8"      # Linux Swap Partition (LUKS encrypted)
HOSTNAME="palypc"
USERNAME="paly"
TIMEZONE="Europe/Prague"
LOCALE="en_US.UTF-8"

# Password file for automated LUKS operations
PASSWORD_FILE="luks-password.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Get user confirmation
get_user_input() {
    log "Using configuration:"
    info "  Username: $USERNAME"
    info "  Hostname: $HOSTNAME"
    info "  Timezone: $TIMEZONE"
    info "  Locale: $LOCALE"
}

# Verify partitions exist
verify_partitions() {
    log "Verifying partitions..."
    
    for part in "$BOOT_PART" "$ROOT_PART" "$SWAP_PART" "$SHARED_PART"; do
        if [[ ! -b "$part" ]]; then
            error "Partition $part not found"
            exit 1
        fi
    done
    
    log "All partitions verified"
}

# Cleanup any existing installation state
cleanup_existing_state() {
    log "Cleaning up any existing installation state..."
    
    swapoff -a 2>/dev/null || true
    
    if mountpoint -q /install 2>/dev/null; then
        warning "Found existing mounts under /install, unmounting..."
        umount -R /install 2>/dev/null || true
    fi
    
    for container in root swap shared; do
        if cryptsetup status "$container" >/dev/null 2>&1; then
            warning "Closing existing LUKS container: $container"
            cryptsetup close "$container"
        fi
    done
    
    [[ -d "/install" ]] && rmdir /install 2>/dev/null || true
    
    log "Cleanup completed"
}

# Open encrypted containers
open_encrypted_containers() {
    log "Opening encrypted containers..."
    
    if [[ ! -f "$PASSWORD_FILE" ]]; then
        error "Password file '$PASSWORD_FILE' not found!"
        exit 1
    fi
    
    cryptsetup open "$ROOT_PART" root --key-file="$PASSWORD_FILE"
    cryptsetup open "$SWAP_PART" swap --key-file="$PASSWORD_FILE"
    cryptsetup open "$SHARED_PART" shared --key-file="$PASSWORD_FILE"
    
    swapon /dev/mapper/swap
}

# Mount partitions
mount_partitions() {
    log "Mounting partitions..."
    
    mkdir -p /install
    mount /dev/mapper/root /install
    
    mkdir -p /install/boot
    mount "$BOOT_PART" /install/boot
    
    mkdir -p /install/mnt/shared
}

# Install minimal base system
install_base_system() {
    log "Installing minimal base system..."
    
    # Core packages for bootable system
    local base_packages="base linux linux-firmware intel-ucode zsh sudo cryptsetup lvm2"
    
    # Essential utilities
    local utils="base-devel git curl wget vim networkmanager openssh man-db man-pages"
    
    info "Installing base system packages..."
    pacstrap /install $base_packages $utils
    
    log "Base system installation completed"
}

# Generate fstab
generate_fstab() {
    log "Generating fstab..."
    genfstab -U /install >> /install/etc/fstab
}

# Configure system basics
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
    
    # Create keyfile for automatic decryption of swap and shared
    # NOTE: Root partition will require password at boot
    mkdir -p /install/etc/keys
    dd bs=512 count=4 if=/dev/urandom of=/install/etc/keys/root.key
    chmod 600 /install/etc/keys/root.key
    
    # Add keyfile to SWAP and SHARED only (NOT root - we want password prompt for root)
    cryptsetup luksAddKey "$SWAP_PART" /install/etc/keys/root.key --key-file="$PASSWORD_FILE"
    cryptsetup luksAddKey "$SHARED_PART" /install/etc/keys/root.key --key-file="$PASSWORD_FILE"
    
    # Configure mkinitcpio with hibernation support
    # Order matters: keyboard/keymap before encrypt so you can type password
    # encrypt before filesystems so root can be decrypted
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt lvm2 resume filesystems fsck)/' /install/etc/mkinitcpio.conf
    
    # Regenerate initramfs
    arch-chroot /install mkinitcpio -P
    
    log "Encryption configuration completed"
    info "Root partition will require password at boot"
    info "Swap and shared will be auto-decrypted using keyfile"
}

# Configure systemd-boot
configure_bootloader() {
    log "Configuring systemd-boot..."
    
    # Get partition UUID (not LUKS UUID) for cryptdevice parameter
    ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_PART")
    
    # Get LUKS UUID for the opened swap (for resume parameter)
    SWAP_UUID=$(blkid -s UUID -o value /dev/mapper/swap)
    
    log "Installing systemd-boot to /boot (p5)..."
    
    if ! mountpoint -q /install/boot; then
        error "/install/boot is not a mount point!"
        exit 1
    fi
    
    arch-chroot /install bootctl install
    
    # Ensure UEFI knows about systemd-boot (on partition 5)
    log "Registering systemd-boot with UEFI..."
    if ! efibootmgr | grep -q "Linux Boot Manager"; then
        efibootmgr --create \
            --disk "$DISK" \
            --part 5 \
            --label "Linux Boot Manager" \
            --loader '\EFI\systemd\systemd-bootx64.efi' \
            --unicode || warning "Could not create UEFI boot entry"
    fi
    
    # Create loader configuration
    cat > /install/boot/loader/loader.conf << EOF
default  arch.conf
timeout  4
console-mode max
editor   no
EOF
    
    # Create Arch Linux boot entry
    cat > /install/boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options cryptdevice=PARTUUID=$ROOT_PARTUUID:root root=/dev/mapper/root resume=UUID=$SWAP_UUID rw
EOF
    
    # Create fallback boot entry
    cat > /install/boot/loader/entries/arch-fallback.conf << EOF
title   Arch Linux (fallback initramfs)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options cryptdevice=PARTUUID=$ROOT_PARTUUID:root root=/dev/mapper/root resume=UUID=$SWAP_UUID rw
EOF
    
    log "systemd-boot configuration completed"
    info "Boot partition (p5) is the ESP - contains both systemd-boot and kernels"
}

# Configure essential services
configure_services() {
    log "Configuring essential services..."
    
    arch-chroot /install systemctl enable NetworkManager
    arch-chroot /install systemctl enable sshd
    arch-chroot /install systemctl enable fstrim.timer
    
    log "Services configuration completed"
}

# Configure encrypted swap and shared storage
configure_shared_storage() {
    log "Configuring encrypted swap and shared storage..."
    
    # Get UUIDs of encrypted partitions
    SWAP_UUID=$(blkid -s UUID -o value "$SWAP_PART")
    SHARED_UUID=$(blkid -s UUID -o value "$SHARED_PART")
    
    # Create crypttab for automatic decryption using keyfile
    cat > /install/etc/crypttab << EOF
# <name>  <device>                    <password>          <options>
swap      UUID=$SWAP_UUID             /etc/keys/root.key  luks
shared    UUID=$SHARED_UUID           /etc/keys/root.key  luks
EOF
    
    # Add to fstab
    echo "/dev/mapper/swap    none         swap    defaults        0 0" >> /install/etc/fstab
    echo "/dev/mapper/shared  /mnt/shared  ext4    defaults,noatime 0 2" >> /install/etc/fstab
    
    log "Encrypted swap and shared storage configuration completed"
    info "Both will be auto-decrypted on boot using keyfile"
}

# Set passwords
set_passwords() {
    log "Setting passwords..."
    
    info "Setting root password..."
    arch-chroot /install passwd root
    
    info "Setting user password for $USERNAME..."
    arch-chroot /install passwd "$USERNAME"
}

# Cleanup and finish
cleanup_and_finish() {
    log "Cleaning up..."
    
    swapoff /dev/mapper/swap 2>/dev/null || true
    umount -R /install 2>/dev/null || umount -l /install 2>/dev/null || true
    
    cryptsetup close shared 2>/dev/null || true
    cryptsetup close swap 2>/dev/null || true
    cryptsetup close root 2>/dev/null || true
    
    log "Base installation completed successfully!"
    info ""
    info "Next steps:"
    info "  1. Remove installation media"
    info "  2. Reboot into the new system"
    info "  3. Log in as $USERNAME"
    info "  4. Run: sudo /path/to/arch-install-extras.sh"
    info ""
    info "The extras script will install:"
    info "  - GNOME desktop environment"
    info "  - Graphics drivers"
    info "  - Development tools"
    info "  - AUR packages"
    info "  - User customizations"
    
    read -p "Reboot now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        reboot
    fi
}

# Main installation function
main() {
    log "Starting Arch Linux base installation..."
    
    check_root
    get_user_input
    verify_partitions
    
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Installation cancelled"
        exit 0
    fi
    
    cleanup_existing_state
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
    cleanup_and_finish
}

# Run main function
main "$@"

