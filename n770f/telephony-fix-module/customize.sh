SKIPUNZIP=0
# Built for one ColorOS port build; the replaced files are patched copies of that build's files.
case "$(getprop ro.bootloader)" in
	N770F*) ;;
	*) abort "! Galaxy Note10 Lite (SM-N770F) only" ;;
esac

ui_print "- N770F ColorOS telephony + setup fix"
ui_print "  * framework.jar  : phone no longer crashes after the modem registers"
ui_print "  * TeleService    : incoming calls show on Exynos"
ui_print "  * services.jar   : no soft reboot at setup (colour mode 303)"
ui_print "  * Qualcomm IMS   : removed (it cannot run on Exynos)"
ui_print "  * APN database  : LTE attach APNs fixed (LTE + mobile data)"

# The patched files must match the ROM build they were made from.
chk() { # path expected-sha256 label
	if [ -f "$1" ]; then
		s=$(sha256sum "$1" 2>/dev/null | cut -d' ' -f1)
		[ "$s" = "$2" ] || ui_print "  ! $3 differs from the build this module was made for"
	fi
}
chk /system/framework/framework.jar 6861d8d7222a398f851e36497ba7f3f9eeb66b6751e5b9933ea1324a578ec09e framework.jar
chk /system/framework/services.jar e526d59c205f7a7694afae0aa58921d231b661408fdaa81b0d972bbbe263f413 services.jar
chk /system/system_ext/priv-app/TeleService/TeleService.apk 720fd1fbc3c409ffa750a6d60e68400f80d18931f75b9d553b79d50846e9490a TeleService.apk
ui_print "    (a mismatch is only a warning: it can also mean another module already replaces the file)"

if [ -d /data/adb/modules/n10l_coloros_aio ] && [ -f /data/adb/modules/n10l_coloros_aio/system/framework/framework.jar ]; then
	ui_print "  ! n10l_coloros_aio also replaces framework.jar; its copy may win and bring the"
	ui_print "    phone crash back. Disable that module's framework.jar or the module."
fi

# Hide the Qualcomm IMS app and the old jar's fs-verity metadata (nothing is deleted from system).
REMOVE="
/system/system_ext/priv-app/ims
/system/framework/framework.jar.fsv_meta
"

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
ui_print "- First boot after installing is slower (framework is recompiled)."
ui_print "- Reboot. About 15 s after boot the APNs are reset once to the fixed list"
ui_print "  (log: /data/adb/n770f_telephony_fix.log)."
ui_print "- VoLTE is not included."
