#!/system/bin/sh
# Start TrebleDroid's system-side Bluetooth audio HAL (sysbta). KernelSU
# mounts module files after init has parsed /system/etc/init, so an .rc file
# would never be seen; start it here instead, before audioserver loads its
# HAL modules and long before Bluetooth is enabled (the BT stack only looks
# for the provider when it starts).
# LD_PRELOAD shim: register the AIDL provider as ".../default", the instance
# the unpatched AOSP Bluetooth stack looks up.
LD_PRELOAD=/system/lib64/libsysbta_shim.so setsid \
	/system/bin/hw/android.hardware.bluetooth.audio-service-system \
	</dev/null >/dev/null 2>&1 &
