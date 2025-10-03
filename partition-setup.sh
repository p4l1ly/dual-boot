#!/bin/bash

# Partition Setup Script for Dell XPS 13" 9350 Dual Boot
# This script helps plan and create the partition layout

set -e

# Configuration - Modify these values as needed
DISK="/dev/nvme0n1"
SHARED_SIZE="171GB"
LINUX_SIZE="150GB"
SWAP_SIZE="40GB"  # Increased for hibernation (32GB RAM + 8GB buffer)
BOOT_SIZE="512MB"

# Auto-detect disk and partition information
detect_disk_info() {
    log "Auto-detecting disk and partition information..."
    
    # Get total disk size
    TOTAL_SIZE_BYTES=$(lsblk -bno SIZE "$DISK" | head -1)
    TOTAL_SIZE_GB=$((TOTAL_SIZE_BYTES / 1024 / 1024 / 1024))
    TOTAL_SIZE="${TOTAL_SIZE_GB}GB"
    
    # Get EFI partition size
    if [[ -b "${DISK}p1" ]]; then
        EFI_SIZE_BYTES=$(lsblk -bno SIZE "${DISK}p1")
        EFI_SIZE_MB=$((EFI_SIZE_BYTES / 1024 / 1024))
        EFI_SIZE="${EFI_SIZE_MB}MB"
    else
        error "EFI partition ${DISK}p1 not found!"
        exit 1
    fi
    
    # Get Windows partition size
    if [[ -b "${DISK}p3" ]]; then
        WINDOWS_SIZE_BYTES=$(lsblk -bno SIZE "${DISK}p3")
        WINDOWS_SIZE_GB=$((WINDOWS_SIZE_BYTES / 1024 / 1024 / 1024))
        WINDOWS_SIZE="${WINDOWS_SIZE_GB}GB"
    else
        error "Windows partition ${DISK}p3 not found!"
        error "Please ensure Windows is installed and partition table is correct."
        exit 1
    fi
    
    log "Detected disk information:"
    echo "  Total disk size: $TOTAL_SIZE"
    echo "  EFI partition: $EFI_SIZE"
    echo "  Windows partition: $WINDOWS_SIZE"
    echo "  Configured Linux partitions:"
    echo "    Shared storage: $SHARED_SIZE"
    echo "    Linux root: $LINUX_SIZE"
    echo "    Linux swap: $SWAP_SIZE"
    echo "    Linux boot: $BOOT_SIZE"
}

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
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Display current disk layout
show_current_layout() {
    log "Current disk layout:"
    lsblk -f
    echo
    fdisk -l "$DISK"
}

