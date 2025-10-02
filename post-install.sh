#!/bin/bash

# Post-Installation Setup Script for Arch Linux on Dell XPS 13" 9350
# This script configures the system after initial installation

set -e

# Configuration
USERNAME=""
HOSTNAME="dell-xps"
PACKAGES_FILE="/home/paly/hobby/dual-boot/packages.txt"

# Colors
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
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root"
        exit 1
    fi
}

# Get user input
get_user_input() {
    read -p "Enter your username: " USERNAME
    if [[ -z "$USERNAME" ]]; then
        error "Username cannot be empty"
        exit 1
    fi
    
    read -p "Enter hostname (default: dell-xps): " HOSTNAME_INPUT
    if [[ -n "$HOSTNAME_INPUT" ]]; then
        HOSTNAME="$HOSTNAME_INPUT"
    fi
}

# Update system
update_system() {
    log "Updating system..."
    sudo pacman -Syu --noconfirm
    log "System updated"
}

# Install additional packages from packages.txt
install_additional_packages() {
    log "Installing additional packages..."
    
    if [[ -f "$PACKAGES_FILE" ]]; then
        # Extract package names from packages.txt (skip comments and empty lines)
        PACKAGES=$(grep -v '^#' "$PACKAGES_FILE" | grep -v '^$' | awk '{print $1}' | tr '\n' ' ')
        
        if [[ -n "$PACKAGES" ]]; then
            log "Installing packages: $PACKAGES"
            yay -S --noconfirm $PACKAGES
        else
            warning "No packages found in $PACKAGES_FILE"
        fi
    else
        warning "Packages file $PACKAGES_FILE not found"
    fi
}

