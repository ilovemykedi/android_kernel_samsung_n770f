SKIPUNZIP=0
case "$(getprop ro.bootloader)" in
	N770F*) ;;
	*) abort "! Galaxy Note10 Lite (SM-N770F) only: the sensor position is device specific" ;;
esac
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
ui_print "- Optical in-display fingerprint at 540,2169 (r100)"
ui_print "- Reboot, then open the module's Action for a report"
ui_print "  (/data/adb/n770f_fod_fixer/report.txt)"
