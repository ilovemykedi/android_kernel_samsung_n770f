#!/system/bin/sh
# N770F ColorOS port: runtime settings that used to live in KernelSU module
# service scripts. Started by /system/etc/init/n770f.rc.
log() { echo "n770f: $*" > /dev/kmsg; }

case "$1" in
early)
	# Optical FOD (Egis ET713 under the panel, Samsung stock fingerprint HAL).
	# The ColorOS framework/SystemUI pick the sensor type and the light spot
	# from these. ro.* only when nothing set them yet; persist.* are enforced
	# because a stale value in /data/property would override build defaults.
	setro() { [ -z "$(getprop $1)" ] && setprop $1 "$2"; }
	setro ro.vendor.fingerprint.type udfps_optical
	setro ro.vendor.fingerprint.sensor_location '540|2169|100'
	setro ro.vendor.fingerprint.request_touch_event true
	setro ro.vendor.fingerprint.screen_off_press_delay 200
	setpersist() { [ "$(getprop $1)" = "$2" ] || setprop $1 "$2"; }
	setpersist persist.vendor.fingerprint.sensor_type optical
	setpersist persist.vendor.fingerprint.optical.iconlocation 308
	setpersist persist.vendor.fingerprint.optical.iconsize 267
	setpersist persist.vendor.fingerprint.optical.iconnumber 0
	log "fod type=$(getprop ro.vendor.fingerprint.type) sensor=$(getprop persist.vendor.fingerprint.sensor_type) loc=$(getprop ro.vendor.fingerprint.sensor_location)"
	# Kernel v19+: the Melfas touch driver's AOSP helpers are opt-in (off =
	# stock One UI behaviour). follow_display: touch LPM on screen off/doze
	# (DT2W, screen-off FOD); fod_lpm_wakeup: a FOD press with the screen off
	# wakes it.
	P=/sys/module/melfas_mss100/parameters
	[ -w $P/follow_display ] && echo 1 > $P/follow_display
	[ -w $P/fod_lpm_wakeup ] && echo 1 > $P/fod_lpm_wakeup
	log "melfas follow_display=$(cat $P/follow_display 2>/dev/null) fod_lpm_wakeup=$(cat $P/fod_lpm_wakeup 2>/dev/null)"
	;;
late)
	# AOSP side of always-on display (ColorOS keeps its own Setting_AodEnable).
	settings put secure doze_always_on 1
	# Panel low-power AOD (HLPM): ver=1 (bits 16-23) with AOD_MODE_HLPM (2).
	# One UI's AOD service writes this; ColorOS does not know the node.
	[ -w /sys/class/lcd/panel/alpm ] && echo 0x10002 > /sys/class/lcd/panel/alpm
	T=/sys/class/sec/tsp/cmd
	# Double tap to wake: Melfas "always on touch" gesture (KEY_WAKEUP in LPM).
	[ -w $T ] && echo aot_enable,1 > $T
	# Screen-off FOD: report presses on the sensor while the IC is in LPM.
	loc=$(getprop ro.vendor.fingerprint.sensor_location)   # x|y|radius
	x=${loc%%|*}; r=${loc##*|}; y=${loc#*|}; y=${y%%|*}
	if [ -w $T ] && [ -n "$x" ] && [ -n "$y" ] && [ -n "$r" ]; then
		echo fod_lp_mode,1 > $T
		echo fod_enable,1,1 > $T
		echo set_fod_rect,$((x - r)),$((y - r)),$((x + r)),$((y + r)) > $T
	fi
	# FOD mask layer brightness (HBM top = 365), used by libexynosdisplay.
	n=/sys/class/lcd/panel/mask_brightness
	i=0
	while [ ! -e $n ] && [ $i -lt 60 ]; do sleep 1; i=$((i + 1)); done
	[ -w $n ] && echo 365 > $n
	# Face unlock HAL: start it if init did not (from the n10l_coloros_aio module).
	FH=/vendor/bin/hw/android.hardware.biometrics.face-service.facehal
	if [ -f $FH ] && [ "$(getprop init.svc.vendor.facehal)" != running ]; then
		start vendor.facehal
		sleep 2
		[ "$(getprop init.svc.vendor.facehal)" = running ] || pidof ${FH##*/} >/dev/null || \
			LD_LIBRARY_PATH=/vendor/lib64 $FH </dev/null >/dev/null 2>&1 &
	fi
	log "late settings applied (fod rect from '$loc')"
	;;
esac
