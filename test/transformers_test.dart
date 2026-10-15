import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:usb_serial_for_android/transaction.dart';

/// Feeds byte chunks into a [Transaction.stringTerminated], the same way
/// `UsbPort.inputStream` delivers data from the device, and records the lines
/// that come out.
class _LineHarness {
  _LineHarness(List<int> terminator) {
    transaction = Transaction.stringTerminated(
      _input.stream,
      Uint8List.fromList(terminator),
    );
    _subscription = transaction.stream.listen(lines.add);
  }

  final StreamController<Uint8List> _input = StreamController<Uint8List>();
  late final Transaction<String> transaction;
  late final StreamSubscription<String> _subscription;
  final List<String> lines = [];

  /// Sends one chunk and waits until it has gone through the transformer.
  Future<void> send(String chunk) async {
    _input.add(Uint8List.fromList(latin1.encode(chunk)));
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    transaction.dispose();
    await _input.close();
  }
}

void main() {
  group('TerminatedStringTransformer via Transaction.stringTerminated', () {
    test('joins a line that arrives split across several chunks', () async {
      final harness = _LineHarness([10]);

      await harness.send('hel');
      expect(harness.lines, isEmpty);
      await harness.send('lo wor');
      expect(harness.lines, isEmpty);
      await harness.send('ld\n');
      expect(harness.lines, ['hello world']);

      await harness.dispose();
    });

    test('splits two lines that arrive in one chunk', () async {
      final harness = _LineHarness([10]);

      await harness.send('first\nsecond\n');
      expect(harness.lines, ['first', 'second']);

      await harness.dispose();
    });

    test('keeps a partial line until the rest arrives', () async {
      final harness = _LineHarness([10]);

      await harness.send('one\ntw');
      expect(harness.lines, ['one']);
      await harness.send('o\n');
      expect(harness.lines, ['one', 'two']);

      await harness.dispose();
    });

    test(r'with terminator [10], \r\n input leaves a trailing \r', () async {
      final harness = _LineHarness([10]);

      await harness.send('temp=21.5\r\n');
      expect(harness.lines, ['temp=21.5\r']);
      // This is why the example app calls trim() on every line.
      expect(harness.lines.single.trim(), 'temp=21.5');

      await harness.dispose();
    });

    test(r'with terminator [13, 10], \r\n input is stripped fully', () async {
      final harness = _LineHarness([13, 10]);

      await harness.send('temp=21.5\r\nhum=40\r\n');
      expect(harness.lines, ['temp=21.5', 'hum=40']);

      await harness.dispose();
    });

    test(r'with terminator [13, 10], a \r\n split across chunks', () async {
      final harness = _LineHarness([13, 10]);

      await harness.send('ok\r');
      expect(harness.lines, isEmpty);
      await harness.send('\n');
      expect(harness.lines, ['ok']);

      await harness.dispose();
    });
  });
}
