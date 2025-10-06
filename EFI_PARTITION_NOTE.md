# EFI Partition Setup for Dell XPS Dual Boot

## The Problem

The Dell XPS comes with a **260MB EFI System Partition** that is shared between Windows and Linux. This partition is:
- **Too small** to hold both Windows EFI files AND Linux kernel files (especially the fallback initramfs which is ~200MB)
- **Already occupied** by Windows Boot Manager, Dell firmware updater, and other Windows-related files

## The Solution

We use a **hybrid boot partition setup**:

### Partition Layout
```
/dev/nvme0n1p1 (260MB)  → EFI System Partition (ESP) - shared with Windows
/dev/nvme0n1p5 (512MB)  → Linux Boot Partition - main storage for kernels
```

### Mount Structure
```
/boot/        → Mounted to p5 (Linux boot partition)
  ├── vmlinuz-linux
  ├── initramfs-linux.img
  ├── initramfs-linux-fallback.img  (~200MB!)
  ├── intel-ucode.img
  └── loader/
      ├── loader.conf
      └── entries/
          ├── arch.conf
          └── arch-fallback.conf

/boot/efi/    → Mounted to p1 (EFI System Partition)
  ├── vmlinuz-linux                  (copied from /boot)
  ├── initramfs-linux.img            (copied from /boot)
  ├── intel-ucode.img                (copied from /boot)
  ├── initramfs-linux-fallback.img   (copied if space available)
  └── EFI/
      ├── systemd/
      │   └── systemd-bootx64.efi
      ├── Microsoft/
      │   └── Boot/...
      └── Dell/...
```

### How It Works

1. **systemd-boot** is installed on the EFI partition (`/boot/efi/EFI/systemd/`)
2. **Boot entries** are stored on the Linux boot partition (`/boot/loader/entries/`)
3. **Kernel files** are stored on both:
   - Main copies on `/boot` (p5) - plenty of space
   - Working copies on `/boot/efi` (p1) - what systemd-boot actually loads
4. **Automatic sync** via pacman hook copies kernel files to EFI after updates

### Why Not XBOOTLDR?

We initially tried using the XBOOTLDR specification (which allows systemd-boot to load kernels from a separate partition), but:
- systemd-boot marked XBOOTLDR entries as `(not reported/new)` 
- Entries were not shown in the boot menu
- Copying files to EFI is simpler and more reliable

### The Pacman Hook

`/etc/pacman.d/hooks/95-copy-to-efi.hook` automatically runs after kernel updates to copy:
- `vmlinuz-linux`
- `initramfs-linux.img`
- `intel-ucode.img`
- `initramfs-linux-fallback.img` (if space available)

From `/boot` to `/boot/efi`.

**Important**: The hook requires both `/boot` and `/boot/efi` to be mounted. These should be automatically mounted at boot via `/etc/fstab`, which is generated during installation. If the partitions aren't mounted, the hook will fail with a clear error message and instructions.

### Space Management

If the EFI partition fills up:

1. **Check what's using space:**
   ```bash
   df -h /boot/efi
   du -sh /boot/efi/*
   ```

2. **Clean old systemd-boot entries:**
   ```bash
   sudo bootctl cleanup
   ```

3. **Remove Windows recovery files** (if not needed):
   ```bash
   # Be careful! Only if you have Windows recovery on USB/separate partition
   sudo rm -rf /boot/efi/EFI/Microsoft/Recovery
   ```

4. **Accept that fallback won't fit:**
   - The main kernel will always work
   - Fallback is only needed if the main initramfs is broken
   - You can boot from USB if needed

### Manual Sync

If you need to manually copy kernel files to EFI:
```bash
sudo /usr/local/bin/copy-kernels-to-efi.sh
```

### Troubleshooting

**Q: Boot menu doesn't show Arch Linux?**
```bash
# Check if kernel files exist on EFI:
ls -lh /boot/efi/*.img /boot/efi/vmlinuz-*

# If missing, copy manually:
sudo cp /boot/vmlinuz-linux /boot/efi/
sudo cp /boot/intel-ucode.img /boot/efi/
sudo cp /boot/initramfs-linux.img /boot/efi/
```

**Q: After kernel update, system won't boot?**
```bash
# Boot from USB, mount partitions:
sudo cryptsetup open /dev/nvme0n1p6 root
sudo mount /dev/mapper/root /mnt
sudo mount /dev/nvme0n1p5 /mnt/boot
sudo mount /dev/nvme0n1p1 /mnt/boot/efi

# Copy kernel files:
sudo cp /mnt/boot/vmlinuz-linux /mnt/boot/efi/
sudo cp /mnt/boot/intel-ucode.img /mnt/boot/efi/
sudo cp /mnt/boot/initramfs-linux.img /mnt/boot/efi/
```

**Q: Want to use only EFI partition (no separate boot)?**

You'd need to free up ~230MB on the EFI partition. This means removing most Windows files, which is risky for dual-boot stability.

## Summary

✅ **Kernel files are stored on p5** (plenty of space, easy to manage)  
✅ **Kernel files are copied to p1** (what systemd-boot loads)  
✅ **Automatic sync on updates** (via pacman hook)  
✅ **Windows remains untouched** (EFI partition shared safely)  
⚠️ **Fallback may not fit** (main kernel always works)

