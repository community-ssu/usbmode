#!/bin/sh

bme () {
	if test -f /etc/bme-disabled; then
		return 0
	fi
	if lsmod | grep -q bq2415x_charger; then
		rmmod bq2415x_charger || return 1
	fi
	if lsmod | grep -q bq27x00_battery; then
		rmmod bq27x00_battery || return 1
	fi
	if ! pidof bme_RX-51 1>/dev/null 2>&1; then
		msg "Starting bme"
		B="$(cat /sys/class/backlight/acx565akm/brightness)"
		start -q bme || return 1
		echo "$B" > /sys/class/backlight/acx565akm/brightness
	fi
	return 0
}

kernel () {
	if pidof bme_RX-51 1>/dev/null 2>&1; then
		msg "Stopping bme"
		stop -q bme || return 1
	fi
	if ! lsmod | grep -q bq2415x_charger; then
		modprobe bq2415x_charger || return 1
	fi
	if ! lsmod | grep -q bq27x00_battery; then
		modprobe bq27x00_battery || return 1
	fi
	return 0
}

charger_mode () {
	if test -z "$1"; then
		cat /sys/class/power_supply/bq24150-0/mode
	else
		echo "$1" > /sys/class/power_supply/bq24150-0/mode
	fi
}

usb_mode () {
	echo "$1" > /sys/devices/platform/musb_hdrc/mode
}

usb_enum () {
	echo F > /proc/driver/musb_hdrc
}

usb_device () {
	cat /sys/devices/platform/musb_hdrc/hostdevice
}

usb_attached () {
	lsusb | grep -v '1d6b:0002' > /var/tmp/lsusb &
	sleep 3
	test -s /var/tmp/lsusb
	ret=$?
	kill -9 %1 1>/dev/null 2>&1
	return $ret
}

msg () {
	echo "$1"
	dbus-send --system --type=method_call --dest=org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications.SystemNoteInfoprint string:"$1"
}

host_mode () {

	if usb_attached; then
		msg "Device already visible in system"
		return 0
	fi

	mode=$(charger_mode)
	if ! echo "$mode" | grep -q none && ! echo "$mode" | grep -q boost; then
		msg "Error: Charger attached"
		return 1
	fi

	if lsmod | grep -q g_file_storage; then
		rmmod g_file_storage
	fi

	modprobe g_file_storage stall=0 luns=2 removable

	if test -z "$1"; then
		try=low
		iter="1 2 3 4 5"
	else
		try="$1"
		iter="1"
	fi

	good=

	for i in $iter; do

		msg "Setting usb speed: $try"

		charger_mode none
		sleep 4

		case "$try" in
			low) usb_mode hostl;;
			full) usb_mode hostf;;
			high) usb_mode hosth;;
		esac

		charger_mode boost
		sleep 1

		usb_enum
		sleep 2

		if usb_attached; then
			msg "Done. Device visible in system"
			return 0
		fi

		speed="$(usb_device)"
		msg "Attached device speed: $speed"

		case "$speed" in

			none)
				next="$good"
			;;

			low)
				next=low
			;;

			full/low)
				if test "$try" = "low"; then
					next=full
				else
					next=low
				fi
			;;

			full)
				next=full
			;;

			full/high)
				if test "$try" = "full"; then
					next=high
				else
					next=full
				fi
			;;

			high)
				next=high
			;;

		esac

		if echo "$speed" | grep "$try"; then
			good="$try"
		fi

		if test "$try" = "$next"; then
			msg "Error: Correct speed but device not visible in system"
		fi

		if test -z "$next"; then
			msg "Error: No device attached"
			return 1
		fi

		try="$next"

	done

	msg "Error: Timeout, configuration failed"
	return 1

}

peripheral_mode () {

	if lsmod | grep -q g_file_storage; then
		rmmod g_file_storage
	fi

	if charger_mode 2>/dev/null | grep -q boost; then
		charger_mode none
	fi

	usb_mode peripheral
	charger_mode auto 2>/dev/null
	modprobe g_file_storage stall=0 luns=2 removable

}

if test "$(id -u)" != "0"; then
	msg "Error: You must be root"
	exit 1
fi

if test "$1" = "peripheral"; then
	msg "Setting usb mode to peripheral"
	peripheral_mode
	bme
elif test "$1" = "host"; then
	msg "Setting usb mode to host with boost"
	kernel || exit 1
	host_mode "$2" || exit 1
elif test "$1" = "hostc"; then
	msg "Setting usb mode to host with charging"
	kernel || exit 1
	host_mode "$2" || exit 1
	charger_mode auto
else
	msg "Script '$0' called without valid option. Valid are: peripheral host hostc"
	exit 1
fi

exit 0
