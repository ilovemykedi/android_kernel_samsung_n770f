#!/system/bin/sh
MODDIR=${0%/*}
# Kernel v19+: the touch driver's AOSP helpers are opt-in (off = stock One UI
# behaviour). follow_display: touch LPM on screen off/doze (DT2W, screen-off
# FOD); fod_lpm_wakeup: a FOD press with the screen off wakes it.
P=/sys/module/melfas_mss100/parameters
[ -w $P/follow_display ] && echo 1 > $P/follow_display
[ -w $P/fod_lpm_wakeup ] && echo 1 > $P/fod_lpm_wakeup

# Stand-in for OnePlus' vendor.oplus.hardware.displaypanelfeature HAL: ColorOS
# SystemUI only enables the AOD <-> lock screen transition when it answers.
# Start it before SystemUI asks; SystemUI also re-checks later.
# feature 217 = 0x3: smooth transition + enter AOD directly in doze
CLASSPATH="$MODDIR/n770f-dpf.dex" setsid nohup app_process /system/bin com.n770f.dpf.Main 0x3 </dev/null >/dev/null 2>&1 &

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
# AOSP side of always-on display (ColorOS keeps its own Setting_AodEnable)
settings put secure doze_always_on 1
# Arm the panel's low-power AOD (HLPM). One UI's AOD service writes this
# before dozing; ColorOS does not know the node. ver=1 (bits 16-23) with
# AOD_MODE_HLPM (2): the s6e3fa9 driver enters HLPM (2/10/30/60 nit from
# the doze brightness) on every DOZE and leaves it on display on.
[ -w /sys/class/lcd/panel/alpm ] && echo 0x10002 > /sys/class/lcd/panel/alpm
# Double tap to wake: arm the Melfas "always on touch" gesture. The v17+
# kernel puts the touch IC into LPM on screen off / doze, where a double tap
# reports KEY_WAKEUP.
[ -w /sys/class/sec/tsp/cmd ] && echo aot_enable,1 > /sys/class/sec/tsp/cmd
# Screen-off FOD: let the touch IC report presses on the sensor in LPM.
# The v18+ kernel turns such a press into KEY_WAKEUP, the panel lights up
# and ColorOS' lock screen FOD flow runs with the finger still in place.
loc=$(getprop ro.vendor.fingerprint.sensor_location)   # x|y|radius
x=${loc%%|*}; r=${loc##*|}; y=${loc#*|}; y=${y%%|*}
if [ -w /sys/class/sec/tsp/cmd ] && [ -n "$x" ] && [ -n "$y" ] && [ -n "$r" ]; then
	echo fod_lp_mode,1 > /sys/class/sec/tsp/cmd
	echo fod_enable,1,1 > /sys/class/sec/tsp/cmd
	echo set_fod_rect,$((x - r)),$((y - r)),$((x + r)),$((y + r)) > /sys/class/sec/tsp/cmd
fi
