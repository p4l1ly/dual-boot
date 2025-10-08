#!/bin/bash
# Check dmesg output for camera

sudo dmesg | grep -i -E "ipu|ivsc|ov02|camera|INT3472" | tail -100