# Calculate partition sizes
calculate_sizes() {
    log "Calculating partition sizes..."
    
    # Auto-detect current disk information
    detect_disk_info
    
    # Helper function to convert size strings (e.g., "100GB", "512MB") to MB
    size_to_mb() {
        local size_str="$1"
        local num unit
        num=$(echo "$size_str" | grep -oE '^[0-9]+')
        unit=$(echo "$size_str" | grep -oE '[A-Za-z]+$')
        case "$unit" in
            TB|tb) echo $((num * 1024 * 1024));;
            GB|gb) echo $((num * 1024));;
            MB|mb) echo $((num));;
            *) echo "$num";;
        esac
    }

    # Convert sizes to MB for calculations
    TOTAL_MB=$(size_to_mb "$TOTAL_SIZE")
    WINDOWS_MB=$(size_to_mb "$WINDOWS_SIZE")
    SHARED_MB=$(size_to_mb "$SHARED_SIZE")
    LINUX_MB=$(size_to_mb "$LINUX_SIZE")
    SWAP_MB=$(size_to_mb "$SWAP_SIZE")
    EFI_MB=$(size_to_mb "$EFI_SIZE")
    BOOT_MB=$(size_to_mb "$BOOT_SIZE")
    
    # Calculate space used by Linux partitions only
    LINUX_USED_MB=$((SHARED_MB + LINUX_MB + SWAP_MB + BOOT_MB))
    
    # Get currently used space (existing partitions)
    local used_space_bytes=0
    for part in p1 p2 p3 p4; do
        if [[ -b "${DISK}${part}" ]]; then
            local part_size=$(lsblk -bno SIZE "${DISK}${part}" 2>/dev/null || echo "0")
            used_space_bytes=$((used_space_bytes + part_size))
        fi
    done
    local used_space_mb=$((used_space_bytes / 1024 / 1024))
    local available_mb=$((TOTAL_MB - used_space_mb))
    
    info "Partition size breakdown:"
    echo "  Total disk: ${TOTAL_MB}MB (${TOTAL_SIZE})"
    echo "  EFI partition: ${EFI_MB}MB (${EFI_SIZE}) - existing"
    echo "  Windows partition: ${WINDOWS_MB}MB (${WINDOWS_SIZE}) - existing"
    echo "  Currently used space: ${used_space_mb}MB"
    echo "  Available free space: ${available_mb}MB"
    echo "  Linux partitions to create:"
    echo "    Shared storage: ${SHARED_MB}MB (${SHARED_SIZE})"
    echo "    Linux boot: ${BOOT_MB}MB (${BOOT_SIZE})"
    echo "    Linux root: ${LINUX_MB}MB (${LINUX_SIZE})"
    echo "    Linux swap: ${SWAP_MB}MB (${SWAP_SIZE})"
    echo "  Total Linux space needed: ${LINUX_USED_MB}MB"
    
    # Check if there's enough space
    if [[ $available_mb -lt $LINUX_USED_MB ]]; then
        error "Insufficient free space!"
        error "Available: ${available_mb}MB, Needed: ${LINUX_USED_MB}MB"
        error "Please shrink Windows partition further or reduce Linux partition sizes."
        exit 1
    else
        info "✓ Sufficient free space available (${available_mb}MB >= ${LINUX_USED_MB}MB)"
    fi
    echo
}


# Add Linux partitions to existing Windows setup
add_linux_partitions() {
    log "Adding Linux partitions to existing Windows setup..."
    
    log "Current partition layout:"
    parted "$DISK" print
    echo
    
    # Detect free space after Windows partitions dynamically
    log "Detecting free space after Windows partitions..."
    
    # Get the end of the last Windows partition (p4 - Recovery)
    local recovery_end_sector=$(parted "$DISK" unit s print | grep "^ 4" | awk '{print $3}' | sed 's/s//')
    if [[ -z "$recovery_end_sector" ]]; then
        error "Could not detect Windows Recovery partition end. Please check partition layout."
        exit 1
    fi
    
    # Convert sectors to MB (assuming 512 bytes per sector)
    local recovery_end_mb=$(( (recovery_end_sector * 512) / (1024 * 1024) ))
    
    # Start Linux partitions right after Windows Recovery, with small gap for alignment
    local linux_start_mb=$((recovery_end_mb + 1))
    
    log "Windows Recovery partition ends at sector $recovery_end_sector (${recovery_end_mb}MB)"
    log "Linux partitions will start at ${linux_start_mb}MB"
    
    # Calculate sizes
    calculate_sizes
    
    # Calculate partition boundaries for Linux partitions
    local shared_end=$((linux_start_mb + SHARED_MB))
    local boot_end=$((shared_end + BOOT_MB))
    local root_end=$((boot_end + LINUX_MB))
    local swap_end=$((root_end + SWAP_MB))
    
    info "Creating Linux partitions:"
    info "  p5: Shared Storage (${SHARED_SIZE}) - LUKS encrypted"
    info "  p6: Linux Boot (${BOOT_SIZE})"
    info "  p7: Linux Root (${LINUX_SIZE}) - LUKS encrypted"
    info "  p8: Linux Swap (${SWAP_SIZE}) - LUKS encrypted"
    echo
    
    log "Linux partition boundaries:"
    log "  Shared: ${linux_start_mb}MiB - ${shared_end}MiB"
    log "  Boot: ${shared_end}MiB - ${boot_end}MiB"
    log "  Root: ${boot_end}MiB - ${root_end}MiB"
    log "  Swap: ${root_end}MiB - ${swap_end}MiB"
    
    # Create LUKS Encrypted Shared Storage Partition
    log "Creating LUKS encrypted shared partition..."
    parted "$DISK" mkpart primary "${linux_start_mb}MiB" "${shared_end}MiB"
    
    # Create Linux Boot Partition
    log "Creating Linux boot partition..."
    parted "$DISK" mkpart primary ext4 "${shared_end}MiB" "${boot_end}MiB"
    
    # Create Linux Root Partition
    log "Creating Linux root partition..."
    parted "$DISK" mkpart primary "${boot_end}MiB" "${root_end}MiB"
    
    # Create Linux Swap Partition
    log "Creating Linux swap partition..."
    parted "$DISK" mkpart primary "${root_end}MiB" "${swap_end}MiB"
    
    log "Linux partitions created successfully!"
    parted "$DISK" print
}

