#!/bin/bash
# Check if Lunar Lake GPIO support is present after booting mainline kernel

echo "==== Checking for Lunar Lake GPIO Support ===="
echo

echo "Current kernel:"
uname -r
echo

echo "Checking for INTC10B5 GPIO chip..."
if ls /sys/class/gpio/gpiochip* 2>/dev/null | head -1; then
    echo "GPIO chips found:"
    for chip in /sys/class/gpio/gpiochip*; do
        if [ -e "$chip/label" ]; then
            echo "  $(basename $chip): $(cat $chip/label)"
        fi
    done
else
    echo "No GPIO chips found in /sys/class/gpio/"
fi
echo

echo "Checking platform device INTC10B5..."
if [ -e /sys/bus/platform/devices/INTC10B5:00/driver ]; then
    DRIVER=$(readlink /sys/bus/platform/devices/INTC10B5:00/driver | xargs basename)
    echo "✅ INTC10B5:00 has driver: $DRIVER"
else
    echo "❌ INTC10B5:00 has no driver bound"
fi
echo

echo "Checking for camera power management errors..."
if sudo dmesg | grep -q "cannot find GPIO chip INTC10B5:00"; then
    echo "❌ Still getting GPIO chip errors"
    sudo dmesg | grep "INTC10B5" | tail -5
else
    echo "✅ No GPIO chip errors found!"
fi
echo

echo "Checking for video devices..."
if ls /dev/video* 2>/dev/null; then
    echo "✅ Video devices found!"
    ls -la /dev/video*
    echo
    echo "Device details:"
    v4l2-ctl --list-devices
else
    echo "❌ No /dev/video* devices yet"
fi
echo

echo "Checking loaded pinctrl modules..."
lsmod | grep pinctrl
echo

echo "==== Check Complete ===="
echo

if ls /dev/video* 2>/dev/null; then
    echo "SUCCESS! Webcam should be working. Test with:"
    echo "  libcamera-hello --list-cameras"
    echo "  mpv av://v4l2:/dev/video0"
else
    echo "Webcam still not working. Additional troubleshooting needed."
    echo "Check full diagnosis: cat webcam-diagnosis-report.md"
fi


