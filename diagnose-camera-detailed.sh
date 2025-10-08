#!/bin/bash
# Detailed camera diagnostics for Dell XPS 13

echo "==== Detailed Camera Diagnostics ===="
echo

echo "=== Hardware Detection ==="
echo "USB devices:"
lsusb | grep -E "Camera|Lattice|SLS"
echo

echo "PCI devices:"
lspci | grep -i -E "vga|display|multimedia"
echo

echo "=== Kernel Modules ==="
echo "Loaded camera-related modules:"
lsmod | grep -E "ipu|ivsc|ov02|mei|video" | head -20
echo

echo "=== IPU Module Details ==="
modinfo intel_ipu6 | grep -E "filename|version|alias|depends"
echo

echo "=== Video Devices ==="
ls -la /dev/video* 2>&1 || echo "No /dev/video* devices found"
echo

echo "=== Media Devices ==="
ls -la /dev/media* 2>&1 || echo "No /dev/media* devices found"
echo

echo "=== V4L2 Subdevices ==="
ls -la /dev/v4l-subdev* 2>&1 || echo "No v4l-subdev* devices found"
echo

echo "=== Kernel Messages (requires sudo) ==="
echo "Recent IPU6 messages:"
sudo dmesg | grep -i "ipu6" | tail -30
echo

echo "Recent IVSC messages:"
sudo dmesg | grep -i "ivsc" | tail -30
echo

echo "Recent camera sensor messages:"
sudo dmesg | grep -i "ov02" | tail -30
echo

echo "Camera-related errors:"
sudo dmesg | grep -i -E "camera|ov02|ipu6|ivsc" | grep -i -E "error|fail|timeout" | tail -20
echo

echo "=== Firmware Loading ==="
sudo dmesg | grep -i firmware | grep -i -E "ipu|camera" | tail -20
echo

echo "=== ACPI/Device Tree ==="
echo "ACPI camera devices:"
ls -la /sys/bus/acpi/devices/INT3* 2>&1 | head -20
echo

echo "=== libcamera Status ==="
if command -v libcamera-hello > /dev/null 2>&1; then
    echo "Testing libcamera detection:"
    libcamera-hello --list-cameras 2>&1 | head -20
else
    echo "libcamera-hello not installed"
fi
echo

echo "=== PipeWire libcamera plugin ==="
ls -la /usr/lib/spa-0.2/libcamera/ 2>&1 || echo "PipeWire libcamera plugin not found"
echo

echo "==== Diagnostic Complete ===="


