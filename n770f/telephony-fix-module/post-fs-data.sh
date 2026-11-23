#!/system/bin/sh
# KernelSU cannot overlay /my_product, so bind-mount the fixed APN database over ColorOS's copy
# before the phone app starts. Fixes the empty LTE attach APNs (e.g. Vodafone DE "VDF IA").
MODDIR=${0%/*}
T=/my_product/etc/apns-conf.xml
if [ -f "$MODDIR/apns-conf.xml" ] && [ -f "$T" ]; then
	chcon u:object_r:system_file:s0 "$MODDIR/apns-conf.xml" 2>/dev/null
	chmod 0644 "$MODDIR/apns-conf.xml"
	mount -o bind "$MODDIR/apns-conf.xml" "$T"
fi
