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

# Get user input (now automated - username and timezone are hardcoded)
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

# Cleanup any existing installation state
cleanup_existing_state() {
    log "Cleaning up any existing installation state..."
    
    # Deactivate any active swap
    swapoff -a 2>/dev/null || true
    
    # Unmount any mounted filesystems under /install
    if mountpoint -q /install 2>/dev/null; then
        warning "Found existing mounts under /install, unmounting..."
        umount -R /install 2>/dev/null || true
    fi
    
    # Close any open LUKS containers
    for container in root swap shared; do
        if cryptsetup status "$container" >/dev/null 2>&1; then
            warning "Closing existing LUKS container: $container"
            cryptsetup close "$container"
        fi
    done
    
    # Remove installation directory if it exists
    if [[ -d "/install" ]]; then
        rmdir /install 2>/dev/null || true
    fi
    
    log "Cleanup completed"
}

# Open encrypted containers (formatting done by partition-setup.sh)
open_encrypted_containers() {
    log "Opening encrypted containers..."
    
    # Check for password file
    if [[ ! -f "$PASSWORD_FILE" ]]; then
        error "Password file '$PASSWORD_FILE' not found!"
        error "It should have been created during partition-setup.sh"
        exit 1
    fi
    
    # Open encrypted containers using password file
    cryptsetup open "$ROOT_PART" root --key-file="$PASSWORD_FILE"
    cryptsetup open "$SWAP_PART" swap --key-file="$PASSWORD_FILE"
    cryptsetup open "$SHARED_PART" shared --key-file="$PASSWORD_FILE"
    
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
    
    # Mount Linux ESP (p5) at /boot - contains bootloader AND kernels
    mkdir -p /install/boot
    mount "$BOOT_PART" /install/boot
    
    # Create shared storage mount point (will be configured later)
    mkdir -p /install/mnt/shared
}

# Install base system from packages.txt and packages-aur.txt
install_base_system() {
    log "Installing base system from packages.txt and packages-aur.txt..."
    
    # Check if packages.txt exists
    if [[ ! -f "packages.txt" ]]; then
        error "packages.txt not found in current directory"
        exit 1
    fi
    
    # Extract official package names from packages.txt
    local official_packages=$(grep -v '^#' packages.txt | grep -v '^$' | sed 's/#.*//' | awk '{print $1}' | grep -v '^$' | tr '\n' ' ')
    
    if [[ -z "$official_packages" ]]; then
        error "No packages found in packages.txt"
        exit 1
    fi
    
    # Extract AUR package names from packages-aur.txt if it exists
    local aur_packages=""
    if [[ -f "packages-aur.txt" ]]; then
        aur_packages=$(grep -v '^#' packages-aur.txt | grep -v '^$' | sed 's/#.*//' | awk '{print $1}' | grep -v '^$' | tr '\n' ' ')
    fi
    
    log "Found $(echo $official_packages | wc -w) official packages and $(echo $aur_packages | wc -w) AUR packages"
    
    # Install official packages first
    info "Installing official packages via pacstrap..."
    pacstrap /install $official_packages
    
    # Store AUR packages for later installation (after user creation)
    if [[ -n "$(echo $aur_packages | tr -d ' ')" ]]; then
        mkdir -p /install/tmp
        echo "$aur_packages" > /install/tmp/aur_packages.txt
        info "AUR packages will be installed after user creation"
    fi
    
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
    
    # Add keyfile to LUKS partitions (using password file for authentication)
    cryptsetup luksAddKey "$ROOT_PART" /install/etc/keys/root.key --key-file="$PASSWORD_FILE"
    cryptsetup luksAddKey "$SWAP_PART" /install/etc/keys/root.key --key-file="$PASSWORD_FILE"
    cryptsetup luksAddKey "$SHARED_PART" /install/etc/keys/root.key --key-file="$PASSWORD_FILE"
    
    # Configure mkinitcpio with hibernation support
    # Order matters: keyboard/keymap before encrypt so you can type password
    # encrypt before filesystems so root can be decrypted
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt lvm2 resume filesystems fsck)/' /install/etc/mkinitcpio.conf
    
    # Regenerate initramfs
    arch-chroot /install mkinitcpio -P
    
    log "Encryption configuration completed"
}

