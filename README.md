# usb_serial_for_android

A Flutter plugin for talking to USB serial devices from an Android phone or
tablet over USB OTG: Arduino, ESP32, Raspberry Pi Pico, and USB-to-serial
adapters (CH340, CP210x, FTDI, PL2303). It is Android only and uses
[mik3y/usb-serial-for-android](https://github.com/mik3y/usb-serial-for-android)
for the USB drivers.

This is a maintained fork of
[Eyanef/usb_serial_for_android](https://github.com/Eyanef/usb_serial_for_android),
which has not been updated since 2022 and no longer builds with current
Flutter and Android tooling.

## What this fork fixes

- **Builds with current Flutter.** The plugin declares an Android
  `namespace`, so apps using Android Gradle Plugin 8 or newer no longer fail
  with *"Namespace not specified"*.
- **USB permission request fixed for Android 12+ and 14+.** Before, asking
  for permission from `create()` threw an exception on these versions.
- **`create()` is safer.** It no longer crashes with *"Reply already
  submitted"* for an unknown driver type or an unsupported device. It checks
  the port number and gives a clear error, and it no longer leaks a USB
  connection on every call.
- **Web builds work again.** An unused `dart:ffi` import broke compiling any
  app that depends on the package for the web
  ([#2](https://github.com/Eyanef/usb_serial_for_android/issues/2)).
- **The example no longer assumes one adapter.** It used to hardcode the
  CP210x driver and port 4, the likely reason Connect did nothing
  ([#1](https://github.com/Eyanef/usb_serial_for_android/issues/1)). It is
  now a small serial terminal with a matching Arduino sketch.
- usb-serial-for-android 3.4.6 → 3.11.0, Dart 3 support, documentation for
  `connect()` (nothing is received without it), and tests.

It also includes the 0.0.6–0.0.9 changes that were published to pub.dev but
never pushed to GitHub. See [CHANGELOG.md](CHANGELOG.md) for details.

## Requirements

- An Android device with USB host (OTG) support, an OTG adapter, and a USB
  **data** cable.
- Your app must compile against Android API 35 or newer (`compileSdk`).
  Recent Flutter templates already do this with `flutter.compileSdkVersion`.

## Install

Add the package to your app's `pubspec.yaml`:

```yaml
dependencies:
  usb_serial_for_android:
    git:
      url: https://github.com/AhmedMannai10/usb_serial_for_android.git
      ref: v0.1.0
```

Then run `flutter pub get`.

## Android setup

### 1. `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- The app needs a USB host port (USB OTG). -->
    <uses-feature android:name="android.hardware.usb.host" />

    <application ...>
        <activity android:name=".MainActivity" ...>
            <!-- ... the existing MAIN/LAUNCHER intent-filter ... -->

            <!-- Offer to open the app when a known board is plugged in. -->
            <intent-filter>
                <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
            </intent-filter>
            <meta-data
                android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"
                android:resource="@xml/device_filter" />
        </activity>
    </application>
</manifest>
```

- `uses-feature` is required by default, so Google Play only offers the app
  to devices with USB host support. Add `android:required="false"` if the app
  should also install on devices without it.
- The `USB_DEVICE_ATTACHED` intent-filter is optional. Without it, `create()`
  asks for permission with a system dialog. With it, Android offers to open
  your app when a matching board is plugged in, and accepting also grants USB
  permission for that board.

### 2. `android/app/src/main/res/xml/device_filter.xml`

This file lists the boards that trigger the intent-filter above. Create the
`xml` folder if it does not exist.

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <usb-device vendor-id="9025" />  <!-- Arduino -->
    <usb-device vendor-id="6790" />  <!-- QinHeng CH340/CH341 -->
    <usb-device vendor-id="4292" />  <!-- Silicon Labs CP210x -->
    <usb-device vendor-id="1027" />  <!-- FTDI -->
    <usb-device vendor-id="1659" />  <!-- Prolific PL2303 -->
    <usb-device vendor-id="12346" /> <!-- Espressif native USB -->
    <usb-device vendor-id="11914" /> <!-- Raspberry Pi RP2040 -->
</resources>
```

| Chip / board | Vendor ID (hex) | `vendor-id` (decimal) |
| --- | --- | --- |
| Arduino (Uno, Mega, Leonardo, ...) | `0x2341` | `9025` |
| QinHeng CH340 / CH341 (Nano clones, many ESP32 and ESP8266 boards) | `0x1A86` | `6790` |
| Silicon Labs CP210x (many ESP32 dev boards) | `0x10C4` | `4292` |
| FTDI (FT232 adapters) | `0x0403` | `1027` |
| Prolific PL2303 | `0x067B` | `1659` |
| Espressif native USB (ESP32-S2, S3, C3) | `0x303A` | `12346` |
| Raspberry Pi RP2040 (Pico) | `0x2E8A` | `11914` |

Write `vendor-id` in decimal, or in hex with a `0x` prefix (`"0x2341"`). A
bare `"2341"` is read as the decimal number 2341 and will not match your
board. To find your board's vendor ID, print the result of
`await UsbSerial.listDevices()`: each `UsbDevice` has a `vid`.

## Usage

This is the same flow as the [example app](example/lib/main.dart):

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:usb_serial_for_android/transaction.dart';
import 'package:usb_serial_for_android/usb_device.dart';
import 'package:usb_serial_for_android/usb_port.dart';
import 'package:usb_serial_for_android/usb_serial_for_android.dart';

Future<UsbPort?> connectToBoard() async {
  // 1. Find the board.
  final List<UsbDevice> devices = await UsbSerial.listDevices();
  if (devices.isEmpty) return null;

  // 2. Create a port. The driver is detected automatically; if your board is
  //    not recognised, pass a type such as UsbSerial.CDC. Android shows the
  //    USB permission dialog here if needed.
  final UsbPort? port = await devices.first.create();
  if (port == null) return null;

  // 3. Open it with the same settings as Serial.begin(...) on the board.
  if (!await port.open()) return null;
  await port.setPortParameters(
    115200,
    UsbPort.DATABITS_8,
    UsbPort.STOPBITS_1,
    UsbPort.PARITY_NONE,
  );

  // 4. Split the incoming bytes into lines and start listening...
  final Transaction<String> lines = Transaction.stringTerminated(
    port.inputStream!,
    Uint8List.fromList([10]), // '\n'
  );
  lines.stream.listen((String line) => debugPrint('board: ${line.trim()}'));

  // 5. ...then start the read loop. Nothing arrives without connect().
  await port.connect();

  // 6. Raise DTR and RTS. Boards with native USB only send once DTR is on.
  await port.setDTR(true);
  await port.setRTS(true);

  // 7. Send a message. End it with '\n' so the board knows where it stops.
  await port.write(Uint8List.fromList(utf8.encode('LED ON\n')));
  return port;
}
```

Notes:

- `create()` throws a `PlatformException` if permission is denied, no driver
  matches the device, or the port number is out of range. Wrap the code above
  in `try` / `on PlatformException`.
- Devices with several serial ports (for example FT2232) take a port number:
  `device.create(null, 1)`. The default is port 0.
- `UsbSerial.usbEventStream` reports boards being plugged in and unplugged.
  `UsbEvent.ACTION_USB_ATTACHED` and `UsbEvent.ACTION_USB_DETACHED` tell
  them apart.
- When you are done, cancel your subscription, call `lines.dispose()`, and
  then `await port.close()`.

## Troubleshooting

**No device is found.**
- Many USB cables only carry power. Use one that you know transfers data.
- Check the OTG adapter. Some phones also have an **OTG switch in
  Settings** that must be turned on; on some models it turns itself off
  again after a few minutes without use.
- Make sure the device supports USB host. Native Android code can check
  `packageManager.hasSystemFeature(PackageManager.FEATURE_USB_HOST)`. The
  `uses-feature` entry above keeps Google Play from installing the app on
  devices without it.

**Data looks like garbage.** The baud rate in `setPortParameters(...)` must
match `Serial.begin(...)` in the sketch.

**`open()` works but nothing arrives.**
- Did you call `connect()`? It starts the read loop. Listen to
  `inputStream` (or a `Transaction`) first, then call `connect()`. Data that
  arrives while nobody is listening is dropped.
- Boards with native USB (Arduino Leonardo or Micro, and many ESP32-S2/S3
  and RP2040 setups) may only send data once DTR is set. Call
  `setDTR(true)` after `connect()`.

**The board restarts when the app connects.** On many boards (Uno, Nano,
ESP32 dev boards with auto-reset), changing DTR/RTS resets the
microcontroller. This is how the Arduino IDE uploads sketches. Wait a moment
before sending (the example waits 1.5 s), and expect the sketch's startup
output. If the board keeps resetting or stops responding, try setting only
DTR and leaving RTS alone.

**Permission.**
- `create()` throws `Failed to acquire permission` if the user taps Deny.
  Call it again to ask again.
- Permission granted from the dialog only lasts until the board is
  unplugged. With the `device_filter.xml` setup, Android asks when the board
  is plugged in instead.
- *"Targeting S+ (version 31 and above) requires that one of FLAG_IMMUTABLE
  or FLAG_MUTABLE be specified"* means you are still on the old plugin
  (0.0.9 or earlier). Use the git dependency above.

**Build errors.**
- *"Namespace not specified"*: you are using the old plugin. Use the git
  dependency above.
- An error saying a dependency requires compiling against version 35 or
  later of the Android APIs: set `compileSdk` to 35 or newer in
  `android/app/build.gradle(.kts)`.
- *"Could not find com.github.mik3y:usb-serial-for-android"*: the plugin
  adds the JitPack repository to your project. If your Gradle settings
  declare repositories centrally (`dependencyResolutionManagement`), add
  `maven { url = uri("https://jitpack.io") }` there.

## Example

[`example/`](example) contains a minimal serial terminal and
[`example/arduino/serial_echo/serial_echo.ino`](example/arduino/serial_echo/serial_echo.ino),
a sketch that echoes lines and switches the built-in LED on `LED ON` and
`LED OFF`.

## Credits

- [Eyanef](https://github.com/Eyanef/usb_serial_for_android): the original
  plugin.
- [mik3y/usb-serial-for-android](https://github.com/mik3y/usb-serial-for-android):
  the Android USB serial drivers this plugin wraps.
- [altera2015/usbserial](https://github.com/altera2015/usbserial): the
  `usb_serial` Flutter plugin that this package's Dart API, `Transaction`
  and transformers are modelled on.

## License

LGPL-3.0, the same as the original project. See [LICENSE](LICENSE).