# Format partitions
format_linux_partitions() {
    log "Formatting Linux partitions only (Windows partitions untouched)..."
    
    # Format Linux boot partition
    log "Formatting Linux boot partition..."
    mkfs.ext4 -F -L "LinuxBoot" "${DISK}p6"
    
    # Set up LUKS encryption for shared partition
    log "Setting up LUKS encryption for shared partition..."
    cryptsetup luksFormat "${DISK}p5"
    cryptsetup open "${DISK}p5" shared
    mkfs.ext4 -F -L "SharedEncrypted" /dev/mapper/shared
    cryptsetup close shared
    
    # Set up LUKS encryption for root partition
    log "Setting up LUKS encryption for root partition..."
    cryptsetup luksFormat "${DISK}p7"
    cryptsetup open "${DISK}p7" root
    mkfs.ext4 -F -L "LinuxRoot" /dev/mapper/root
    cryptsetup close root
    
    # Set up LUKS encryption for swap partition
    log "Setting up LUKS encryption for swap partition..."
    cryptsetup luksFormat "${DISK}p8"
    cryptsetup open "${DISK}p8" swap
    mkswap -L "LinuxSwap" /dev/mapper/swap
    cryptsetup close swap
    
    log "Linux partitions formatted successfully!"
    info "Shared partition accessible from:"
    info "- Linux: Native LUKS support at /mnt/shared"
    info "- Windows: Via WSL after proper setup"
}


# Show final layout
show_final_layout() {
    log "Final partition layout:"
    lsblk -f
    echo
    parted "$DISK" print
}

# Interactive menu
interactive_menu() {
    while true; do
        echo
        echo "=== Dell XPS 13\" 9350 Dual Boot Setup ==="
        echo "1. Show current disk layout"
        echo "2. Add Linux partitions (after manual Windows shrinking)"
        echo "3. Format Linux partitions (LUKS encrypted)"
        echo "4. Show final layout"
        echo "5. Exit"
        echo
        echo -n "Select an option (1-5): "
        read -r choice
        
        case $choice in
            1)
                show_current_layout
                ;;
            2)
                add_linux_partitions
                ;;
            3)
                format_linux_partitions
                ;;
            4)
                show_final_layout
                ;;
            5)
                info "Exiting..."
                exit 0
                ;;
            *)
                error "Invalid option. Please select 1-5."
                ;;
        esac
    done
}

# Main function
main() {
    log "Dell XPS 13\" 9350 Partition Setup Script"
    log "Target disk: $DISK"
    echo
    
    check_root
    detect_disk_info
    
    if [[ $# -eq 0 ]]; then
        interactive_menu
    else
        case "$1" in
            "show")
                show_current_layout
                ;;
            "create")
                add_linux_partitions
                ;;
            "format")
                format_linux_partitions
                ;;
            "layout")
                show_final_layout
                ;;
            *)
                echo "Usage: $0 [show|create|format|layout]"
                echo "  show      - Show current disk layout"
                echo "  create    - Add Linux partitions (after manual Windows shrinking)"
                echo "  format    - Format Linux partitions (LUKS encrypted)"
                echo "  layout    - Show final layout"
                echo "  (no args) - Interactive menu"
                exit 1
                ;;
        esac
    fi
}

# Run main function
main "$@"
