#!/system/bin/sh
MODDIR=${0%/*}
. $MODDIR/common.sh
# persist.* values stored in /data/property win over system.prop: force them.
enforce_persist
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
# Samsung fingerprint HAL is class late_start; make sure it runs.
[ "$(getprop init.svc.vendor.fps_hal)" = running ] || { start vendor.fps_hal; log "started vendor.fps_hal"; }
# FOD mask layer brightness (HBM top) used by the patched Samsung HWC.
n=/sys/class/lcd/panel/mask_brightness
[ -w $n ] && [ "$(cat $n)" != 365 ] && echo 365 > $n
sleep 10
report > /dev/null
log "report in $OUT/report.txt"
