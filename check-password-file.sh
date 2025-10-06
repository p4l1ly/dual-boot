#!/bin/bash

# Check if luks-password.txt is correctly formatted

PASSWORD_FILE="luks-password.txt"

echo "=== Checking LUKS Password File ==="
echo

if [[ ! -f "$PASSWORD_FILE" ]]; then
    echo "❌ File '$PASSWORD_FILE' not found"
    echo
    echo "Create it with:"
    echo "  echo -n 'your-password' > $PASSWORD_FILE && chmod 600 $PASSWORD_FILE"
    echo
    echo "IMPORTANT: Use 'echo -n' to avoid adding a newline!"
    exit 1
fi

# Check permissions
PERMS=$(stat -c "%a" "$PASSWORD_FILE")
if [[ "$PERMS" != "600" ]]; then
    echo "⚠️  WARNING: File permissions are $PERMS (should be 600)"
    echo "   Fix with: chmod 600 $PASSWORD_FILE"
    echo
fi

# Check if empty
if [[ ! -s "$PASSWORD_FILE" ]]; then
    echo "❌ File is empty!"
    exit 1
fi

# Get file size
SIZE=$(stat -c "%s" "$PASSWORD_FILE")
echo "✓ File exists: $PASSWORD_FILE"
echo "✓ Size: $SIZE bytes"
echo

# Check for trailing newline
if [[ $(tail -c 1 "$PASSWORD_FILE" | wc -l) -eq 1 ]]; then
    echo "⚠️  WARNING: File ends with a newline character!"
    echo "   This means your password includes \\n at the end."
    echo "   This is usually NOT what you want for LUKS passwords."
    echo
    echo "Fix it with:"
    echo "  1. Read current password: cat $PASSWORD_FILE"
    echo "  2. Recreate without newline: echo -n 'password-here' > $PASSWORD_FILE"
    echo
    exit 1
else
    echo "✓ No trailing newline (correct)"
fi

# Show password length (but not the password itself)
echo "✓ Password length: $SIZE characters"
echo

# Test with cryptsetup (requires a LUKS partition to test against)
echo "To test with an actual LUKS partition:"
echo "  cryptsetup open /dev/nvme0n1p6 test --key-file=$PASSWORD_FILE"
echo "  cryptsetup close test"
echo

echo "✅ Password file looks good!"

