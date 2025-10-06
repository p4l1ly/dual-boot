# Split Installation Guide

The installation is now split into two parts for faster iteration and easier testing.

## Two-Part Installation

### Part 1: Base System (`arch-install-base.sh`)
**Run from: Live USB**  
**Time: ~10-15 minutes**

Installs minimal bootable system:
- Core packages (base, linux, firmware)
- Essential utilities (git, curl, vim, NetworkManager)
- LUKS encryption setup
- systemd-boot bootloader
- User account creation
- Basic system configuration

**Result:** Bootable console system with network capability

### Part 2: Extras (`arch-install-extras.sh`)
**Run from: Installed system (after first boot)**  
**Time: ~30-60 minutes (depends on internet speed)**

Installs everything else:
- GNOME desktop environment
- Graphics drivers (Intel)
- All packages from `packages.txt`
- AUR packages from `packages-aur.txt`
- Desktop services (GDM, Bluetooth, etc.)
- User customizations (keyboard remapping)

**Result:** Full desktop environment with all applications

## Installation Workflow

### Step 1: Prepare (on live USB)
```bash
# Boot from Arch USB
# Connect to WiFi
iwctl
> station wlan0 connect "YourWiFi"
> quit

# Create password file (use -n to avoid trailing newline)
cd /path/to/dual-boot
echo -n 'YourStrongPassword' > luks-password.txt
chmod 600 luks-password.txt
```

### Step 2: Partition and Format (on live USB)
```bash
sudo ./partition-setup.sh
# Select option 2: Create partitions (if first time)
# Select option 3: Format partitions
```

### Step 3: Install Base System (on live USB)
```bash
sudo ./arch-install-base.sh
# Prompts:
#   - Confirmation to continue
#   - Root password
#   - User (paly) password
# Takes ~10-15 minutes
```

### Step 4: First Boot (remove USB, reboot)
```bash
# Reboot (remove USB stick)
# Select "Linux Boot Manager" from UEFI menu
# Enter LUKS password when prompted
# Log in as: paly
```

### Step 5: Install Extras (from installed system)
```bash
# Copy the scripts to your home directory (if not already there)
# Or mount USB and access them

sudo ./arch-install-extras.sh
# Installs all desktop packages, AUR, etc.
# Takes ~30-60 minutes
```

### Step 6: Final Reboot
```bash
sudo reboot
# Should boot directly into GNOME after entering LUKS password
```

## Benefits of Split Installation

### 1. **Faster Testing**
- Test bootloader without waiting for full desktop install
- If boot fails, you only lost 10 minutes, not 60
- Can iterate on bootloader configuration quickly

### 2. **Network Independence**
- Base system installs with minimal packages
- Less download time on slow connections
- Can install base, then do extras later when on better network

### 3. **Modular Debugging**
- If system doesn't boot: problem is in base script
- If desktop doesn't work: problem is in extras script
- Clear separation of concerns

### 4. **Flexibility**
- Can install base, boot, test hardware compatibility
- Can customize packages before running extras
- Can run extras multiple times without reinstalling base

### 5. **Better Error Recovery**
- If extras fails, just rerun it
- No need to reformat/reinstall base system
- Less destructive iterations

## What's in Each Script

### `arch-install-base.sh` Installs:
```
base linux linux-firmware intel-ucode zsh sudo cryptsetup lvm2
base-devel git curl wget vim networkmanager openssh man-db man-pages
```

**Services enabled:**
- NetworkManager (for WiFi)
- sshd (for remote access)
- fstrim.timer (for SSD)

**Configured:**
- User account (paly)
- Timezone (Europe/Prague)
- Locale (en_US.UTF-8)
- Hostname (palypc)
- LUKS encryption
- systemd-boot
- Hibernation

### `arch-install-extras.sh` Installs:
- Everything from `packages.txt` (~150 packages)
- Everything from `packages-aur.txt` (~13 AUR packages)

**Services enabled:**
- GDM (display manager)
- iwd (wireless daemon)
- bluetooth

**Configured:**
- Keyboard remapping (Escape ↔ CapsLock)
- GNOME desktop environment
- User customizations

## Comparison to Original Script

### Original `arch-install.sh`:
- Single monolithic script
- ~60 minute installation
- If it fails at minute 50, start over
- Hard to debug which part failed

### New Split Scripts:
- Part 1: 10 minutes → bootable system
- Part 2: 30-60 minutes → full desktop
- If part 2 fails, just rerun it
- Clear separation of base vs extras

## Troubleshooting

### Base system won't boot
```bash
# Boot from USB again
sudo ./reinstall-systemd-boot.sh
# Or debug base installation issues
```

### Extras script fails
```bash
# Just rerun it - it's idempotent
sudo ./arch-install-extras.sh
# Or install missing packages manually
```

### Want to change desktop packages
```bash
# Edit packages.txt and packages-aur.txt
# Rerun extras script
sudo ./arch-install-extras.sh
```

## Original Script Still Available

The original `arch-install.sh` (monolithic) is still in the repository if you prefer a single installation pass. However, the split approach is recommended for:
- Testing bootloader configurations
- Slow internet connections
- Iterative development
- Better error recovery

## Quick Command Reference

```bash
# Create password file first
echo -n 'YourPassword' > luks-password.txt && chmod 600 luks-password.txt

# Full installation (split approach)
sudo ./partition-setup.sh              # Format partitions
sudo ./arch-install-base.sh            # Install base (live USB)
# ... reboot ...
sudo ./arch-install-extras.sh          # Install extras (installed system)

# Full installation (monolithic approach)
sudo ./partition-setup.sh              # Format partitions
sudo ./arch-install.sh                 # Install everything (live USB)
```

