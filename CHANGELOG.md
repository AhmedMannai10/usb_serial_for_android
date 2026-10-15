## 0.0.1

- Initial release

## 0.0.2

- Add documentation and fix port issues

## 0.0.3

- Fix control exceptions

## 0.0.4

- Fix more control exceptions

## 0.0.5

- Fix onError exception.

## 0.0.6

- Fix onError exception.

## 0.1.0

First release of the fork at
https://github.com/AhmedMannai10/usb_serial_for_android. It starts from the
0.0.9 release on pub.dev, because the upstream GitHub repository stopped at
0.0.5.

Build
- Android: declare `namespace` so the plugin builds with Android Gradle
  Plugin 8 and newer (fixes "Namespace not specified"). Remove the ignored
  `package` attribute from the plugin's AndroidManifest.xml.
- Android: update com.github.mik3y:usb-serial-for-android 3.4.6 -> 3.11.0
  and compileSdk 31 -> 35. Apps must compile against API 35 or newer.
- Dart SDK constraint `>=2.18.1 <4.0.0` (Dart 3).

Fixes
- Android 12+: the USB permission request no longer throws. Its
  PendingIntent is FLAG_MUTABLE.
- Android 14+: the permission PendingIntent wraps an explicit intent
  (setPackage). Both broadcast receivers are registered with
  RECEIVER_NOT_EXPORTED on API 33+.
- Permission counts as granted if EXTRA_PERMISSION_GRANTED is true or
  UsbManager.hasPermission(device) returns true.
- Use the typed getParcelableExtra on API 34+.
- create(): reply exactly once on every path. An unknown type or a device
  without a driver no longer causes a "Reply already submitted" crash.
- create(): check portNum against the device's ports and report
  "Invalid portNum N: the device has M serial port(s)" instead of throwing
  IndexOutOfBoundsException.
- create(): close the USB connection used as a permission probe; one
  connection leaked per call. Clearer errors when the device cannot be
  opened.
- Remove the unused `dart:ffi` import that broke web builds (upstream #2).

Docs
- Fix the `inputStream` example (open -> setPortParameters -> listen ->
  connect) and document that `connect()` starts the read loop.
- Rewrite the README as a setup guide: install, Android manifest and
  device_filter.xml, usage, troubleshooting, credits.

Example
- New example app: a minimal serial terminal plus an Arduino echo sketch
  (`example/arduino/serial_echo`), with an Android project regenerated for
  current Flutter, a USB_DEVICE_ATTACHED intent-filter and
  device_filter.xml. It replaces the hardcoded
  `create(UsbSerial.CP21xx, 4)`, the likely cause of upstream #1.

Tests
- Add tests for line splitting in TerminatedStringTransformer.
