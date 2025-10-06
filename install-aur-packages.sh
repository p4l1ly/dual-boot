#!/bin/bash

# Helper script to install AUR packages after installation
# Run this after booting into your new Arch system if AUR installation was skipped

set -e

echo "=== AUR Package Installation Helper ==="
echo

# Check if yay is installed
if ! command -v yay &> /dev/null; then
    echo "yay is not installed. Installing yay-bin first..."
    
    # Create build directory
    BUILD_DIR="$HOME/yay-build"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Clone and build yay-bin
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si
    
    # Cleanup
    cd ~
    rm -rf "$BUILD_DIR"
    
    echo "✓ yay-bin installed"
else
    echo "✓ yay is already installed"
fi

echo

# Read AUR packages from packages-aur.txt
if [[ -f "packages-aur.txt" ]]; then
    echo "Installing AUR packages from packages-aur.txt..."
    
    # Extract package names
    packages=$(grep -v '^#' packages-aur.txt | grep -v '^$' | sed 's/#.*//' | awk '{print $1}' | grep -v '^$' | grep -v '^yay-bin$' | tr '\n' ' ')
    
    if [[ -n "$packages" ]]; then
        echo "Packages to install: $packages"
        echo
        yay -S --noconfirm $packages
        echo
        echo "✓ AUR packages installed successfully"
    else
        echo "No AUR packages found in packages-aur.txt"
    fi
else
    echo "packages-aur.txt not found"
    echo "Please provide the list of AUR packages to install:"
    echo
    echo "Example:"
    echo "  yay -S ghcup-hs-bin google-cloud-cli oh-my-zsh-git slack-desktop zoom"
fi

echo
echo "=== Done ==="
