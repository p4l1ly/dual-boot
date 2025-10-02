#!/bin/bash

# Partition Setup Script for Dell XPS 13" 9350 Dual Boot
# This script helps plan and create the partition layout

set -e

# Configuration - Modify these values as needed
DISK="/dev/nvme0n1"
TOTAL_SIZE="512GB"
WINDOWS_SIZE="150GB"
SHARED_SIZE="171GB"
LINUX_SIZE="150GB"
SWAP_SIZE="40GB"  # Increased for hibernation (32GB RAM + 8GB buffer)
EFI_SIZE="260MB"
BOOT_SIZE="512MB"

# Configuration function to allow interactive modification
configure_sizes() {
    log "Current partition configuration:"
    echo "  Total disk size: $TOTAL_SIZE"
    echo "  Windows partition: $WINDOWS_SIZE"
    echo "  Shared storage: $SHARED_SIZE"
    echo "  Linux root: $LINUX_SIZE"
    echo "  Linux swap: $SWAP_SIZE"
    echo "  EFI partition: $EFI_SIZE"
    echo "  Linux boot: $BOOT_SIZE"
    echo
    
    echo -n "Do you want to modify these sizes? (y/N): "
    read -r REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -n "Enter Windows partition size (default: $WINDOWS_SIZE): "
        read -r NEW_WINDOWS_SIZE
        if [[ -n "$NEW_WINDOWS_SIZE" ]]; then
            WINDOWS_SIZE="$NEW_WINDOWS_SIZE"
        fi
        
        echo -n "Enter shared storage size (default: $SHARED_SIZE): "
        read -r NEW_SHARED_SIZE
        if [[ -n "$NEW_SHARED_SIZE" ]]; then
            SHARED_SIZE="$NEW_SHARED_SIZE"
        fi
        
        echo -n "Enter Linux root size (default: $LINUX_SIZE): "
        read -r NEW_LINUX_SIZE
        if [[ -n "$NEW_LINUX_SIZE" ]]; then
            LINUX_SIZE="$NEW_LINUX_SIZE"
        fi
        
        echo -n "Enter swap size (default: $SWAP_SIZE): "
        read -r NEW_SWAP_SIZE
        if [[ -n "$NEW_SWAP_SIZE" ]]; then
            SWAP_SIZE="$NEW_SWAP_SIZE"
        fi
        
        log "Updated configuration:"
        echo "  Windows partition: $WINDOWS_SIZE"
        echo "  Shared storage: $SHARED_SIZE"
        echo "  Linux root: $LINUX_SIZE"
        echo "  Linux swap: $SWAP_SIZE"
    fi
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
    log "Calculating partition sizes for $TOTAL_SIZE disk..."
    
    # Convert to MB for calculations
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

    TOTAL_MB=$(size_to_mb "$TOTAL_SIZE")
    WINDOWS_MB=$(size_to_mb "$WINDOWS_SIZE")
    SHARED_MB=$(size_to_mb "$SHARED_SIZE")
    LINUX_MB=$(size_to_mb "$LINUX_SIZE")
    SWAP_MB=$(size_to_mb "$SWAP_SIZE")
    EFI_MB=$(size_to_mb "$EFI_SIZE")
    BOOT_MB=$(size_to_mb "$BOOT_SIZE")
    
    # Calculate remaining space
    USED_MB=$((WINDOWS_MB + SHARED_MB + LINUX_MB + SWAP_MB + EFI_MB + BOOT_MB))
    REMAINING_MB=$((TOTAL_MB - USED_MB))
    
    info "Partition size breakdown:"
    echo "  EFI System Partition: ${EFI_MB}MB"
    echo "  Windows System: ${WINDOWS_MB}MB (${WINDOWS_SIZE})"
    echo "  Shared Storage: ${SHARED_MB}MB (${SHARED_SIZE})"
    echo "  Linux Boot: ${BOOT_MB}MB"
    echo "  Linux Root: ${LINUX_MB}MB (${LINUX_SIZE})"
    echo "  Linux Swap: ${SWAP_MB}MB (${SWAP_SIZE})"
    echo "  Remaining space: ${REMAINING_MB}MB"
    echo
}

