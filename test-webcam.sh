#!/bin/bash
# Simple script to test the webcam

echo "Testing webcam..."
echo

# Check if video devices exist
if ! ls /dev/video* > /dev/null 2>&1; then
    echo "ERROR: No video devices found!"
    echo "Please run ./fix-webcam.sh first"
    exit 1
fi

echo "Available video devices:"
v4l2-ctl --list-devices
echo

# Try to capture a test image with ffmpeg
if command -v ffmpeg > /dev/null 2>&1; then
    echo "Attempting to capture a test image..."
    if ffmpeg -f v4l2 -list_formats all -i /dev/video0 2>&1 | grep -i "video"; then
        echo
        echo "Camera formats available. Capturing test image..."
        ffmpeg -f v4l2 -i /dev/video0 -frames:v 1 /tmp/webcam-test.jpg -y 2>/dev/null && \
        echo "Success! Test image saved to /tmp/webcam-test.jpg" || \
        echo "Failed to capture image"
    fi
else
    echo "ffmpeg not found. Install it to test image capture."
fi

echo

# Test with libcamera if available
if command -v libcamera-hello > /dev/null 2>&1; then
    echo "Testing with libcamera..."
    libcamera-hello --list-cameras
else
    echo "libcamera-hello not found. Install libcamera-tools to test with libcamera."
fi