# Configure shell
configure_shell() {
    log "Configuring shell..."
    
    # Install Oh My Zsh
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    # Set Zsh as default shell
    sudo chsh -s /bin/zsh "$USERNAME"
    
    # Install additional Zsh plugins
    log "Installing Zsh plugins..."
    
    # Install zsh-autosuggestions
    if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    fi
    
    # Install zsh-syntax-highlighting
    if [[ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    fi
    
    # Configure .zshrc
    log "Configuring .zshrc..."
    cat >> "$HOME/.zshrc" << EOF

# Custom configuration
export EDITOR=nvim
export VISUAL=nvim

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Enable plugins
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

# Enable Powerlevel10k theme
ZSH_THEME="powerlevel10k/powerlevel10k"
EOF
    
    log "Shell configuration completed"
}

# Configure development environment
configure_development() {
    log "Configuring development environment..."
    
    # Configure Git
    read -p "Enter your Git name: " GIT_NAME
    read -p "Enter your Git email: " GIT_EMAIL
    
    if [[ -n "$GIT_NAME" && -n "$GIT_EMAIL" ]]; then
        git config --global user.name "$GIT_NAME"
        git config --global user.email "$GIT_EMAIL"
        log "Git configured"
    fi
    
    # Configure Neovim
    log "Configuring Neovim..."
    mkdir -p "$HOME/.config/nvim"
    
    # Create basic Neovim configuration
    cat > "$HOME/.config/nvim/init.vim" << EOF
" Basic Neovim configuration
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set smartindent
set autoindent
set hlsearch
set incsearch
set ignorecase
set smartcase
set showcmd
set showmode
set ruler
set laststatus=2
set wildmenu
set wildmode=list:longest
set backspace=indent,eol,start
set encoding=utf-8
set fileencoding=utf-8
set termguicolors
syntax enable
filetype plugin indent on

" Key mappings
let mapleader = " "
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>x :x<CR>
nnoremap <leader>h :nohlsearch<CR>
EOF
    
    log "Development environment configured"
}

# Configure GNOME desktop
configure_gnome() {
    log "Configuring GNOME desktop..."
    
    # Install GNOME extensions
    log "Installing GNOME extensions..."
    yay -S --noconfirm gnome-shell-extension-appindicator
    yay -S --noconfirm gnome-shell-extension-dash-to-dock
    yay -S --noconfirm gnome-shell-extension-user-theme
    
    # Configure GNOME settings
    log "Configuring GNOME settings..."
    
    # Enable extensions
    gsettings set org.gnome.shell enabled-extensions "['appindicatorsupport@rgcjonas.gmail.com', 'dash-to-dock@micxgx.gmail.com', 'user-theme@gnome-shell-extensions.gcamp.net']"
    
    # Configure dash-to-dock
    gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
    gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false
    gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
    gsettings set org.gnome.shell.extensions.dash-to-dock intellihide true
    
    # Configure appearance
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
    gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'
    
    # Configure window management
    gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
    
    log "GNOME desktop configured"
}

# Configure system services
configure_services() {
    log "Configuring system services..."
    
    # Enable additional services
    sudo systemctl enable bluetooth
    sudo systemctl enable fstrim.timer
    sudo systemctl enable pkgfile-update.timer
    
    # Configure power management
    log "Installing power management tools..."
    yay -S --noconfirm tlp tlp-rdw
    
    # Enable TLP
    sudo systemctl enable tlp
    sudo systemctl enable tlp-sleep
    
    # Configure TLP
    sudo sed -i 's/#CPU_SCALING_GOVERNOR_ON_AC=powersave/CPU_SCALING_GOVERNOR_ON_AC=performance/' /etc/tlp.conf
    sudo sed -i 's/#CPU_SCALING_GOVERNOR_ON_BATTERY=powersave/CPU_SCALING_GOVERNOR_ON_BATTERY=powersave/' /etc/tlp.conf
    
    log "System services configured"
}

# Configure hibernation
configure_hibernation() {
    log "Configuring hibernation..."
    
    # Check if swap partition exists and is encrypted
    if ! swapon --show | grep -q "/dev/mapper/swap"; then
        warning "Encrypted swap not found. Hibernation may not work properly."
        return
    fi
    
    # Get swap partition info
    SWAP_UUID=$(findmnt -no UUID -T /proc/swaps | tail -1)
    if [[ -z "$SWAP_UUID" ]]; then
        SWAP_UUID=$(blkid -s UUID -o value /dev/mapper/swap)
    fi
    
    log "Swap UUID: $SWAP_UUID"
    
    # Configure systemd for hibernation
    log "Configuring systemd hibernation settings..."
    
    # Create systemd sleep configuration
    sudo tee /etc/systemd/sleep.conf << EOF
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
AllowHybridSleep=yes
SuspendMode=
SuspendState=mem standby freeze
HibernateMode=platform shutdown
HibernateState=disk
HybridSleepMode=suspend platform shutdown
HybridSleepState=disk
SuspendToHibernateDelay=2h
EOF
    
    # Test hibernation capability
    log "Testing hibernation capability..."
    if sudo test -f /sys/power/disk; then
        log "Hibernation is supported by kernel"
        log "Available hibernation modes: $(cat /sys/power/disk)"
    else
        warning "Hibernation may not be supported by kernel"
    fi
    
    # Create hibernation test script
    cat > "$HOME/bin/test-hibernation" << 'EOF'
#!/bin/bash
# Test hibernation script

echo "Testing hibernation capability..."

# Check swap
echo "Swap status:"
swapon --show

# Check hibernation support
echo "Hibernation support:"
cat /sys/power/state

echo "Hibernation modes:"
cat /sys/power/disk

# Check resume device
echo "Resume device in kernel parameters:"
cat /proc/cmdline | grep -o 'resume=[^ ]*'

echo "To test hibernation, run: sudo systemctl hibernate"
echo "To test suspend-then-hibernate: sudo systemctl suspend-then-hibernate"
EOF
    
    chmod +x "$HOME/bin/test-hibernation"
    
    log "Hibernation configured successfully!"
    info "Test hibernation with: ~/bin/test-hibernation"
    info "Hibernate with: sudo systemctl hibernate"
    info "Suspend-then-hibernate: sudo systemctl suspend-then-hibernate"
}

# Configure security
configure_security() {
    log "Configuring security..."
    
    # Install firewall
    yay -S --noconfirm ufw
    
    # Configure firewall
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw enable
    
    # Configure automatic security updates
    yay -S --noconfirm unattended-upgrades
    
    log "Security configured"
}

# Configure backup
configure_backup() {
    log "Configuring backup..."
    
    # Install backup tools
    yay -S --noconfirm timeshift
    
    # Create backup configuration
    sudo timeshift --create --comments "Initial backup after installation"
    
    log "Backup configured"
}

# Configure shared storage
configure_shared_storage() {
    log "Configuring shared storage..."
    
    # Create mount point
    sudo mkdir -p /mnt/shared
    
    # Add to fstab for automatic mounting
    echo "/dev/nvme0n1p3 /mnt/shared ntfs-3g defaults,uid=$(id -u),gid=$(id -g),umask=0022,noatime 0 0" | sudo tee -a /etc/fstab
    
    # Mount the partition
    sudo mount -a
    
    # Set permissions
    sudo chown "$USERNAME:$USERNAME" /mnt/shared
    
    log "Shared storage configured"
}

# Create useful scripts
create_scripts() {
    log "Creating useful scripts..."
    
    # Create update script
    cat > "$HOME/bin/update-system" << 'EOF'
#!/bin/bash
# System update script
sudo pacman -Syu
yay -Syu
sudo pkgfile -u
EOF
    
    # Create backup script
    cat > "$HOME/bin/backup-system" << 'EOF'
#!/bin/bash
# System backup script
sudo timeshift --create --comments "Manual backup $(date)"
EOF
    
    # Make scripts executable
    chmod +x "$HOME/bin/update-system"
    chmod +x "$HOME/bin/backup-system"
    
    log "Useful scripts created"
}

# Main function
main() {
    log "Post-Installation Setup for Arch Linux on Dell XPS 13\" 9350"
    echo
    
    check_root
    get_user_input
    
    log "Starting post-installation setup..."
    
    update_system
    install_additional_packages
    configure_shell
    configure_development
    configure_gnome
    configure_services
    configure_hibernation
    configure_security
    configure_backup
    configure_shared_storage
    create_scripts
    
    log "Post-installation setup completed successfully!"
    info "Please reboot your system to apply all changes"
    
    read -p "Reboot now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo reboot
    fi
}

# Run main function
main "$@"
