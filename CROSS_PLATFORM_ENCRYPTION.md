# Cross-Platform Encryption for Shared Storage

## The Problem

You want a **truly shared** partition that is:
- ✅ **Accessible from both Windows and Linux**
- ✅ **Encrypted for security**
- ✅ **Easy to use on both systems**

LUKS encryption is Linux-only, so it's **not really shared**. Here are the real cross-platform solutions:

## Option 1: VeraCrypt (Recommended)

### **How It Works:**
- Shared partition formatted as regular NTFS
- Create encrypted **container files** on the partition
- Both Windows and Linux can mount VeraCrypt containers
- Files inside containers are fully encrypted

### **Advantages:**
- ✅ **True cross-platform**: Works identically on both systems
- ✅ **Strong encryption**: AES-256, Serpent, Twofish
- ✅ **Flexible**: Multiple containers for different purposes
- ✅ **Hidden volumes**: Plausible deniability
- ✅ **Mature software**: Well-tested, widely used
- ✅ **No filesystem limitations**: Works with any base filesystem

### **Setup Process:**

#### **1. Install VeraCrypt:**
```bash
# Linux (after Arch installation)
yay -S veracrypt

# Windows
# Download from https://www.veracrypt.fr/
```

#### **2. Create Encrypted Container:**
```bash
# Create 100GB encrypted container
veracrypt --create /mnt/shared/documents.vc \
  --size 100G \
  --encryption AES \
  --hash SHA-512 \
  --filesystem NTFS \
  --password
```

#### **3. Mount Container:**
```bash
# Linux
veracrypt /mnt/shared/documents.vc /mnt/encrypted

# Windows (GUI)
# Select container file → Mount → Enter password
```

### **Usage Example:**
```
/mnt/shared/
├── documents.vc (100GB encrypted container)
├── photos.vc (50GB encrypted container)  
├── work.vc (20GB encrypted container)
└── public/ (unencrypted folder for non-sensitive files)
```

## Option 2: BitLocker + dislocker

### **How It Works:**
- Format shared partition with NTFS
- Enable BitLocker encryption from Windows
- Access from Linux using `dislocker` tool

### **Advantages:**
- ✅ **Windows native**: Built into Windows Pro/Enterprise
- ✅ **Hardware integration**: Can use TPM chip
- ✅ **Transparent**: Automatic unlock on Windows
- ✅ **Enterprise ready**: Centrally manageable

### **Disadvantages:**
- ⚠️ **Windows Pro required**: Not available on Home edition
- ⚠️ **Linux complexity**: Requires additional tools
- ⚠️ **Performance**: Additional layer of abstraction
- ⚠️ **Dependency**: Relies on third-party Linux support

### **Setup Process:**

#### **1. Enable BitLocker (Windows):**
```cmd
# Enable BitLocker on shared partition (E:)
manage-bde -on E: -password
```

#### **2. Install dislocker (Linux):**
```bash
# Install dislocker for BitLocker support
sudo pacman -S dislocker

# Mount BitLocker partition
sudo dislocker /dev/nvme0n1p5 -u -- /mnt/bitlocker
sudo mount -o loop /mnt/bitlocker/dislocker-file /mnt/shared
```

## Option 3: File-Level Encryption

### **How It Works:**
- Shared partition remains unencrypted NTFS
- Encrypt individual files/folders as needed
- Use cross-platform encryption tools

### **Tools Available:**
- **7-Zip**: Password-protected archives
- **GPG**: OpenPGP encryption
- **AxCrypt**: File encryption tool
- **Cryptomator**: Cloud-focused encryption

### **Advantages:**
- ✅ **Selective**: Encrypt only sensitive files
- ✅ **Granular**: Different passwords for different files
- ✅ **Tool choice**: Many options available
- ✅ **No partition changes**: Works on any filesystem