# Configure systemd-boot
configure_bootloader() {
    log "Configuring systemd-boot..."
    
    # Get partition UUID (not LUKS UUID) for cryptdevice parameter
    ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_PART")
    
    # Get LUKS UUID for the opened swap (for resume parameter)
    SWAP_UUID=$(blkid -s UUID -o value /dev/mapper/swap)
    
    # Install systemd-boot to /boot (p5 is our ESP)
    log "Installing systemd-boot to /boot (p5)..."
    
    # Debug: Show mount points
    log "Current mount points:"
    mount | grep /install
    
    # Debug: Check if boot partition is properly formatted
    log "Checking boot partition (p5)..."
    blkid "$BOOT_PART"
    
    # Verify /boot is mounted
    if ! mountpoint -q /install/boot; then
        error "/install/boot is not a mount point!"
        exit 1
    fi
    
    # Install bootctl to /boot (simpler - single ESP)
    log "Running bootctl install..."
    arch-chroot /install bootctl install
    
    # Verify installation
    log "Verifying bootctl installation..."
    arch-chroot /install bootctl status || warning "bootctl status returned non-zero (might be expected)"
    
    # Ensure UEFI knows about systemd-boot (on partition 5)
    log "Registering systemd-boot with UEFI..."
    if ! efibootmgr | grep -q "Linux Boot Manager"; then
        efibootmgr --create \
            --disk "$DISK" \
            --part 5 \
            --label "Linux Boot Manager" \
            --loader '\EFI\systemd\systemd-bootx64.efi' \
            --unicode || warning "Could not create UEFI boot entry"
        
        log "Current UEFI boot order:"
        efibootmgr
    else
        info "Linux Boot Manager entry already exists in UEFI"
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
    
    # Create Arch Linux fallback boot entry
    cat > /install/boot/loader/entries/arch-fallback.conf << EOF
title   Arch Linux (fallback initramfs)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options cryptdevice=PARTUUID=$ROOT_PARTUUID:root root=/dev/mapper/root resume=UUID=$SWAP_UUID rw
EOF
    
    log "systemd-boot configuration completed"
    info "Boot partition (p5) is the ESP - contains both systemd-boot and kernels"
    info "Windows uses p1, Linux uses p5 - completely separate"
}

# Configure services
configure_services() {
    log "Configuring services..."
    
    # Enable essential services (with error handling)
    local services=(
        "gdm:Display Manager"
        "iwd:Wireless Daemon"
        "bluetooth:Bluetooth"
        "fstrim.timer:SSD Trim"
    )
    
    for service_info in "${services[@]}"; do
        local service="${service_info%%:*}"
        local description="${service_info##*:}"
        
        log "Enabling $description ($service)..."
        if arch-chroot /install systemctl enable "$service" 2>&1; then
            info "✓ $description enabled"
        else
            warning "✗ Failed to enable $service - may not be installed"
        fi
    done
    
    log "Services configuration completed"
}