# Create partition layout using parted (DESTRUCTIVE - creates new partition table)
create_partitions_new() {
    log "Creating NEW partition layout (DESTROYS existing data)..."
    
    # Calculate sizes first
    calculate_sizes
    
    error "WARNING: This will DESTROY ALL existing partitions and data!"
    warning "Your current Windows installation will be LOST!"
    echo -n "Are you absolutely sure you want to continue? (y/N): "
    read -r REPLY
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Partition creation cancelled"
        exit 0
    fi
    
    # Calculate partition boundaries
    local start_mb=1
    local efi_end=$((start_mb + EFI_MB))
    local windows_end=$((efi_end + WINDOWS_MB))
    local shared_end=$((windows_end + SHARED_MB))
    local boot_end=$((shared_end + BOOT_MB))
    local root_end=$((boot_end + LINUX_MB))
    local swap_end=$((root_end + SWAP_MB))
    
    log "Partition boundaries:"
    log "  EFI: ${start_mb}MiB - ${efi_end}MiB"
    log "  Windows: ${efi_end}MiB - ${windows_end}MiB"
    log "  Shared: ${windows_end}MiB - ${shared_end}MiB"
    log "  Boot: ${shared_end}MiB - ${boot_end}MiB"
    log "  Root: ${boot_end}MiB - ${root_end}MiB"
    log "  Swap: ${root_end}MiB - ${swap_end}MiB"
    
    # Create GPT partition table
    parted "$DISK" mklabel gpt
    
    # Create EFI System Partition
    log "Creating EFI System Partition (${EFI_SIZE})..."
    parted "$DISK" mkpart primary fat32 "${start_mb}MiB" "${efi_end}MiB"
    parted "$DISK" set 1 esp on
    
    # Create Windows System Partition
    log "Creating Windows System Partition (${WINDOWS_SIZE})..."
    parted "$DISK" mkpart primary ntfs "${efi_end}MiB" "${windows_end}MiB"
    
    # Create Shared Storage Partition
    log "Creating Shared Storage Partition (${SHARED_SIZE})..."
    parted "$DISK" mkpart primary ntfs "${windows_end}MiB" "${shared_end}MiB"
    
    # Create Linux Boot Partition
    log "Creating Linux Boot Partition (${BOOT_SIZE})..."
    parted "$DISK" mkpart primary ext4 "${shared_end}MiB" "${boot_end}MiB"
    
    # Create Linux Root Partition
    log "Creating Linux Root Partition (${LINUX_SIZE})..."
    parted "$DISK" mkpart primary "${boot_end}MiB" "${root_end}MiB"
    
    # Create Linux Swap Partition
    log "Creating Linux Swap Partition (${SWAP_SIZE})..."
    parted "$DISK" mkpart primary "${root_end}MiB" "${swap_end}MiB"
    
    # Show final layout
    log "Partition layout created successfully!"
    parted "$DISK" print
}

