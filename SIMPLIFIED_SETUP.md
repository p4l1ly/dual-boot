# Simplified Single-ESP Setup

## What Changed

**Before (complex):**
- p1: Windows ESP (260MB, FAT32)
- p5: Linux XBOOTLDR (512MB, FAT32) - kernels here
- Both mounted: `/boot` for p5, `/boot/efi` for p1
- systemd-boot needed to find entries across two partitions

**After (simple):**
- p1: Windows ESP (260MB, FAT32) - **untouched, Windows only**
- p5: Linux ESP (512MB, FAT32) - **everything Linux (bootloader + kernels)**
- Single mount: `/boot` → p5
- systemd-boot all in one place

## Benefits

1. **Simpler mounting** - only `/boot`, no `/boot/efi`
2. **No cross-partition confusion** - Windows and Linux completely separate
3. **Larger boot partition** - 512MB vs 260MB (shared with Windows)
4. **Cleaner UEFI entries** - p1 for Windows, p5 for Linux
5. **No XBOOTLDR complexity** - standard ESP behavior

## Partition Layout

```
/dev/nvme0n1p1  EFI System (Windows)     260MB   FAT32  [Windows Boot Manager]
/dev/nvme0n1p2  Microsoft Reserved        16MB   NTFS   [Windows]
/dev/nvme0n1p3  Windows System           150GB   NTFS   [Windows OS]
/dev/nvme0n1p4  Windows Recovery         990MB   NTFS   [Windows Recovery]
/dev/nvme0n1p5  EFI System (Linux)       512MB   FAT32  [Linux Boot - systemd-boot + kernels]
/dev/nvme0n1p6  Linux Root (Encrypted)   150GB   LUKS   [Arch Linux /]
/dev/nvme0n1p7  Shared (Encrypted)      ~170GB   LUKS   [Shared storage]
/dev/nvme0n1p8  Linux Swap (Encrypted)    40GB   LUKS   [Swap + hibernation]
```

## File Layout on p5

```
/boot/
├── EFI/
│   ├── systemd/
│   │   └── systemd-bootx64.efi       # Bootloader binary
│   └── Boot/
│       └── BOOTX64.EFI               # Fallback (optional)
├── loader/
│   ├── loader.conf                   # Bootloader config
│   └── entries/
│       ├── arch.conf                 # Arch Linux entry
│       └── arch-fallback.conf        # Fallback entry
├── vmlinuz-linux                     # Kernel
├── initramfs-linux.img               # Initramfs
├── initramfs-linux-fallback.img      # Fallback initramfs
└── intel-ucode.img                   # CPU microcode
```

## Installation Steps

```bash
# 1. Create password file (use -n to avoid trailing newline)
echo -n 'YourStrongPassword' > luks-password.txt
chmod 600 luks-password.txt

# 2. Format partitions (automated)
sudo ./partition-setup.sh
# Select option 3
# p5 will be formatted as ESP (EF00) with FAT32

# 3. Install Arch (automated)
sudo ./arch-install.sh
# Only prompts for root/user passwords
# Mounts only p5 at /boot
# Installs systemd-boot to p5

# 4. Reboot
# UEFI entry "Linux Boot Manager" points to p5
```

## UEFI Boot Entries

After installation, `efibootmgr` shows:

```
Boot0000* Windows Boot Manager    HD(1,GPT,...)/\EFI\Microsoft\Boot\bootmgfw.efi
Boot0001* Linux Boot Manager      HD(5,GPT,...)/\EFI\systemd\systemd-bootx64.efi
BootOrder: 0001,0000
```

- **Boot0000**: Windows (partition 1)
- **Boot0001**: Linux (partition 5)
- Completely independent

## Fixing Boot Issues

If systemd-boot doesn't appear:

```bash
# From live USB
sudo ./reinstall-systemd-boot.sh

# Or manually:
mount /dev/nvme0n1p5 /mnt/boot
bootctl --esp-path=/mnt/boot install
efibootmgr -c -d /dev/nvme0n1 -p 5 -L "Linux Boot Manager" -l '\EFI\systemd\systemd-bootx64.efi'
```

## Advantages Over XBOOTLDR

1. **Standard behavior** - no special GUID needed (just EF00)
2. **Firmware compatibility** - all UEFI firmware understands ESP
3. **Simpler troubleshooting** - one partition to check
4. **More space** - 512MB for kernels vs 260MB shared
5. **Clean separation** - Windows never touches p5, Linux never touches p1

## Why This Works Better

The original dual-mount (p1 + p5 XBOOTLDR) approach had issues:
- Firmware might not support XBOOTLDR GUID
- systemd-boot had to search two partitions
- Dell XPS 9350 firmware was selecting wrong entry

With single ESP (p5 only):
- Standard UEFI behavior
- Everything in one place
- Clear NVRAM entries (part 1 = Windows, part 5 = Linux)
- No confusion about which partition holds what

## Migration from Old Setup

If you already installed with the old dual-ESP method:

1. Back up important data
2. Run `partition-setup.sh` option 3 (reformats p5)
3. Run `arch-install.sh` (reinstalls with new layout)
4. Delete old UEFI entries if needed:
   ```bash
   efibootmgr -b 0001 -B  # Delete old entry
   ```

