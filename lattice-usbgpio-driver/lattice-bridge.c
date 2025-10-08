// SPDX-License-Identifier: GPL-2.0
/*
 * Lattice NX33 USB-GPIO Bridge Driver for Linux
 * Based on analysis of Intel's UsbBridge.sys for Windows
 *
 * Supports: Lattice NX33 USB-GPIO bridge (VID_2AC1, PID_20C9)
 * Used in: Dell XPS 13 9350 (2024) and other Lunar Lake laptops
 *
 * This driver provides the USB communication layer for INTC10B5 virtual GPIO.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/usb.h>
#include <linux/gpio/driver.h>
#include <linux/platform_device.h>

#define DRIVER_NAME "lattice-usbgpio"
#define LATTICE_NX33_GPIO_COUNT 10  // Guess - needs verification

/* USB Protocol Commands (extracted from Windows driver) */
#define CMD_GPIOD 0x444F4950  // "GPIOD" - GPIO Direction
#define CMD_GPIOI 0x494F4950  // "GPIOI" - GPIO I/O  
#define CMD_UBGD  0x44474255  // "UBGD" - Unknown purpose

struct lattice_bridge {
	struct usb_device *udev;
	struct usb_interface *intf;
	struct gpio_chip gpio;
	
	/* USB endpoints - assuming bulk transfers like LJCA */
	struct usb_endpoint_descriptor *bulk_in;
	struct usb_endpoint_descriptor *bulk_out;
	
	/* GPIO state */
	unsigned long gpio_dir;  // Direction bitmap (0=in, 1=out)
	unsigned long gpio_val;  // Value bitmap
};

/* USB Communication Functions */

static int lattice_usb_send_cmd(struct lattice_bridge *bridge, u32 cmd, 
				u8 pin, u8 value)
{
	int ret;
	u8 buf[8];  // Command buffer - size is a guess
	int actual_length;
	
	/* Build command packet - GUESSING format:
	 * [0-3]: Command (4 bytes, little endian)
	 * [4]: Pin number
	 * [5]: Value (for write) or 0
	 * Rest: Padding/reserved
	 */
	buf[0] = cmd & 0xFF;
	buf[1] = (cmd >> 8) & 0xFF;
	buf[2] = (cmd >> 16) & 0xFF;
	buf[3] = (cmd >> 24) & 0xFF;
	buf[4] = pin;
	buf[5] = value;
	buf[6] = 0;
	buf[7] = 0;
	
	ret = usb_bulk_msg(bridge->udev,
			   usb_sndbulkpipe(bridge->udev, 
					   bridge->bulk_out->bEndpointAddress),
			   buf, sizeof(buf), &actual_length, 1000);
	
	if (ret < 0) {
		dev_err(&bridge->udev->dev, "USB send failed: %d\n", ret);
		return ret;
	}
	
	return 0;
}

static int lattice_usb_recv_response(struct lattice_bridge *bridge, u8 *data, int len)
{
	int ret;
	int actual_length;
	
	ret = usb_bulk_msg(bridge->udev,
			   usb_rcvbulkpipe(bridge->udev,
					   bridge->bulk_in->bEndpointAddress),
			   data, len, &actual_length, 1000);
	
	if (ret < 0) {
		dev_err(&bridge->udev->dev, "USB recv failed: %d\n", ret);
		return ret;
	}
	
	return actual_length;
}

/* GPIO Chip Operations */

static int lattice_gpio_get_direction(struct gpio_chip *chip, unsigned offset)
{
	struct lattice_bridge *bridge = gpiochip_get_data(chip);
	
	return test_bit(offset, &bridge->gpio_dir) ? GPIO_LINE_DIRECTION_OUT 
						   : GPIO_LINE_DIRECTION_IN;
}

