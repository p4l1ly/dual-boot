obj-m += lattice-bridge.o
obj-m += usbgpio-platform.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean

install:
	sudo insmod lattice-bridge.ko

uninstall:
	sudo rmmod lattice-bridge

test:
	@echo "Loading driver..."
	sudo insmod lattice-bridge.ko
	@echo "Checking dmesg..."
	dmesg | tail -20
	@echo "Checking GPIO chips..."
	ls -la /sys/class/gpio/ 2>&1 || echo "No GPIO sysfs"

.PHONY: all clean install uninstall test

