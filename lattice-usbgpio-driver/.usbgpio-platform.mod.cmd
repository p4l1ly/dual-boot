savedcmd_usbgpio-platform.mod := printf '%s\n'   usbgpio-platform.o | awk '!x[$$0]++ { print("./"$$0) }' > usbgpio-platform.mod
