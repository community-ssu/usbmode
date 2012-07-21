#!/bin/sh

dbus () {
	run-standalone.sh dbus-send "$1" --type=method_call --dest="$2" "$3" "$4" "$5"
}

msg () {
	echo "$1"
	dbus --system org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications.SystemNoteInfoprint string:"$1"
}

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
		start -q bme
		ret=$?
		echo "$B" > /sys/class/backlight/acx565akm/brightness
		if test "$ret" != "0"; then
			msg "Error: Starting bme failed, please reboot your device"
			return 1
		fi
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

mce () {
	if ! grep -q '^PatternBoost=' /etc/mce/mce.ini || ! grep '^LEDPatterns=' /etc/mce/mce.ini | grep -q PatternBoost; then
		if ! dpkg -l mceledpattern | grep -q '^ii'; then
			msg "Error: You need to install package mceledpattern from Maemo Extras repository"
			return 1
		fi
		msg "Stopping mce and adding PatternBoost"
		stop -q mce
		mceledpattern add 'PatternBoost' '35;5;0;b;9d804000043fc0000000;9d800000'
	fi
	if ! pidof mce 1>/dev/null 2>&1; then
		msg "Starting mce"
		start -q mce
		if test "$?" != "0"; then
			msg "Error: Starting mce failed, please reboot your device"
			return 1
		fi
	fi
	return 0
}

check () {
	mce || return 1
	if ! test -f /sys/devices/platform/musb_hdrc/hostdevice; then
		msg "Error: You need to install kernel with new usb host mode support (e.g. kernel-power >= 51)"
		return 1
	fi
	if ! test -f /lib/modules/$(uname -r)/bq2415x_charger.ko; then
		msg "Error: You need to install kernel with charger module (e.g. kernel-power >= 51)"
		return 1
	fi
	if ! test -f /lib/modules/$(uname -r)/bq27x00_battery.ko; then
		msg "Error: You need to install kernel with battery module (e.g. kernel-power >= 51)"
		return 1
	fi
	if ! dpkg --compare-versions "$(dpkg-query -W -f \${Version} ke-recv)" ge "3.19-14"; then
		msg "Error: You need to update your Maemo 5 system to last Community SSU version"
		return 1
	fi
	return 0
}


mce_boost () {
	if test "$1" = "1"; then
		action=activate
	else
		action=deactivate
	fi
	dbus --system com.nokia.mce /com/nokia/mce/request com.nokia.mce.request.req_led_pattern_$action string:PatternBoost
}

charger_mode () {
	if test -z "$1"; then
		cat /sys/class/power_supply/bq24150-0/mode
	else
		echo "$1" > /sys/class/power_supply/bq24150-0/mode
		if test "$1" = "boost"; then
			mce_boost 1
		else
			mce_boost 0
		fi
	fi
}

usb_mode () {
	if test -z "$1"; then
		cat /sys/devices/platform/musb_hdrc/mode
	else
		echo "$1" > /sys/devices/platform/musb_hdrc/mode
	fi
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
		sleep 1
	fi

	charger_mode none
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
		sleep 1
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

if ! check; then
	exit 1
fi

if test "$1" = "check"; then
	if charger_mode 2>/dev/null | grep -q boost; then
		charger="boost"
	else
		charger="charging"
	fi
	if usb_mode 2>/dev/null | grep -q host; then
		usb="host"
	else
		usb="peripheral"
	fi
	msg "Current usb mode is $usb with $charger"
elif test "$1" = "peripheral"; then
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
	msg "Script '$0' called without valid option. Valid are: check peripheral host hostc"
	exit 1
fi

exit 0