static int lattice_gpio_direction_input(struct gpio_chip *chip, unsigned offset)
{
	struct lattice_bridge *bridge = gpiochip_get_data(chip);
	int ret;
	
	dev_dbg(chip->parent, "Setting GPIO %d to INPUT\n", offset);
	
	/* Send GPIOD command to set direction to input (value 0) */
	ret = lattice_usb_send_cmd(bridge, CMD_GPIOD, offset, 0);
	if (ret == 0)
		clear_bit(offset, &bridge->gpio_dir);
	
	return ret;
}

static int lattice_gpio_direction_output(struct gpio_chip *chip, unsigned offset, int value)
{
	struct lattice_bridge *bridge = gpiochip_get_data(chip);
	int ret;
	
	dev_dbg(chip->parent, "Setting GPIO %d to OUTPUT (value %d)\n", offset, value);
	
	/* Send GPIOD command to set direction to output (value 1) */
	ret = lattice_usb_send_cmd(bridge, CMD_GPIOD, offset, 1);
	if (ret == 0) {
		set_bit(offset, &bridge->gpio_dir);
		/* Also set the initial value */
		ret = lattice_usb_send_cmd(bridge, CMD_GPIOI, offset, value);
		if (ret == 0) {
			if (value)
				set_bit(offset, &bridge->gpio_val);
			else
				clear_bit(offset, &bridge->gpio_val);
		}
	}
	
	return ret;
}

static int lattice_gpio_get(struct gpio_chip *chip, unsigned offset)
{
	struct lattice_bridge *bridge = gpiochip_get_data(chip);
	u8 response[4];  // Response buffer - size is a guess
	int ret;
	
	dev_dbg(chip->parent, "Reading GPIO %d\n", offset);
	
	/* Send GPIOI read command */
	ret = lattice_usb_send_cmd(bridge, CMD_GPIOI, offset, 0xFF); // 0xFF = read?
	if (ret < 0)
		return ret;
	
	/* Receive response */
	ret = lattice_usb_recv_response(bridge, response, sizeof(response));
	if (ret < 0)
		return ret;
	
	/* Parse response - GUESSING format */
	return response[0] & 0x01;  // Bit 0 = value?
}

static void lattice_gpio_set(struct gpio_chip *chip, unsigned offset, int value)
{
	struct lattice_bridge *bridge = gpiochip_get_data(chip);
	
	dev_dbg(chip->parent, "Writing GPIO %d = %d\n", offset, value);
	
	/* Send GPIOI write command */
	lattice_usb_send_cmd(bridge, CMD_GPIOI, offset, value ? 1 : 0);
	
	if (value)
		set_bit(offset, &bridge->gpio_val);
	else
		clear_bit(offset, &bridge->gpio_val);
}

/* USB Driver Probe/Remove */

static int lattice_bridge_probe(struct usb_interface *intf,
				const struct usb_device_id *id)
{
	struct lattice_bridge *bridge;
	struct usb_host_interface *iface_desc;
	struct usb_endpoint_descriptor *endpoint;
	int i, ret;
	
	dev_info(&intf->dev, "Lattice NX33 USB-GPIO bridge detected\n");
	
	bridge = devm_kzalloc(&intf->dev, sizeof(*bridge), GFP_KERNEL);
	if (!bridge)
		return -ENOMEM;
	
	bridge->udev = usb_get_dev(interface_to_usbdev(intf));
	bridge->intf = intf;
	
	/* Find bulk endpoints */
	iface_desc = intf->cur_altsetting;
	for (i = 0; i < iface_desc->desc.bNumEndpoints; i++) {
		endpoint = &iface_desc->endpoint[i].desc;
		
		if (usb_endpoint_is_bulk_in(endpoint))
			bridge->bulk_in = endpoint;
		if (usb_endpoint_is_bulk_out(endpoint))
			bridge->bulk_out = endpoint;
	}
	
	if (!bridge->bulk_in || !bridge->bulk_out) {
		dev_err(&intf->dev, "Missing bulk endpoints\n");
		return -ENODEV;
	}
	
	dev_info(&intf->dev, "Bulk IN: 0x%02x, Bulk OUT: 0x%02x\n",
		 bridge->bulk_in->bEndpointAddress,
		 bridge->bulk_out->bEndpointAddress);
	
	/* Register GPIO chip */
	bridge->gpio.label = "lattice-nx33-gpio";
	bridge->gpio.parent = &intf->dev;
	bridge->gpio.owner = THIS_MODULE;
	bridge->gpio.get_direction = lattice_gpio_get_direction;
	bridge->gpio.direction_input = lattice_gpio_direction_input;
	bridge->gpio.direction_output = lattice_gpio_direction_output;
	bridge->gpio.get = lattice_gpio_get;
	bridge->gpio.set = lattice_gpio_set;
	bridge->gpio.base = -1;  // Dynamic allocation
	bridge->gpio.ngpio = LATTICE_NX33_GPIO_COUNT;
	bridge->gpio.can_sleep = true;  // USB operations can sleep
	
	ret = devm_gpiochip_add_data(&intf->dev, &bridge->gpio, bridge);
	if (ret) {
		dev_err(&intf->dev, "Failed to register GPIO chip: %d\n", ret);
		return ret;
	}
	
	usb_set_intfdata(intf, bridge);
	
	dev_info(&intf->dev, "Lattice NX33 GPIO chip registered with %d pins\n",
		 LATTICE_NX33_GPIO_COUNT);
	
	/* TODO: Device initialization sequence
	 * - May need firmware upload?
	 * - May need configuration commands?
	 * - Check Windows driver initialization
	 */
	
	return 0;
}

