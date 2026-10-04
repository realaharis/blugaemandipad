SKIPUNZIP=0
[ "$BOOTMODE" = true ] || abort "Install from the Magisk app."
[ "$(getprop ro.product.device)" = begonia ] || abort "This module requires begonia."
[ "$(getprop ro.build.version.sdk)" = 30 ] || abort "This module requires Android 11 (SDK 30)."
[ -f /system/etc/bluetooth/bt_did.conf ] || abort "Expected Bluetooth DID config missing."
for module in /data/adb/modules/*; do
  [ "${module##*/}" = blugaemand_ds4_did ] && continue
  [ -f "$module/disable" ] && continue
  [ -f "$module/remove" ] && continue
  if [ -f "$module/system/etc/bluetooth/bt_did.conf" ] || [ -f "$module/system/vendor/etc/bluetooth/bt_did.conf" ]; then
    abort "Disable the other Bluetooth DID module and reboot first."
  fi
done
set_perm_recursive "$MODPATH" 0 0 0755 0644
ui_print "Install Blugaemand DS4, then reboot and pair again."
ui_print "Rollback: disable this module in Magisk and reboot."
