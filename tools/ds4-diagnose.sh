#!/system/bin/sh
[ "$(id -u)" = 0 ] || { echo 'Run with su -c sh /path/to/ds4-diagnose.sh'; exit 1; }
out=/sdcard/Download/ds4-begonia.log
{
  date
  for property in ro.product.device ro.build.version.release ro.build.version.incremental bluetooth.device.class_of_device; do
    echo "$property=$(getprop "$property")"
  done
  cat /system/etc/bluetooth/bt_did.conf
  dumpsys package com.blugaemand.ds4begonia | grep -E 'versionCode|versionName'
  cat /data/adb/modules/blugaemand_ds4_did/module.prop
  logcat -d -v threadtime -t 18000 Blugaemand:V bt_sdp:V BluetoothHidDeviceServiceJni:V HidDeviceService:V BluetoothBondStateMachine:V BluetoothAdapter:W bt_btm:V bt_btm_sec:V bt_btif_dm:V bt_btif:V bt_l2cap:V AndroidRuntime:E '*:S'
} > "$out" 2>&1
chmod 644 "$out"
echo "$out"