static void lattice_bridge_disconnect(struct usb_interface *intf)
{
	dev_info(&intf->dev, "Lattice NX33 USB-GPIO bridge disconnected\n");
	/* GPIO chip is automatically unregistered by devm */
}

/* USB Device ID Table */
static const struct usb_device_id lattice_bridge_table[] = {
	{ USB_DEVICE(0x8086, 0x0B63) },  /* Intel LJCA (for compatibility) */
	{ USB_DEVICE(0x2AC1, 0x20C1) },  /* Lattice NX40 */
	{ USB_DEVICE(0x2AC1, 0x20C9) },  /* Lattice NX33 - YOUR DEVICE */
	{ USB_DEVICE(0x2AC1, 0x20CB) },  /* Lattice NX33U */
	{ USB_DEVICE(0x06CB, 0x0701) },  /* Synaptics Sabre */
	{ }
};
MODULE_DEVICE_TABLE(usb, lattice_bridge_table);

static struct usb_driver lattice_bridge_driver = {
	.name = DRIVER_NAME,
	.probe = lattice_bridge_probe,
	.disconnect = lattice_bridge_disconnect,
	.id_table = lattice_bridge_table,
};

module_usb_driver(lattice_bridge_driver);

MODULE_AUTHOR("Based on Intel UsbBridge.sys analysis");
MODULE_DESCRIPTION("Lattice NX33 USB-GPIO Bridge Driver");
MODULE_LICENSE("GPL");
MODULE_VERSION("0.1");

/*
 * NOTES FOR TESTING:
 * 
 * This is a SKELETON driver based on:
 * - Windows driver analysis (UsbBridge.sys)
 * - Hex dump showing GPIOD/GPIOI commands
 * - LJCA driver architecture reference
 *
 * KNOWN UNKNOWNS:
 * - Exact command packet format (guessed)
 * - Response packet format (guessed)
 * - Pin count (guessed 10)
 * - Initialization sequence (unknown)
 * - Error handling (incomplete)
 *
 * TO TEST:
 * 1. Compile: make -C /lib/modules/$(uname -r)/build M=$(pwd) modules
 * 2. Load: sudo insmod lattice-bridge.ko
 * 3. Check: dmesg | tail -30
 * 4. Verify: ls /sys/class/gpio/
 * 5. Debug: Adjust protocol based on errors
 *
 * NEXT STEPS:
 * - Test probe function (does USB device bind?)
 * - Test GPIO registration (does chip appear?)
 * - Test GPIO operations (do commands work?)
 * - Refine protocol based on testing
 */

