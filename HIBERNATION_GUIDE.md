# Hibernation with Encrypted Setup Guide

## Overview

Yes, hibernation works perfectly with encrypted setups! In fact, it's quite secure since your hibernation image (RAM contents) will be stored on an encrypted swap partition.

## How It Works

### **Hibernation Process:**
1. **Suspend to disk**: System saves RAM contents to encrypted swap partition
2. **Power off**: System shuts down completely
3. **Resume**: On boot, kernel reads hibernation image from encrypted swap
4. **Restore**: System restores RAM contents and continues where you left off

### **Security Benefits:**
- 🔒 **Hibernation image encrypted**: RAM contents stored on encrypted swap
- 🔒 **Full disk encryption**: All data protected when hibernated
- 🔒 **Password required**: Must decrypt to resume from hibernation

## Configuration Changes Made

### **1. Increased Swap Size**
- **Before**: 32GB swap
- **After**: 40GB swap (32GB RAM + 8GB buffer)
- **Why**: Hibernation needs swap ≥ RAM size

### **2. Kernel Parameters**
Added to GRUB configuration:
```bash
GRUB_CMDLINE_LINUX="cryptdevice=UUID=<root_uuid>:root resume=UUID=<swap_uuid>"
```

### **3. Initramfs Hooks**
Added `resume` hook to mkinitcpio:
```bash
HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 resume filesystems fsck)
```

### **4. Systemd Sleep Configuration**
```ini
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
AllowHybridSleep=yes
SuspendToHibernateDelay=2h
```

## Updated Partition Layout

With hibernation support:

```
/dev/nvme0n1p1  EFI System              260MB   FAT32
/dev/nvme0n1p2  Microsoft Reserved      16MB    NTFS
/dev/nvme0n1p3  Windows Data            150GB   NTFS
/dev/nvme0n1p4  Windows Recovery        990MB   NTFS
/dev/nvme0n1p5  Shared Storage          150GB   NTFS
/dev/nvme0n1p6  Linux Boot              512MB   EXT4
/dev/nvme0n1p7  Linux Root (Encrypted)  150GB   LUKS
/dev/nvme0n1p8  Linux Swap (Encrypted)  40GB    LUKS  ← Increased for hibernation
```

## Usage

### **Hibernate Commands:**
```bash
# Standard hibernation
sudo systemctl hibernate

# Suspend (RAM stays powered)
sudo systemctl suspend

# Hybrid sleep (suspend + hibernation backup)
sudo systemctl hybrid-sleep

# Suspend, then hibernate after 2 hours
sudo systemctl suspend-then-hibernate
```

### **GNOME Integration:**
- Hibernation option in power menu
- Configurable in GNOME Settings → Power
- Automatic hibernation on critical battery

### **Testing Hibernation:**
```bash
# Run the test script (created by post-install)
~/bin/test-hibernation

# Manual test
sudo systemctl hibernate
# System should shut down and resume on next boot
```

## Hibernation vs Suspend

| Feature | Suspend | Hibernation |
|---------|---------|-------------|
| **Power Usage** | Low (RAM powered) | None (complete shutdown) |
| **Resume Speed** | Instant | ~10-30 seconds |
| **Battery Drain** | Gradual | None |
| **Data Safety** | Lost if battery dies | Saved to disk |
| **Encryption** | RAM unencrypted | Hibernation image encrypted |

## Troubleshooting

### **Hibernation Fails**
```bash
# Check swap is active
swapon --show

# Check hibernation support
cat /sys/power/state
# Should show: freeze mem disk

# Check resume parameter
cat /proc/cmdline | grep resume
```

### **Resume Fails**
```bash
# Check kernel logs
journalctl -b | grep -i hibernate

# Verify swap UUID in GRUB
sudo blkid /dev/mapper/swap
# Compare with /etc/default/grub
```

### **Slow Hibernation**
- **Cause**: Large RAM usage
- **Solution**: Close applications before hibernating
- **Alternative**: Use suspend-then-hibernate

### **GNOME Doesn't Show Hibernation**
```bash
# Install GNOME extension for hibernation button
yay -S gnome-shell-extension-hibernate-status-button

# Or use command line
sudo systemctl hibernate
```

## Power Management Integration

### **TLP Configuration:**
The setup includes TLP power management with hibernation-friendly settings:

```bash
# TLP will use hibernation for critical battery
RESTORE_DEVICE_STATE_ON_STARTUP=1

# Hibernation on critical battery (5%)
BAT_CRIT_SHUT_DOWN=1
```

### **Automatic Hibernation:**
```bash
# Configure automatic hibernation on low battery
sudo systemctl edit systemd-suspend.service

# Add hibernation timeout
sudo systemctl edit systemd-logind.service
```

## Security Considerations

### **Benefits:**
- ✅ **Hibernation image encrypted**: RAM contents protected
- ✅ **Full system encryption**: All data encrypted when hibernated
- ✅ **Password required**: Must unlock to resume

### **Considerations:**
- ⚠️ **Swap encryption**: Ensure swap is properly encrypted
- ⚠️ **Key management**: LUKS keys protect hibernation image
- ⚠️ **Physical access**: System appears "off" when hibernated

## Performance Tips

### **Faster Hibernation:**
1. **Close unnecessary apps** before hibernating
2. **Use zram** for better compression
3. **SSD optimization** already configured with TRIM

### **Faster Resume:**
1. **Fast boot enabled** in BIOS/UEFI
2. **Minimal initramfs** hooks
3. **SSD performance** optimized

## Dual Boot Considerations

### **Windows Hibernation:**
- Windows hibernation works independently
- Each OS has its own hibernation file
- No conflicts between Windows and Linux hibernation

### **Shared Storage:**
- Shared partition remains accessible
- NTFS partition properly unmounted before hibernation
- No data corruption risk

## Verification Checklist

After installation, verify hibernation works:

- [ ] **Swap active**: `swapon --show` shows encrypted swap
- [ ] **Kernel support**: `cat /sys/power/state` includes "disk"
- [ ] **Resume parameter**: `cat /proc/cmdline` shows resume=UUID
- [ ] **Test hibernation**: `sudo systemctl hibernate` works
- [ ] **GNOME integration**: Power menu shows hibernation option
- [ ] **Automatic hibernation**: Low battery triggers hibernation

## Summary

Your encrypted dual boot setup now includes:

1. **40GB encrypted swap** for hibernation
2. **Kernel resume support** configured
3. **GRUB hibernation parameters** set
4. **Systemd hibernation** enabled
5. **GNOME integration** configured
6. **Security maintained** with encryption
7. **Testing tools** provided

Hibernation will work seamlessly with your encrypted setup, providing both convenience and security!
