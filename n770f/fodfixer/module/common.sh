# shared by service.sh / action.sh
FOD_TYPE=udfps_optical
FOD_LOC='540|2169|100'
OUT=/data/adb/n770f_fod_fixer
log() { echo "n770f_fod_fixer: $*" > /dev/kmsg; }

enforce_persist() {
	for kv in persist.vendor.fingerprint.sensor_type=optical \
		  persist.vendor.fingerprint.optical.iconlocation=308 \
		  persist.vendor.fingerprint.optical.iconsize=267 \
		  persist.vendor.fingerprint.optical.iconnumber=0; do
		k=${kv%%=*}; v=${kv#*=}
		[ "$(getprop $k)" = "$v" ] || { setprop $k "$v"; log "set $k=$v"; }
	done
}

mark() { if [ "$2" = "$3" ]; then echo "  OK    $1 = $2"; else echo "  FIX   $1 = '$2' (want '$3')"; fi; }

report() {
	mkdir -p $OUT
	{
	echo "N770F FOD fixer report - $(date)"
	echo "device: $(getprop ro.bootloader)  rom: $(getprop ro.build.display.id)"
	echo
	echo "[props]"
	mark ro.vendor.fingerprint.type "$(getprop ro.vendor.fingerprint.type)" $FOD_TYPE
	mark ro.vendor.fingerprint.sensor_location "$(getprop ro.vendor.fingerprint.sensor_location)" "$FOD_LOC"
	mark ro.vendor.fingerprint.request_touch_event "$(getprop ro.vendor.fingerprint.request_touch_event)" true
	mark persist.vendor.fingerprint.sensor_type "$(getprop persist.vendor.fingerprint.sensor_type)" optical
	mark persist.vendor.fingerprint.optical.iconlocation "$(getprop persist.vendor.fingerprint.optical.iconlocation)" 308
	mark persist.vendor.fingerprint.optical.iconsize "$(getprop persist.vendor.fingerprint.optical.iconsize)" 267
	echo
	echo "[framework]"
	o=$(cmd overlay list android 2>/dev/null | grep com.n770f.overlay.fod)
	case "$o" in *"[x]"*) echo "  OK    udfps overlay enabled";; "") echo "  FIX   udfps overlay not listed (product overlay not mounted?)";; *) echo "  FIX   udfps overlay present but not enabled: $o";; esac
	t=$(dumpsys fingerprint 2>/dev/null | grep -io -m1 'sensorType[^,}]*')
	echo "  INFO  dumpsys fingerprint: ${t:-no sensorType line (enroll screen still tells: in-display = OK)}"
	for f in android.hardware.fingerprint oppo.hardware.fingerprint.optical.support; do
		pm list features 2>/dev/null | grep -q "feature:$f\$" && echo "  OK    feature $f" || echo "  FIX   feature $f missing"
	done
	j=/system/framework/services.jar
	BB=/data/adb/ksu/bin/busybox; [ -x $BB ] || BB=busybox
	if $BB unzip -l $j 2>/dev/null | grep -q classes; then
		n=$($BB unzip -p $j 2>/dev/null | grep -ac N10lFingerprintCompat)
		[ "${n:-0}" -gt 0 ] && echo "  OK    services.jar has the N770F touch bridge (N10lFingerprintCompat)" \
			|| echo "  WARN  services.jar has no N770F touch bridge: presses may not reach the Samsung HAL (ROM-side fix needed)"
	fi
	echo
	echo "[hardware]"
	echo "  HAL   vendor.fps_hal: $(getprop init.svc.vendor.fps_hal)"
	echo "  sysfs fingerprint position: $(cat /sys/class/fingerprint/fingerprint/position 2>/dev/null || echo n/a)"
	echo "  panel mask_brightness: $(cat /sys/class/lcd/panel/mask_brightness 2>/dev/null || echo n/a) (want 365)"
	echo
	echo "Props/overlay changes apply after a reboot; persist.* light-spot props after SystemUI restarts."
	} > $OUT/report.txt 2>&1
	cat $OUT/report.txt
}