### **Disadvantages:**
- ⚠️ **Manual process**: Must remember to encrypt
- ⚠️ **Metadata visible**: File names/sizes may be exposed
- ⚠️ **Inconsistent**: Easy to forget encryption
- ⚠️ **Tool dependency**: Need same tools on both systems

### **Example with 7-Zip:**
```bash
# Create encrypted archive
7z a -p -mhe=on sensitive.7z documents/

# Extract on either system
7z x sensitive.7z
```

## Option 4: Cryptomator

### **How It Works:**
- Creates encrypted "vaults" as regular folders
- Files inside vaults are automatically encrypted
- Cross-platform client applications
- Originally designed for cloud storage

### **Advantages:**
- ✅ **Automatic**: Transparent encryption/decryption
- ✅ **Cross-platform**: Windows, Linux, macOS, mobile
- ✅ **Modern**: Active development, good UI
- ✅ **Cloud-friendly**: Works with any sync service

### **Setup:**
```bash
# Install Cryptomator
# Linux: Available as AppImage or AUR package
yay -S cryptomator

# Windows: Download from cryptomator.org
```

## Comparison Table

| Solution | Windows Access | Linux Access | Encryption | Setup Complexity | Performance |
|----------|---------------|--------------|------------|------------------|-------------|
| **VeraCrypt** | ✅ Native | ✅ Native | 🔒 AES-256 | 🟡 Medium | 🟢 Good |
| **BitLocker** | ✅ Native | ⚠️ dislocker | 🔒 AES-256 | 🔴 Complex | 🟡 Fair |
| **File-level** | ✅ Various | ✅ Various | 🔒 Variable | 🟢 Simple | 🟢 Good |
| **Cryptomator** | ✅ App | ✅ App | 🔒 AES-256 | 🟡 Medium | 🟢 Good |

## Recommended Setup

### **For Maximum Security + Usability:**

1. **Choose Option 2** in the partition script (NTFS + VeraCrypt)
2. **Install VeraCrypt** on both Windows and Linux
3. **Create multiple containers** for different purposes:
   - `personal.vc` - Personal documents
   - `work.vc` - Work files  
   - `photos.vc` - Photo collection
   - `backup.vc` - System backups

### **Container Strategy:**
```
/mnt/shared/ (171GB NTFS partition)
├── personal.vc (50GB) - Personal documents
├── work.vc (30GB) - Work files
├── media.vc (80GB) - Photos, videos
├── public/ (unencrypted) - Non-sensitive files
└── temp/ (unencrypted) - Temporary transfers
```

### **Benefits:**
- ✅ **Selective encryption**: Only sensitive data encrypted
- ✅ **Performance**: Unencrypted files have no overhead
- ✅ **Flexibility**: Different containers for different purposes
- ✅ **Security**: Strong encryption when needed
- ✅ **Compatibility**: Works perfectly on both systems

## Post-Installation Setup

### **1. Install VeraCrypt (both systems)**
```bash
# Add to post-install script
yay -S veracrypt
```

### **2. Create initial containers**
```bash
# Create personal documents container
veracrypt --create /mnt/shared/personal.vc --size 50G --encryption AES --hash SHA-512 --filesystem NTFS

# Create work container  
veracrypt --create /mnt/shared/work.vc --size 30G --encryption AES --hash SHA-512 --filesystem NTFS
```

### **3. Configure auto-mount (optional)**
```bash
# Linux: Add to /etc/fstab or create mount scripts
# Windows: Use VeraCrypt favorites feature
```

## Security Best Practices

### **Password Management:**
- Use **different passwords** for different containers
- Use a **password manager** (KeePassXC works on both systems)
- Consider **keyfiles** for additional security

### **Backup Strategy:**
- **Backup container files** regularly
- **Test restoration** on both systems
- Keep **recovery information** secure

### **Performance Tips:**
- **Don't nest containers** (container inside container)
- **Use appropriate sizes** (don't make containers too large)
- **Consider SSD optimization** for better performance

This approach gives you **true cross-platform encrypted sharing** while maintaining excellent usability on both Windows and Linux!
