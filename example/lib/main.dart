import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usb_serial_for_android/transaction.dart';
import 'package:usb_serial_for_android/usb_device.dart';
import 'package:usb_serial_for_android/usb_event.dart';
import 'package:usb_serial_for_android/usb_port.dart';
import 'package:usb_serial_for_android/usb_serial_for_android.dart';

/// A minimal USB serial terminal.
///
/// Pair it with example/arduino/serial_echo/serial_echo.ino on any
/// Arduino-compatible board (Uno, Nano, ESP32, Pico, ...).
void main() => runApp(const SerialTerminalApp());

class SerialTerminalApp extends StatelessWidget {
  const SerialTerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serial Terminal',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const TerminalPage(),
    );
  }
}

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  UsbPort? _port;
  Transaction<String>? _lines;
  StreamSubscription<String>? _lineSub;
  StreamSubscription<UsbEvent>? _usbSub;
  bool _connecting = false;
  String _status = 'Disconnected';
  final List<String> _log = [];
  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Connect when a board is plugged in, clean up when it is unplugged.
    _usbSub = UsbSerial.usbEventStream?.listen((UsbEvent event) {
      if (event.event == UsbEvent.ACTION_USB_ATTACHED) _connect();
      if (event.event == UsbEvent.ACTION_USB_DETACHED) _disconnect();
    });
    _connect();
  }

  Future<void> _connect() async {
    if (_port != null || _connecting) return;
    _connecting = true;
    try {
      // 1. Find the board.
      final List<UsbDevice> devices = await UsbSerial.listDevices();
      if (devices.isEmpty) {
        _setStatus('No USB device found');
        return;
      }
      final UsbDevice device = devices.first;

      // 2. Create a port. The driver is detected automatically; if your
      //    board is not recognised, pass a type such as UsbSerial.CDC.
      //    Android shows the USB permission dialog here if needed.
      final UsbPort? port = await device.create();
      if (port == null) {
        _setStatus('Unsupported device');
        return;
      }

      // 3. Open it with the same settings as Serial.begin(...) on the board.
      if (!await port.open()) {
        _setStatus('Could not open the port');
        return;
      }
      await port.setPortParameters(
        115200,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      // 4. Split the incoming bytes into lines, then start the read loop.
      //    connect() is what actually starts reading - without it, nothing arrives.
      _lines = Transaction.stringTerminated(
        port.inputStream!,
        Uint8List.fromList([10]), // '\n'
      );
      _lineSub = _lines!.stream.listen((String line) => _addLog('← ${line.trim()}'));
      await port.connect();

      // 5. Raise DTR and RTS. Boards with native USB only send once DTR is on;
      //    others may reset when these lines change, so give them a moment.
      await port.setDTR(true);
      await port.setRTS(true);
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      _port = port;
      _setStatus('Connected to ${device.productName ?? device.deviceName}');
    } on PlatformException catch (e) {
      _setStatus('Could not connect: ${e.message}');
    } finally {
      _connecting = false;
    }
  }

  Future<void> _send(String text) async {
    final UsbPort? port = _port;
    if (port == null || text.trim().isEmpty) return;
    // Messages end with '\n' so the board knows where each one stops.
    await port.write(Uint8List.fromList(utf8.encode('${text.trim()}\n')));
    _addLog('→ ${text.trim()}');
    _input.clear();
  }

  Future<void> _disconnect() async {
    await _lineSub?.cancel();
    _lineSub = null;
    _lines?.dispose();
    _lines = null;
    await _port?.close();
    _port = null;
    _setStatus('Disconnected');
  }

  void _addLog(String line) {
    if (!mounted) return;
    setState(() {
      _log.add(line);
      if (_log.length > 200) _log.removeAt(0);
    });
  }

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() => _status = status);
  }

  @override
  void dispose() {
    _usbSub?.cancel();
    _disconnect();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool connected = _port != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Serial Terminal'),
        actions: [
          TextButton(
            onPressed: connected ? _disconnect : _connect,
            child: Text(connected ? 'Disconnect' : 'Connect'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: connected ? Colors.green.shade50 : Colors.grey.shade200,
            child: Text(_status),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _log.length,
              itemBuilder: (context, i) => Text(
                _log[i],
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                OutlinedButton(onPressed: connected ? () => _send('LED ON') : null, child: const Text('LED ON')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: connected ? () => _send('LED OFF') : null, child: const Text('LED OFF')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: connected,
                    decoration: const InputDecoration(hintText: 'Type a message'),
                    onSubmitted: _send,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: connected ? () => _send(_input.text) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
