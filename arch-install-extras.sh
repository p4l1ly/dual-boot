#!/bin/bash

# Arch Linux Extras Installation Script
# Run this AFTER first boot into the base system (not from live USB)

set -e

USERNAME="paly"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check if we're in the installed system (not live USB)
check_environment() {
    if [[ -d "/install" ]] || grep -q "archiso" /proc/cmdline 2>/dev/null; then
        error "This script should be run from the installed system, not live USB!"
        exit 1
    fi
    
    log "Environment check passed - running in installed system"
}

# Install packages from packages.txt
install_official_packages() {
    log "Installing official packages from packages.txt..."
    
    local script_dir="$(dirname "$(readlink -f "$0")")"
    local packages_file="$script_dir/packages.txt"
    
    if [[ ! -f "$packages_file" ]]; then
        error "packages.txt not found at $packages_file"
        error "Please ensure the script is in the same directory as packages.txt"
        exit 1
    fi
    
    # Extract package names
    local packages=$(grep -v '^#' "$packages_file" | grep -v '^$' | sed 's/#.*//' | awk '{print $1}' | grep -v '^$' | tr '\n' ' ')
    
    if [[ -z "$packages" ]]; then
        error "No packages found in packages.txt"
        exit 1
    fi
    
    info "Found $(echo $packages | wc -w) official packages"
    
    # Update system first
    log "Updating system..."
    pacman -Syu --noconfirm
    
    # Install packages
    log "Installing packages..."
    pacman -S --needed --noconfirm $packages
    
    log "Official packages installation completed"
}

# Install AUR packages
install_aur_packages() {
    log "Installing AUR packages..."
    
    local script_dir="$(dirname "$(readlink -f "$0")")"
    local aur_file="$script_dir/packages-aur.txt"
    
    if [[ ! -f "$aur_file" ]]; then
        warning "packages-aur.txt not found, skipping AUR packages"
        return
    fi
    
    local aur_packages=$(grep -v '^#' "$aur_file" | grep -v '^$' | sed 's/#.*//' | awk '{print $1}' | grep -v '^$' | tr '\n' ' ')
    
    if [[ -z "$aur_packages" ]]; then
        info "No AUR packages to install"
        return
    fi
    
    info "Found $(echo $aur_packages | wc -w) AUR packages"
    
    # Test AUR connectivity
    if ! sudo -u "$USERNAME" curl -s --max-time 10 https://aur.archlinux.org > /dev/null 2>&1; then
        warning "Cannot reach aur.archlinux.org"
        read -p "Skip AUR packages and continue? (Y/n): " -r SKIP_AUR
        if [[ "$SKIP_AUR" =~ ^[Nn]$ ]]; then
            error "Cannot proceed without AUR access"
            exit 1
        fi
        return
    fi
    
    # Check if yay is installed
    if ! command -v yay &> /dev/null; then
        info "Installing yay-bin..."
        
        local build_dir="/home/$USERNAME/yay-build"
        rm -rf "$build_dir"
        mkdir -p "$build_dir"
        chown -R "$USERNAME:$USERNAME" "$build_dir"
        
        cd "$build_dir"
        sudo -u "$USERNAME" git clone https://aur.archlinux.org/yay-bin.git
        cd yay-bin
        sudo -u "$USERNAME" makepkg -si --noconfirm
        
        cd /
        rm -rf "$build_dir"
        
        log "yay installed successfully"
    fi
    
    # Remove yay-bin from list if present
    aur_packages=$(echo "$aur_packages" | sed 's/yay-bin//' | sed 's/  / /g' | sed 's/^ *//' | sed 's/ *$//')
    
    # Install remaining AUR packages
    if [[ -n "$aur_packages" ]]; then
        info "Installing AUR packages: $aur_packages"
        sudo -u "$USERNAME" yay -S --noconfirm $aur_packages || {
            warning "Some AUR packages failed to install"
        }
    fi
    
    log "AUR packages installation completed"
}

# Configure desktop services
configure_services() {
    log "Configuring desktop services..."
    
    local services=(
        "gdm:Display Manager"
        "iwd:Wireless Daemon"
        "bluetooth:Bluetooth"
    )
    
    for service_info in "${services[@]}"; do
        local service="${service_info%%:*}"
        local description="${service_info##*:}"
        
        log "Enabling $description ($service)..."
        if systemctl enable "$service" 2>&1; then
            info "✓ $description enabled"
        else
            warning "✗ Failed to enable $service"
        fi
    done
    
    log "Services configuration completed"
}

# Configure keyboard (swap Escape and CapsLock)
configure_keyboard() {
    log "Configuring keyboard: swapping Escape and CapsLock..."
    
    # For X11 sessions (system-wide)
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/90-custom-kbd.conf << 'EOF'
Section "InputClass"
    Identifier "keyboard defaults"
    MatchIsKeyboard "on"
    Option "XKbOptions" "caps:swapescape"
EndSection
EOF
    
    # For Wayland/GNOME - user config
    local user_home="/home/$USERNAME"
    
    mkdir -p "$user_home/.local/bin"
    cat > "$user_home/.local/bin/swap-caps-esc.sh" << 'EOF'
#!/bin/bash
# Swap CapsLock and Escape for GNOME
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:swapescape']"
EOF
    chmod +x "$user_home/.local/bin/swap-caps-esc.sh"
    
    # Set it in dconf
    mkdir -p "$user_home/.config/dconf/user.d"
    cat > "$user_home/.config/dconf/user.d/00-keyboard" << 'EOF'
[org/gnome/desktop/input-sources]
xkb-options=['caps:swapescape']
EOF
    
    chown -R "$USERNAME:$USERNAME" "$user_home/.local"
    chown -R "$USERNAME:$USERNAME" "$user_home/.config"
    
    log "Keyboard configuration completed"
}

# Main function
main() {
    log "Starting Arch Linux extras installation..."
    
    check_root
    check_environment
    
    info "This will install:"
    info "  - Desktop environment (GNOME)"
    info "  - Graphics drivers"
    info "  - Development tools"
    info "  - Applications"
    info "  - AUR packages"
    info "  - User customizations"
    echo
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Installation cancelled"
        exit 0
    fi
    
    install_official_packages
    install_aur_packages
    configure_services
    configure_keyboard
    
    log "Extras installation completed successfully!"
    info ""
    info "Desktop environment installed!"
    info "Reboot to start GNOME: sudo reboot"
}

# Run main function
main "$@"