# Add Linux partitions to existing Windows setup (SAFE - preserves Windows)
create_partitions() {
    log "Adding Linux partitions to existing Windows setup..."
    
    # Calculate sizes first
    calculate_sizes
    
    log "Current partition layout:"
    parted "$DISK" print
    echo
    
    # Check if we have the expected Windows partitions
    log "Verifying existing Windows partitions..."
    if ! parted "$DISK" print | grep -q "260MB.*fat32"; then
        warning "EFI partition doesn't match expected size (260MB)"
    fi
    
    if ! parted "$DISK" print | grep -q "16.8MB.*ntfs"; then
        warning "Microsoft Reserved partition not found"
    fi
    
    # Calculate where to start Linux partitions (dynamically detect free space)
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
    
    warning "This will add Linux partitions after your existing Windows partitions"
    info "Windows partitions will be preserved:"
    info "  p1: EFI System (260MB) - KEEP"
    info "  p2: Microsoft Reserved (16MB) - KEEP" 
    info "  p3: Windows Data (will be shrunk to ~${WINDOWS_SIZE}) - MODIFY"
    info "  p4: Windows Recovery (990MB) - KEEP"
    info "New Linux partitions will be added:"
    info "  p5: Shared Storage (${SHARED_SIZE})"
    info "  p6: Linux Boot (${BOOT_SIZE})"
    info "  p7: Linux Root (${LINUX_SIZE})"
    info "  p8: Linux Swap (${SWAP_SIZE})"
    echo
    
    echo -n "Continue with adding Linux partitions? (y/N): "
    read -r REPLY
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Partition creation cancelled"
        exit 0
    fi
    
    # First, we need to shrink the Windows data partition (p3)
    log "Step 1: Shrinking Windows data partition..."
    
    echo -n "Do you want to shrink the Windows partition from Linux? (y/N): "
    read -r SHRINK_REPLY
    if [[ $SHRINK_REPLY =~ ^[Yy]$ ]]; then
        shrink_windows_partition
    else
        warning "You should shrink the Windows partition from Windows Disk Management first!"
        warning "This script will only create the Linux partitions in the free space."
    fi
    
    # Calculate partition boundaries for Linux partitions
    local shared_end=$((linux_start_mb + SHARED_MB))
    local boot_end=$((shared_end + BOOT_MB))
    local root_end=$((boot_end + LINUX_MB))
    local swap_end=$((root_end + SWAP_MB))
    
    log "Linux partition boundaries:"
    log "  Shared: ${linux_start_mb}MiB - ${shared_end}MiB"
    log "  Boot: ${shared_end}MiB - ${boot_end}MiB"
    log "  Root: ${boot_end}MiB - ${root_end}MiB"
    log "  Swap: ${root_end}MiB - ${swap_end}MiB"
    
    # Create Shared Storage Partition (LUKS encrypted for WSL access)
    log "Creating LUKS Encrypted Shared Storage Partition (${SHARED_SIZE})..."
    echo
    info "Creating LUKS encrypted partition for WSL access:"
    info "- Encrypted with LUKS (Linux native)"
    info "- Accessible from Linux directly"
    info "- Accessible from Windows via WSL"
    info "- Secure: Full disk encryption"
    echo
    
    log "Creating LUKS encrypted shared partition..."
    parted "$DISK" mkpart primary "${linux_start_mb}MiB" "${shared_end}MiB"
    
    info "Post-installation setup required:"
    info "1. Install WSL on Windows"
    info "2. Configure WSL to access encrypted partition"
    info "3. Set up automatic mounting in both systems"
    
    # Create Linux Boot Partition
    log "Creating Linux Boot Partition (${BOOT_SIZE})..."
    parted "$DISK" mkpart primary ext4 "${shared_end}MiB" "${boot_end}MiB"
    
    # Create Linux Root Partition
    log "Creating Linux Root Partition (${LINUX_SIZE})..."
    parted "$DISK" mkpart primary "${boot_end}MiB" "${root_end}MiB"
    
    # Create Linux Swap Partition
    log "Creating Linux Swap Partition (${SWAP_SIZE})..."
    parted "$DISK" mkpart primary "${root_end}MiB" "${swap_end}MiB"
    
    # Show final layout
    log "Linux partitions added successfully!"
    parted "$DISK" print
}

# Format partitions
format_partitions() {
    log "Formatting partitions..."
    
    # Format EFI partition
    log "Formatting EFI partition..."
    mkfs.fat -F32 "${DISK}p1"
    
    # Format Windows partition
    log "Formatting Windows partition..."
    mkfs.ntfs -Q -L "Windows" "${DISK}p2"
    
    # Format shared storage partition (LUKS encrypted)
    log "Setting up LUKS encrypted shared partition..."
    
    log "Creating LUKS container..."
    cryptsetup luksFormat "${DISK}p5"
    
    log "Opening LUKS container..."
    cryptsetup open "${DISK}p5" shared
    
    log "Creating ext4 filesystem..."
    mkfs.ext4 -F -L "SharedEncrypted" /dev/mapper/shared
    
    log "Closing LUKS container..."
    cryptsetup close shared
    
    log "Shared partition encrypted and formatted successfully!"
    info "This partition will be accessible from:"
    info "- Linux: Native LUKS support"
    info "- Windows: Via WSL with proper setup"
    
    # Format Linux boot partition
    log "Formatting Linux boot partition..."
    mkfs.ext4 -F -L "LinuxBoot" "${DISK}p4"
    
    # Create encrypted containers for root and swap
    log "Setting up encryption for Linux partitions..."
    
    # Root partition encryption
    log "Creating LUKS container for root..."
    cryptsetup luksFormat "${DISK}p5"
    
    # Swap partition encryption
    log "Creating LUKS container for swap..."
    cryptsetup luksFormat "${DISK}p6"
    
    # Open encrypted containers
    log "Opening encrypted containers..."
    cryptsetup open "${DISK}p5" root
    cryptsetup open "${DISK}p6" swap
    
    # Format encrypted partitions
    log "Formatting encrypted partitions..."
    mkfs.ext4 -F -L "LinuxRoot" /dev/mapper/root
    mkswap -L "LinuxSwap" /dev/mapper/swap
    
    # Close encrypted containers
    cryptsetup close root
    cryptsetup close swap
    
    log "All partitions formatted successfully!"
}

