// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../lib/output/osc_client.dart';

/// Try multiple framing modes against Eos:
/// 1. Port 3032 with 4-byte length prefix (OSC 1.0 TCP)
/// 2. Port 3032 raw (no framing)
/// 3. Port 3037 with SLIP encoding (OSC 1.1)
/// 4. UDP to port 3032 (fallback)
void main() async {
  print('=== ETC Eos Heartbeat Probe v2 ===\n');

  final query = OscClient.encodeOscMessage(
    OscMessage(address: '/eos/get/version', args: []),
  );

  // Method 1: TCP 3032 with length prefix
  await _testTcp('TCP 3032 (length prefix)', '127.0.0.1', 3032, query, _frameLengthPrefix);

  // Method 2: TCP 3032 raw (no framing)
  await _testTcp('TCP 3032 (raw)', '127.0.0.1', 3032, query, _frameRaw);

  // Method 3: TCP 3037 with SLIP
  await _testTcp('TCP 3037 SLIP', '127.0.0.1', 3037, query, _frameSlip);

  // Method 4: TCP 3037 with length prefix
  await _testTcp('TCP 3037 (length prefix)', '127.0.0.1', 3037, query, _frameLengthPrefix);

  // Method 5: TCP 3037 raw
  await _testTcp('TCP 3037 (raw)', '127.0.0.1', 3037, query, _frameRaw);

  // Method 6: UDP to various ports
  for (final port in [3032, 3034, 3037]) {
    await _testUdp('UDP $port', '127.0.0.1', port, query);
  }

  print('Done.');
}

Future<void> _testTcp(String label, String ip, int port, Uint8List oscData,
    Uint8List Function(Uint8List) framer) async {
  print('--- $label ---');
  try {
    final socket = await Socket.connect(ip, port,
        timeout: const Duration(seconds: 2));

    int rxBytes = 0;
    final rxData = <int>[];

    socket.listen(
      (data) {
        rxBytes += data.length;
        rxData.addAll(data);
        // Try to decode whatever comes back
        if (rxData.length > 10) {
          // Try length-prefixed
          if (rxData.length >= 4) {
            final len = (rxData[0] << 24) | (rxData[1] << 16) | (rxData[2] << 8) | rxData[3];
            if (len > 0 && len < 10000 && rxData.length >= 4 + len) {
              try {
                final msg = OscClient.decodeOscMessage(Uint8List.fromList(rxData.sublist(4, 4 + len)));
                if (msg != null) print('  >>> RX (len-prefix): ${msg.address} args=${msg.args}');
              } catch (_) {}
            }
          }
          // Try raw
          try {
            final msg = OscClient.decodeOscMessage(Uint8List.fromList(rxData));
            if (msg != null) print('  >>> RX (raw): ${msg.address} args=${msg.args}');
          } catch (_) {}
          // Try SLIP-decoded
          final unslipped = _unslip(rxData);
          if (unslipped != null) {
            try {
              final msg = OscClient.decodeOscMessage(unslipped);
              if (msg != null) print('  >>> RX (SLIP): ${msg.address} args=${msg.args}');
            } catch (_) {}
          }
        }
      },
      onError: (e) => print('  Error: $e'),
      onDone: () {},
    );

    final framed = framer(oscData);
    socket.add(framed);
    print('  Sent ${framed.length} bytes (OSC: ${oscData.length})');

    await Future.delayed(const Duration(seconds: 3));
    print('  Received: $rxBytes bytes total');
    if (rxBytes > 0 && rxData.isNotEmpty) {
      print('  First 40 bytes: ${rxData.take(40).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    }
    await socket.close();
  } catch (e) {
    print('  Connection failed: $e');
  }
  print('');
}

Future<void> _testUdp(String label, String ip, int port, Uint8List oscData) async {
  print('--- $label ---');
  final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  int rx = 0;
  sock.listen((event) {
    if (event == RawSocketEvent.read) {
      final d = sock.receive();
      if (d != null) {
        rx++;
        try {
          final msg = OscClient.decodeOscMessage(d.data);
          print('  >>> RX: ${msg?.address} args=${msg?.args}');
        } catch (_) {
          print('  >>> RX: ${d.data.length} bytes');
        }
      }
    }
  });
  sock.send(oscData, InternetAddress(ip), port);
  print('  Sent ${oscData.length} bytes');
  await Future.delayed(const Duration(seconds: 2));
  print('  Responses: $rx');
  sock.close();
  print('');
}

Uint8List _frameLengthPrefix(Uint8List data) {
  final frame = ByteData(4 + data.length);
  frame.setUint32(0, data.length, Endian.big);
  final result = Uint8List.view(frame.buffer);
  result.setRange(4, 4 + data.length, data);
  return result;
}

Uint8List _frameRaw(Uint8List data) => data;

// SLIP encoding: END=0xC0, ESC=0xDB, ESC_END=0xDC, ESC_ESC=0xDD
Uint8List _frameSlip(Uint8List data) {
  final buf = <int>[0xC0]; // start with END
  for (final b in data) {
    if (b == 0xC0) {
      buf.addAll([0xDB, 0xDC]);
    } else if (b == 0xDB) {
      buf.addAll([0xDB, 0xDD]);
    } else {
      buf.add(b);
    }
  }
  buf.add(0xC0); // end with END
  return Uint8List.fromList(buf);
}

Uint8List? _unslip(List<int> data) {
  // Find SLIP frame boundaries
  final start = data.indexOf(0xC0);
  if (start < 0) return null;
  final end = data.indexOf(0xC0, start + 1);
  if (end < 0) return null;
  final frame = data.sublist(start + 1, end);
  final result = <int>[];
  for (var i = 0; i < frame.length; i++) {
    if (frame[i] == 0xDB && i + 1 < frame.length) {
      if (frame[i + 1] == 0xDC) { result.add(0xC0); i++; }
      else if (frame[i + 1] == 0xDD) { result.add(0xDB); i++; }
      else { result.add(frame[i]); }
    } else {
      result.add(frame[i]);
    }
  }
  return Uint8List.fromList(result);
}
