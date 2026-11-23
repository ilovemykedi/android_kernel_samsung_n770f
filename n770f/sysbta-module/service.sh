#!/system/bin/sh
# Safety net: if sysbta was not running when the system came up, start it and
# restart Bluetooth so the stack picks up the provider.
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
if ! pidof android.hardware.bluetooth.audio-service-system >/dev/null; then
	LD_PRELOAD=/system/lib64/libsysbta_shim.so setsid \
		/system/bin/hw/android.hardware.bluetooth.audio-service-system \
		</dev/null >/dev/null 2>&1 &
	sleep 3
	if [ "$(settings get global bluetooth_on)" = 1 ]; then
		cmd bluetooth_manager disable; sleep 3; cmd bluetooth_manager enable
	fi
fi