# Shrink Windows partition from Linux
shrink_windows_partition() {
    log "Shrinking Windows partition from Linux..."
    
    # Get current Windows partition info
    local windows_part="${DISK}p3"
    log "Analyzing Windows partition: $windows_part"
    
    # Check if partition is BitLocker encrypted
    local fstype=$(lsblk -no FSTYPE "$windows_part")
    log "Detected filesystem type: $fstype"
    
    if [[ "$fstype" == "BitLocker" || "$fstype" == "crypto_LUKS" ]]; then
        error "Windows partition is encrypted with BitLocker!"
        error "Cannot resize BitLocker encrypted partitions from Linux."
        echo
        warning "You have several options:"
        echo "1. RECOMMENDED: Disable BitLocker in Windows, then resize"
        echo "   - Boot Windows → Settings → Update & Security → Device encryption → Turn off"
        echo "   - Or: Control Panel → BitLocker Drive Encryption → Turn off BitLocker"
        echo "   - Wait for decryption to complete (may take hours)"
        echo "   - Then use Windows Disk Management to shrink partition"
        echo
        echo "2. Use Windows tools only:"
        echo "   - Boot Windows → Disk Management → Shrink Volume"
        echo "   - BitLocker partitions can be resized from Windows"
        echo
        echo "3. Advanced: Use manage-bde command in Windows:"
        echo "   - Open Command Prompt as Administrator"
        echo "   - Run: manage-bde -status C: (check BitLocker status)"
        echo "   - Temporarily disable: manage-bde -protectors -disable C:"
        echo "   - Resize partition, then re-enable BitLocker"
        echo
        info "After resizing Windows partition, return here and run:"
        info "./partition-setup.sh create  # to add Linux partitions"
        exit 1
    fi
    
    # Check if ntfs-3g is available for regular NTFS
    if ! command -v ntfsresize &> /dev/null; then
        error "ntfs-3g package is required for resizing NTFS partitions"
        info "Install it with: pacman -S ntfs-3g"
        exit 1
    fi
    
    # Check filesystem for regular NTFS
    if ! ntfsresize --info "$windows_part"; then
        error "Failed to get Windows partition info. Is it NTFS?"
        exit 1
    fi
    
    # Calculate target size (leave some buffer space)
    local target_size_gb=150
    local target_size_mb=$((target_size_gb * 1024))
    local buffer_mb=1024  # 1GB buffer
    local safe_target_mb=$((target_size_mb + buffer_mb))
    
    log "Current Windows partition size: $(lsblk -b --output SIZE -n "$windows_part" | numfmt --to=iec)"
    log "Target size: ${target_size_gb}GB (${safe_target_mb}MB with buffer)"
    
    warning "This will shrink your Windows partition!"
    warning "Make sure Windows is properly shut down (not hibernated)"
    warning "Backup important data before proceeding"
    echo
    
    echo -n "Continue with shrinking Windows partition? (y/N): "
    read -r CONFIRM_SHRINK
    if [[ ! $CONFIRM_SHRINK =~ ^[Yy]$ ]]; then
        info "Windows partition shrinking cancelled"
        return
    fi
    
    # First, check and repair the filesystem
    log "Checking Windows filesystem integrity..."
    if ! ntfsfix "$windows_part"; then
        warning "NTFS filesystem check found issues. Attempting repair..."
        ntfsfix "$windows_part" || {
            error "Failed to repair NTFS filesystem. Boot Windows and run chkdsk first."
            exit 1
        }
    fi
    
    # Perform a dry run first
    log "Performing dry run to check if resize is possible..."
    if ! ntfsresize --no-action --size "${safe_target_mb}M" "$windows_part"; then
        error "Dry run failed. Cannot safely resize Windows partition."
        error "This might be due to:"
        error "  - Insufficient free space"
        error "  - Fragmented files at the end of partition"
        error "  - System files that cannot be moved"
        info "Try defragmenting Windows first, or use a smaller target size."
        exit 1
    fi
    
    log "Dry run successful. Proceeding with actual resize..."
    
    # Perform the actual resize
    log "Resizing NTFS filesystem to ${safe_target_mb}MB..."
    if ! ntfsresize --size "${safe_target_mb}M" "$windows_part"; then
        error "Failed to resize NTFS filesystem"
        exit 1
    fi
    
    # Now resize the partition itself
    log "Resizing partition table..."
    
    # Get the start sector of the Windows partition
    local start_sector=$(parted "$DISK" unit s print | grep "^ 3" | awk '{print $2}' | sed 's/s//')
    local new_end_sector=$(( (safe_target_mb * 1024 * 1024 / 512) + start_sector - 1 ))
    
    log "Resizing partition 3 to end at sector $new_end_sector"
    
    # Resize the partition
    if ! parted "$DISK" resizepart 3 "${new_end_sector}s"; then
        error "Failed to resize partition"
        exit 1
    fi
    
    log "Windows partition successfully shrunk!"
    log "New layout:"
    parted "$DISK" print
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
        echo "=== Dell XPS 13\" 9350 Partition Setup ==="
        echo "1. Show current disk layout"
        echo "2. Configure partition sizes"
        echo "3. Calculate partition sizes"
        echo "4. Shrink Windows partition (from Linux)"
        echo "5. Add Linux partitions (SAFE - preserves Windows)"
        echo "6. Create new partition layout (DESTRUCTIVE - destroys Windows)"
        echo "7. Format partitions"
        echo "8. Show final layout"
        echo "9. Exit"
        echo
        echo -n "Select an option (1-9): "
        read -r choice
        
        case $choice in
            1)
                show_current_layout
                ;;
            2)
                configure_sizes
                ;;
            3)
                calculate_sizes
                ;;
            4)
                shrink_windows_partition
                ;;
            5)
                create_partitions
                ;;
            6)
                create_partitions_new
                ;;
            7)
                format_partitions
                ;;
            8)
                show_final_layout
                ;;
            9)
                info "Exiting..."
                exit 0
                ;;
            *)
                error "Invalid option. Please select 1-9."
                ;;
        esac
    done
}

# Main function
main() {
    log "Dell XPS 13\" 9350 Partition Setup Script"
    log "Target disk: $DISK"
    log "Total size: $TOTAL_SIZE"
    echo
    
    check_root
    
    if [[ $# -eq 0 ]]; then
        interactive_menu
    else
        case "$1" in
            "show")
                show_current_layout
                ;;
            "configure")
                configure_sizes
                ;;
            "calculate")
                calculate_sizes
                ;;
            "shrink")
                shrink_windows_partition
                ;;
            "create")
                create_partitions
                ;;
            "format")
                format_partitions
                ;;
            "layout")
                show_final_layout
                ;;
            *)
                echo "Usage: $0 [show|configure|calculate|shrink|create|format|layout]"
                echo "  show      - Show current disk layout"
                echo "  configure - Configure partition sizes"
                echo "  calculate - Calculate partition sizes"
                echo "  shrink    - Shrink Windows partition from Linux"
                echo "  create    - Add Linux partitions (safe mode)"
                echo "  format    - Format partitions"
                echo "  layout    - Show final layout"
                echo "  (no args) - Interactive menu"
                exit 1
                ;;
        esac
    fi
}

# Run main function
main "$@"
