#!/system/bin/sh
MODDIR=${0%/*}
chcon u:object_r:system_file:s0 "$MODDIR/system/product/overlay/N770F-AOD-Overlay.apk" 2>/dev/null
chmod 0644 "$MODDIR/system/product/overlay/N770F-AOD-Overlay.apk"
# idmaps regenerated as root cannot be parsed or replaced by idmap2d (system):
# the display overlays then stay in STATE_NO_IDMAP. Drop them so they are rebuilt.
for f in /data/resource-cache/product@overlay@android_framework_res_overlay.display.product.23821.apk@idmap \
         /data/resource-cache/product@overlay@oplus_framework_res_overlay.display.product.23821.apk@idmap; do
	[ -f "$f" ] || continue
	[ "$(stat -c %U "$f")" = root ] && rm -f "$f" && echo "n770f_aod_fix: removed stale $f" > /dev/kmsg
done
