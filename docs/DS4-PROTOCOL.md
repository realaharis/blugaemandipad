# Experimental DS4 gameplay on begonia

This branch targets rooted begonia, Android 11 / MIUI V12.5.8.0.RGGMIXM and an iPad host. Hardware pairing is not yet verified. Original README claims about tested generic controllers do not validate this branch.

The supplied device log reported `SDP attr too big: max_list_len=246,attr_len=454`, followed by SDP error 0x06. The previous 442-byte descriptor plus SDP overhead matches this failure. The compact 115-byte descriptor retains gameplay reports while dropping unimplemented vendor/audio/authentication usages. This addresses the observed descriptor-size failure; it does not prove that iPadOS will accept the device.

Implemented: initial report 0x01, extended Bluetooth report 0x11, seeded CRC32, timestamp and sequence, six motion axes, two touch contacts/click, battery, calibration 0x02/0x05, virtual firmware metadata 0xA3, output rumble/lightbar/flash and explicit successful SET_REPORT handshake. Unsupported feature IDs are rejected. Reports target 100 Hz; Android scheduling and Bluetooth transport determine actual timing. Sensor orientation needs physical validation. Battery is sampled on connection; two motors are approximated with one phone vibrator, with a five-second watchdog.

The stock Android Bluetooth stack still owns SDP, pairing/SSP and transport. No native stack binary patch, USB mode, Sony console authentication, speaker or headset emulation is included. This is not full Sony firmware emulation.

Build: JDK 17, Android platform 36, build tools 36.0.0; run `./gradlew clean :app:assembleDebug :app:testDebugUnitTest :app:lintDebug`. CI verifies the actual packaged application ID `com.blugaemand.ds4begonia`, APK signature and unit tests, then packages the APK, guarded Magisk identity module, Persian guide and diagnostics. CI cannot verify radio pairing or physical sensor orientation.

Protocol references:
- https://github.com/torvalds/linux/blob/master/drivers/hid/hid-playstation.c
- https://android.googlesource.com/platform/system/bt/+/refs/tags/android-11.0.0_r1/stack/sdp/sdp_server.cc
- https://android.googlesource.com/platform/system/bt/+/refs/tags/android-11.0.0_r1/bta/hd/bta_hd_act.cc
- https://developer.android.com/reference/android/bluetooth/BluetoothHidDevice

Magisk installer is from the official Magisk project; its GPL license is included in the module archive.
