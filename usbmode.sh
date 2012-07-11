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
		B=$(cat /sys/class/backlight/acx565akm/brightness)
		start bme || return 1
		echo $B > /sys/class/backlight/acx565akm/brightness
	fi
	return 0
}

kernel () {
	if pidof bme_RX-51 1>/dev/null 2>&1; then
		stop bme || return 1
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

msg () {
	echo "$1"
	dbus-send --system --type=method_call --dest=org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications.SystemNoteInfoprint string:"$1"
}

host_mode_with_boost () {

	mode=$(charger_mode)
	if ! echo "$mode" | grep -q none && ! echo "$mode" | grep -q boost; then
		msg "Error: Charger attached"
		return 1
	fi

	if test -z "$1"; then
		try=hostl
		good=
	else
		try="$1"
		good="$1"
	fi

	for i in 1 2 3 4; do

		msg "Trying usb mode $try"

#		rmmod g_file_storage
#		sleep 2
		peripheral_mode
		sleep 2

		charger_mode none
		usb_mode "$try"
		charger_mode boost
		sleep 1

		usb_enum
		usb_enum
		sleep 1

		speed="$(usb_device)"
		echo "speed: $speed"

		if echo "$speed" | grep -q low; then
			next=hostl
		elif echo "$speed" | grep -q full; then
			next=hostf
		elif echo "$speed" | grep -q high; then
			next=hosth
		else
			next=
		fi

		echo "next=$next"

		if test "$try" = "$good" && test "$try" = "$next"; then
			msg "Done. Correct mode is $try"
			return 0
		fi

		if test -z "$good"; then
			quit=0
		else
			quit=1
		fi

		if test "$try" = "$next"; then
			good="$try"
			echo "good=$good"
		fi

		if test "$try" = "hostl" && echo "$speed" | grep -q full; then
			next=hostf
		fi

		if test "$try" = "hostf" && echo "$speed" | grep -q full; then
			next=hostf
		fi

		if test "$try" = "hostf" && echo "$speed" | grep -q high; then
			next=hosth
		fi

		if test "$try" = "hosth" && echo "$speed" | grep -q high; then
			next=hosth
		fi

		echo "next=$next"

		if test "$try" = "$next"; then
			msg "Done. Correct mode is $try"
			return 0
		fi

		if test "$quit" = "1"; then
			break
		fi

		if ! test -z "$good" && test -z "$next"; then
			next="$good"
		fi

		echo "next=$next"

		if test -z "$next"; then
			msg "Error: No usb device attached"
			return 1
		fi

		try="$next"

	done

	msg "Error: Timeout"
	return 1

}

#host_mode () {
#
#	charger_mode auto
#
#	try=hostl
#
#	for i in 1 2 3 4; do
#
#		msg "Trying usb mode $try"
#
#		peripheral_mode
#		sleep 1
#
#		rmmod g_file_storage
#		sleep 1
#
#		usb_mode "$try"
#		sleep 1
#
#		usb_enum
#		sleep 1
#
#		speed="$(usb_device)"
#
#		if echo "$speed" | grep -q low; then
#			next=hostl
#		elif echo "$speed" | grep -q full; then
#			next=hostf
#		elif echo "$speed" | grep -q high; then
#			next=hosth
#		else
#			next=
#		fi
#
#		if test "$next" = "$try"; then
#			return 0
#		elif test -z "$next"; then
#			msg "Error: No usb device attached"
#			next=hostf
##			return 1
#		fi
#
#		try="$next"
#
#	done
#
#	return 1
#
#}

peripheral_mode () {

	if charger_mode 2>/dev/null | grep -q boost; then
		charger_mode none
		sleep 1
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
#elif test "$1" = "host"; then
#	msg "Setting usb mode to host without boost"
#	kernel || exit 1
#	host_mode "$2" || exit 1
elif test "$1" = "boost"; then
	msg "Setting usb mode to host with boost"
	kernel || exit 1
	host_mode_with_boost "$2" || exit 1
else
	msg "Script '$0' called without valid option. Valid are: peripheral host boost"
	exit 1
fi

exit 0
