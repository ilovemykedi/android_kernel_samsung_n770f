#!/system/bin/sh
# ColorOS' TelephonyProvider keeps its cached APN database and only re-reads apns-conf.xml on an
# OTA, so the fixed attach APNs (bind-mounted in post-fs-data.sh) are not used until the APNs are
# reset. Do the same as Settings > APN > Reset once per version of the fixed file.
MODDIR=${0%/*}
LOG=/data/adb/n770f_telephony_fix.log
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 2; done
sleep 15
{
	echo "=== $(date)"
	mount | grep -q " /my_product/etc/apns-conf.xml " && echo "apns-conf bind mount: active" || echo "apns-conf bind mount: MISSING"
	want=$(md5sum "$MODDIR/apns-conf.xml" | cut -d' ' -f1)
	have=$(cat "$MODDIR/.apn_reset_done" 2>/dev/null)
	if [ "$want" != "$have" ]; then
		content delete --uri content://telephony/carriers/restore && echo "APNs reset to the fixed database" && echo "$want" > "$MODDIR/.apn_reset_done"
	else
		echo "APNs already reset for this version"
	fi
	content query --uri content://telephony/carriers --where "type like '%ia%' and current=1" --projection name:apn:type 2>/dev/null | head -5
} >> $LOG 2>&1
