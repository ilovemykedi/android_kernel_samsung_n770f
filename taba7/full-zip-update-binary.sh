#!/sbin/sh
# Tab A7 10.4 (SM-T500/T505, gta4l) - ColorOS 13 port, full image installer
# Writes boot, dtbo and the super partition (layout + system/vendor/product/odm).
OUTFD=$2; ZIP=$3
ui() { echo "ui_print $1" > /proc/self/fd/$OUTFD; echo "ui_print" > /proc/self/fd/$OUTFD; }
abort() { ui "! $1"; exit 1; }
SUPER=/dev/block/by-name/super
ui "=========================================="
ui " ColorOS 13 for Galaxy Tab A7 (gta4l)"
ui " boot + dtbo + super (system/vendor/product/odm)"
ui " Data encryption: DISABLED"
ui "=========================================="
[ -e $SUPER ] || abort "no super partition - wrong device?"
[ "$(blockdev --getsize64 $SUPER)" = "5729419264" ] || abort "super size mismatch - this zip is for gta4l only"
unzip -p "$ZIP" md5.txt > /tmp/c13_md5.txt && unzip -p "$ZIP" sizes.txt > /tmp/c13_sizes.txt || abort "cannot read zip"
md5of() { grep " $1\$" /tmp/c13_md5.txt | cut -d' ' -f1; }
for m in /system_root /system /vendor /product /odm; do umount $m 2>/dev/null; done
# write FILE DEVICE BYTE_OFFSET
wr() {
  sz=$(grep " $1\$" /tmp/c13_sizes.txt | cut -d' ' -f1)
  want=$(md5of $1)
  for try in 1 2 3; do
    ui "- writing $1 (try $try)"
    unzip -p "$ZIP" "images/$1" | dd of=$2 bs=1048576 seek=$3 oflag=seek_bytes conv=notrunc 2>/tmp/c13_dd.log
    sync
    got=$(dd if=$2 bs=1048576 skip=$3 count=$sz iflag=skip_bytes,count_bytes 2>/dev/null | md5sum | cut -d' ' -f1)
    [ "$got" = "$want" ] && return 0
    ui "  mismatch ($got) - $(tail -n 1 /tmp/c13_dd.log)"
  done
  abort "write failed: $1"
}
wr boot.img /dev/block/by-name/boot 0
wr dtbo.img /dev/block/by-name/dtbo 0
ui "- writing super partition layout"
wr super_head.bin $SUPER 0
wr system.part1.img $SUPER 1048576
wr system.part2.img $SUPER 3080716288
wr vendor.img $SUPER 1270624256
wr product.img $SUPER 1925304320
wr odm.img $SUPER 3079045120
ui "- resetting metadata (old encryption keys)"
umount /metadata 2>/dev/null
mke2fs -t ext4 -F -q /dev/block/by-name/metadata || ui "  (metadata format failed - format it in TWRP)"
rm -f /tmp/c13_md5.txt /tmp/c13_sizes.txt; sync
ui "=========================================="
ui " Done."
ui " If /data was encrypted (any other ROM, or this"
ui " port before): Wipe > Format Data > type yes,"
ui " then Reboot > Recovery once, then System."
ui "=========================================="
exit 0
