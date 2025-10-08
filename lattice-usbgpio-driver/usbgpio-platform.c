// SPDX-License-Identifier: GPL-2.0
/*
 * Intel UsbGpio Platform Driver for Linux
 * Connects ACPI device (INTC10B5) to USB GPIO chip (lattice-nx33-gpio)
 *
 * Based on Intel's UsbGpio.sys for Windows
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/acpi.h>
#include <linux/gpio/driver.h>
#include <linux/gpio/consumer.h>
#include <linux/gpio/machine.h>

#define DRIVER_NAME "usbgpio-platform"

struct usbgpio_platform {
	struct platform_device *pdev;
	struct gpio_chip *usb_gpio;  // Points to lattice-nx33-gpio
	struct gpiod_lookup_table *lookup;
};

static int usbgpio_platform_probe(struct platform_device *pdev)
{
	struct usbgpio_platform *ugpio;
	struct gpiod_lookup_table *lookup;
	char *dev_name_str;
	
	dev_info(&pdev->dev, "Intel UsbGpio platform driver probing for %s\n", 
		 dev_name(&pdev->dev));
	
	ugpio = devm_kzalloc(&pdev->dev, sizeof(*ugpio), GFP_KERNEL);
	if (!ugpio)
		return -ENOMEM;
	
	ugpio->pdev = pdev;
	platform_set_drvdata(pdev, ugpio);
	
	/* Create GPIO lookup table to connect this ACPI device to the USB GPIO chip.
	 * This allows INT3472 to find GPIO pins via this device.
	 */
	dev_name_str = devm_kasprintf(&pdev->dev, GFP_KERNEL, "%s", dev_name(&pdev->dev));
	if (!dev_name_str)
		return -ENOMEM;
	
	lookup = devm_kzalloc(&pdev->dev, sizeof(*lookup) + sizeof(struct gpiod_lookup) * 11, 
			      GFP_KERNEL);
	if (!lookup)
		return -ENOMEM;
	
	lookup->dev_id = dev_name_str;
	
	/* Map GPIO pins 0-9 from lattice-nx33-gpio to this device */
	lookup->table[0] = GPIO_LOOKUP("lattice-nx33-gpio", 0, NULL, GPIO_ACTIVE_HIGH);
	lookup->table[1] = GPIO_LOOKUP("lattice-nx33-gpio", 1, NULL, GPIO_ACTIVE_HIGH);
	lookup->table[2] = GPIO_LOOKUP("lattice-nx33-gpio", 2, NULL, GPIO_ACTIVE_HIGH);
	lookup->table[3] = GPIO_LOOKUP("lattice-nx33-gpio", 3, NULL, GPIO_ACTIVE_HIGH);
	lookup->table[4] = GPIO_LOOKUP("lattice-nx33-gpio", 4, NULL, GPIO_ACTIVE_HIGH);
	lookup->table[5] = GPIO_LOOKUP("lattice-nx33-gpio", 5, NULL, GPIO_ACTIVE_HIGH);
	lookup->table[6] = GPIO_LOOKUP("lattice-nx33-gpio", 6, NULL, GPIO_ACTIVE_HIGH);
	lookup->table[7] = GPIO_LOOKUP("lattice-nx33-gpio", 7, NULL, GPIO_ACTIVE_HIGH);
	lookup->table[8] = GPIO_LOOKUP("lattice-nx33-gpio", 8, NULL, GPIO_ACTIVE_HIGH);
	lookup->table[9] = GPIO_LOOKUP("lattice-nx33-gpio", 9, NULL, GPIO_ACTIVE_HIGH);
	memset(&lookup->table[10], 0, sizeof(struct gpiod_lookup)); // Sentinel
	
	gpiod_add_lookup_table(lookup);
	ugpio->lookup = lookup;
	
	dev_info(&pdev->dev, "Created GPIO lookup table for INT3472\n");
	dev_info(&pdev->dev, "INTC10B5 now provides access to lattice-nx33-gpio\n");
	
	return 0;
}

static void usbgpio_platform_remove(struct platform_device *pdev)
{
	struct usbgpio_platform *ugpio = platform_get_drvdata(pdev);
	
	if (ugpio->lookup)
		gpiod_remove_lookup_table(ugpio->lookup);
	
	dev_info(&pdev->dev, "Intel UsbGpio platform driver removed\n");
}

static const struct acpi_device_id usbgpio_acpi_ids[] = {
	{ "INTC1074", },  /* Tiger Lake */
	{ "INTC1096", },  /* Alder Lake */
	{ "INTC100B", },  /* Raptor Lake */
	{ "INTC1007", },  /* Meteor Lake */
	{ "INTC10B2", },  /* Arrow Lake */
	{ "INTC10B5", },  /* Lunar Lake - YOUR DEVICE */
	{ "INTC10D1", },  /* Meteor Lake CVF */
	{ "INTC10E2", },  /* Panther Lake */
	{ }
};
MODULE_DEVICE_TABLE(acpi, usbgpio_acpi_ids);

static struct platform_driver usbgpio_platform_driver = {
	.driver = {
		.name = DRIVER_NAME,
		.acpi_match_table = usbgpio_acpi_ids,
	},
	.probe = usbgpio_platform_probe,
	.remove = usbgpio_platform_remove,
};

module_platform_driver(usbgpio_platform_driver);

MODULE_AUTHOR("Based on Intel UsbGpio.sys analysis");
MODULE_DESCRIPTION("Intel UsbGpio Platform Driver");
MODULE_LICENSE("GPL");
MODULE_VERSION("0.1");

/*
 * NOTE: This is a simple forwarding driver.
 * It binds to ACPI device INTC10B5 and connects to the USB GPIO chip.
 * INT3472 will then be able to find GPIO via ACPI device.
 *
 * TODO: Properly implement GPIO forwarding/lookup mechanism
 */

