#!/sbin/sh
# Galaxy Note10 Lite (SM-N770F) - ColorOS port, full installer
# system (EROFS) + vendor + product into the dynamic partitions, then the kernel via AnyKernel3.
OUTFD=$2; ZIP=$3
ui() { echo "ui_print $1" > /proc/self/fd/$OUTFD; echo "ui_print" > /proc/self/fd/$OUTFD; }
abort() { ui "! $1"; exit 1; }
T=/tmp/n770f_rom; rm -rf $T; mkdir -p $T
ui "=========================================="
ui " ColorOS for Galaxy Note10 Lite (SM-N770F)"
ui " system + vendor + product + kernel (AK3)"
ui "=========================================="
case "$(getprop ro.bootloader)$(getprop ro.product.device)" in
	*N770F*|*r7*) ;;
	*) abort "this zip is for the Galaxy Note10 Lite (SM-N770F) only" ;;
esac
unzip -p "$ZIP" md5.txt > $T/md5.txt && unzip -p "$ZIP" sizes.txt > $T/sizes.txt || abort "cannot read zip"
md5of() { grep " $1\$" $T/md5.txt | cut -d' ' -f1; }
sizeof() { grep " $1\$" $T/sizes.txt | cut -d' ' -f1; }
lt() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a+0 < b+0)}'; }   # 64-bit safe compare
for m in /system_root /system /vendor /product /odm; do umount $m 2>/dev/null; done

# lptools from the bundled AnyKernel3 zip (used only if a partition is too small)
unzip -p "$ZIP" images/kernel-ak3.zip > $T/ak3.zip || abort "kernel zip missing"
unzip -o -q $T/ak3.zip tools/lptools_static -d $T && chmod 755 $T/tools/lptools_static
LPT=$T/tools/lptools_static

# ensure PART is at least NEED bytes
fit() {
	dev=/dev/block/mapper/$1
	[ -e $dev ] || abort "no /dev/block/mapper/$1 - reboot to recovery and retry"
	cur=$(blockdev --getsize64 $dev)
	if lt "$cur" "$2"; then
		ui "- $1 is $cur bytes, needs $2: resizing"
		$LPT unmap $1 >/dev/null 2>&1
		$LPT resize $1 $2 || abort "cannot resize $1 (not enough free space in super)"
		$LPT map $1 >/dev/null 2>&1
		sleep 1; [ -e $dev ] || abort "$1 did not map back after resize"
		cur=$(blockdev --getsize64 $dev); lt "$cur" "$2" && abort "$1 still too small after resize"
	fi
}
# write FILE DEVICE BYTE_OFFSET (offsets are literal: the shell is 32-bit)
wr() {
	sz=$(sizeof $1); want=$(md5of $1)
	for try in 1 2 3; do
		ui "- writing $1 (try $try)"
		unzip -p "$ZIP" "images/$1" | dd of=$2 bs=1048576 seek=$3 oflag=seek_bytes conv=notrunc 2>$T/dd.log
		sync
		got=$(dd if=$2 bs=1048576 skip=$3 count=$sz iflag=skip_bytes,count_bytes 2>/dev/null | md5sum | cut -d' ' -f1)
		[ "$got" = "$want" ] && return 0
		ui "  mismatch ($got) - $(tail -n 1 $T/dd.log)"
	done
	abort "write failed: $1"
}

fit system 5128187904
fit vendor 1161920512
fit product 846905344
wr system.part1.img /dev/block/mapper/system 0
wr system.part2.img /dev/block/mapper/system 1709395968
wr system.part3.img /dev/block/mapper/system 3418791936
wr vendor.img /dev/block/mapper/vendor 0
wr product.img /dev/block/mapper/product 0

ui "- flashing kernel (AnyKernel3)"
unzip -o -q $T/ak3.zip META-INF/com/google/android/update-binary -d $T/ak3bin || abort "AK3 installer missing"
sh $T/ak3bin/META-INF/com/google/android/update-binary 3 "$OUTFD" $T/ak3.zip || abort "kernel flash failed"

rm -rf $T; sync
ui "=========================================="
ui " Done. Coming from another ROM or an older"
ui " build: Wipe > Format Data > yes, then boot."
ui " Needs KernelSU only for optional modules."
ui "=========================================="
exit 0
