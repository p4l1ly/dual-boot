# Automated LUKS Password Setup

Both `partition-setup.sh` and `arch-install.sh` now use a password file for fully automated LUKS operations.

## Setup

1. **Create the password file:**
   ```bash
   echo 'your-strong-password' > luks-password.txt
   chmod 600 luks-password.txt
   ```

2. **Run partition setup:**
   ```bash
   sudo ./partition-setup.sh
   # Choose option 3 to format partitions
   # It will automatically use luks-password.txt
   ```

3. **Run installation:**
   ```bash
   sudo ./arch-install.sh
   # It will automatically use luks-password.txt for:
   # - Opening encrypted containers
   # - Adding keyfiles to LUKS
   ```

## Security Notes

- **Password file contains plaintext password** - keep it secure!
- The file is checked for:
  - Existence (must be present)
  - Non-empty (must contain password)
- After installation, the password file is used only for boot-time decryption
- The installed system uses a keyfile (`/etc/keys/root.key`) for automatic decryption of swap and shared partitions

## What Gets Encrypted

All three LUKS containers use the **same password** from `luks-password.txt`:
- `/dev/nvme0n1p6` - Root partition
- `/dev/nvme0n1p7` - Shared storage partition  
- `/dev/nvme0n1p8` - Swap partition

## Boot Process

After installation:
1. systemd-boot prompts for LUKS password (once)
2. Root partition is decrypted with your password
3. Swap and shared partitions are auto-decrypted using keyfile from root

## Partition Type GUID

The updated `partition-setup.sh` now automatically sets the XBOOTLDR partition type GUID for `p5`:
```
BC13C2FF-59E6-4262-A352-B275FD6F7172
```
This ensures systemd-boot can find boot entries on the XBOOTLDR partition.

## Example Workflow

```bash
# 1. Create password file
echo 'MySecurePass123!' > luks-password.txt
chmod 600 luks-password.txt

# 2. Format partitions (uses password file)
sudo ./partition-setup.sh
# Select option 3

# 3. Install Arch (uses password file)
sudo ./arch-install.sh
# Enter username when prompted
# Enter user/root passwords when prompted
# LUKS operations are automated

# 4. Reboot
# At boot: Enter 'MySecurePass123!' when prompted
```

## Cleanup

After successful installation and verification, you can optionally remove the password file:
```bash
shred -u luks-password.txt
```

**Note:** Keep a secure backup of your password! You'll need it to:
- Boot your system
- Recover from issues
- Re-run installation if needed

