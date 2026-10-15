# usb_serial_for_android example

A minimal USB serial terminal for Android. It connects to the first USB
device it finds, shows every line the device sends, and lets you send text
or the `LED ON` / `LED OFF` commands.

## Try it with a board

1. Flash [`arduino/serial_echo/serial_echo.ino`](arduino/serial_echo/serial_echo.ino)
   to any Arduino-compatible board (Uno, Nano, ESP32, Pico, ...). It runs at
   115200 baud, echoes every line back and switches the built-in LED on
   `LED ON` / `LED OFF`.
2. Run the app on an Android phone: `flutter run`.
3. Plug the board into the phone with a USB OTG adapter and a data cable.
   Accept the USB permission dialog.

The app connects on start and whenever a board is plugged in; you can also
use the **Connect** button. `android/app/src/main/res/xml/device_filter.xml`
lists the USB vendor IDs that make Android offer to open the app when a board
is plugged in.

See the [package README](../README.md) for setup and troubleshooting.
