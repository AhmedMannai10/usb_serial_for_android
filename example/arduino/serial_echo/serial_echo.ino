// Serial echo for the usb_serial_for_android example app.
// Works on any Arduino-compatible board (Uno, Nano, ESP32, Pico, ...).
//
// Send "LED ON" or "LED OFF" to switch the built-in LED.
// Anything else is echoed back.

void setup() {
  Serial.begin(115200);          // must match setPortParameters(...) in the app
  pinMode(LED_BUILTIN, OUTPUT);
}

void loop() {
  if (Serial.available()) {
    String message = Serial.readStringUntil('\n');  // the app ends every message with '\n'
    message.trim();

    if (message == "LED ON") {
      digitalWrite(LED_BUILTIN, HIGH);
      Serial.println("OK: LED is on");
    } else if (message == "LED OFF") {
      digitalWrite(LED_BUILTIN, LOW);
      Serial.println("OK: LED is off");
    } else {
      Serial.println("Got: " + message);
    }
  }
}