# Install AUR packages
install_aur_packages() {
    log "Installing AUR packages..."
    
    # Check if there are AUR packages to install
    if [[ ! -f "/install/tmp/aur_packages.txt" ]]; then
        info "No AUR packages to install"
        return
    fi
    
    local aur_packages=$(cat /install/tmp/aur_packages.txt)
    if [[ -z "$aur_packages" ]]; then
        info "No AUR packages to install"
        return
    fi
    
    info "Installing yay-bin for AUR package management..."
    
    # Test AUR connectivity first
    if ! arch-chroot /install curl -s --max-time 10 https://aur.archlinux.org > /dev/null 2>&1; then
        warning "Cannot reach aur.archlinux.org"
        warning "This could be a temporary issue with AUR or network connectivity"
        
        echo -n "Skip AUR packages and continue? (Y/n): "
        read -r SKIP_AUR
        if [[ ! "$SKIP_AUR" =~ ^[Nn]$ ]]; then
            warning "Skipping AUR packages installation"
            info "You can install them manually after reboot with:"
            info "  yay -S $aur_packages"
            return
        else
            error "Cannot proceed without AUR access"
            exit 1
        fi
    fi
    
    # Install yay-bin manually with proper error handling
    if ! arch-chroot /install /bin/bash << EOFCHROOT
        set -e
        
        # Create build directory in user's home
        USER_HOME="/home/$USERNAME"
        BUILD_DIR="\$USER_HOME/yay-build"
        
        # Clean up any previous attempts
        rm -rf "\$BUILD_DIR"
        mkdir -p "\$BUILD_DIR"
        chown -R $USERNAME:$USERNAME "\$BUILD_DIR"
        
        # Clone and build as user
        cd "\$BUILD_DIR"
        if ! sudo -u $USERNAME git clone https://aur.archlinux.org/yay-bin.git; then
            echo "ERROR: Failed to clone yay-bin repository"
            exit 1
        fi
        
        if [ ! -d "\$BUILD_DIR/yay-bin" ]; then
            echo "ERROR: yay-bin directory not found after clone"
            exit 1
        fi
        
        cd "\$BUILD_DIR/yay-bin"
        sudo -u $USERNAME makepkg -si --noconfirm
        
        # Cleanup
        cd /
        rm -rf "\$BUILD_DIR"
EOFCHROOT
    then
        error "Failed to install yay-bin"
        warning "Skipping AUR packages installation"
        info "You can install yay and AUR packages manually after reboot"
        return
    fi
    
    # Remove yay-bin from the list if it exists
    aur_packages=$(echo "$aur_packages" | sed 's/yay-bin//' | sed 's/  / /g' | sed 's/^ *//' | sed 's/ *$//')
    
    # Install remaining AUR packages
    if [[ -n "$aur_packages" ]]; then
        info "Installing remaining AUR packages: $aur_packages"
        arch-chroot /install sudo -u "$USERNAME" yay -S --noconfirm $aur_packages || {
            warning "Some AUR packages failed to install"
        }
    fi
    
    # Cleanup
    rm -f /install/tmp/aur_packages.txt
    
    log "AUR packages installation completed"
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

# Configure keyboard (swap Escape and CapsLock)
configure_keyboard() {
    log "Configuring keyboard: swapping Escape and CapsLock..."
    
    # For X11 sessions (system-wide)
    mkdir -p /install/etc/X11/xorg.conf.d
    cat > /install/etc/X11/xorg.conf.d/90-custom-kbd.conf << 'EOF'
Section "InputClass"
    Identifier "keyboard defaults"
    MatchIsKeyboard "on"
    Option "XKbOptions" "caps:swapescape"
EndSection
EOF
    
    # For Wayland/GNOME - create helper script
    mkdir -p /install/etc/skel/.local/bin
    cat > /install/etc/skel/.local/bin/swap-caps-esc.sh << 'EOF'
#!/bin/bash
# Swap CapsLock and Escape for GNOME
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:swapescape']"
EOF
    chmod +x /install/etc/skel/.local/bin/swap-caps-esc.sh
    
    # Apply for the created user
    mkdir -p /install/home/$USERNAME/.local/bin
    cp /install/etc/skel/.local/bin/swap-caps-esc.sh /install/home/$USERNAME/.local/bin/
    
    # Set it in dconf for the user (will take effect on first login)
    mkdir -p /install/home/$USERNAME/.config/dconf/user.d
    cat > /install/home/$USERNAME/.config/dconf/user.d/00-keyboard << 'EOF'
[org/gnome/desktop/input-sources]
xkb-options=['caps:swapescape']
EOF
    
    # Fix ownership inside chroot (where the user exists)
    arch-chroot /install chown -R $USERNAME:$USERNAME /home/$USERNAME/.local
    arch-chroot /install chown -R $USERNAME:$USERNAME /home/$USERNAME/.config
    
    log "Keyboard configuration completed"
}

# Cleanup and reboot
cleanup_and_reboot() {
    log "Cleaning up..."
    
    # Deactivate swap first
    swapoff /dev/mapper/swap 2>/dev/null || true
    
    # Unmount partitions (must happen before closing LUKS containers)
    log "Unmounting partitions..."
    umount -R /install 2>/dev/null || umount -l /install 2>/dev/null || true
    
    # Now close encrypted containers
    log "Closing encrypted containers..."
    cryptsetup close shared 2>/dev/null || true
    cryptsetup close swap 2>/dev/null || true
    cryptsetup close root 2>/dev/null || true
    
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
    
    cleanup_existing_state
    open_encrypted_containers
    mount_partitions
    install_base_system
    generate_fstab
    configure_system
    configure_encryption
    configure_bootloader
    configure_services
    install_aur_packages
    configure_shared_storage
    set_passwords
    configure_keyboard
    cleanup_and_reboot
}

# Run main function
main "$@"
