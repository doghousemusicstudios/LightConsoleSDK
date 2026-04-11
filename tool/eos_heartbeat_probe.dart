// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../lib/output/osc_client.dart';

/// Probe ETC Eos Nomad for heartbeat response via TCP OSC on port 3032.
/// Eos uses OSC 1.0 over TCP with 4-byte packet-length header.
void main() async {
  print('=== ETC Eos Heartbeat Probe ===\n');

  // Connect via TCP to port 3032 (native OSC)
  print('Connecting to 127.0.0.1:3032 (TCP)...');
  late Socket socket;
  try {
    socket = await Socket.connect('127.0.0.1', 3032,
        timeout: const Duration(seconds: 3));
    print('Connected!\n');
  } catch (e) {
    print('ERROR: $e');
    return;
  }

  final responses = <String>[];
  final buffer = <int>[];

  socket.listen(
    (data) {
      buffer.addAll(data);
      // Eos TCP OSC: 4-byte big-endian length prefix + OSC packet
      while (buffer.length >= 4) {
        final len = (buffer[0] << 24) | (buffer[1] << 16) | (buffer[2] << 8) | buffer[3];
        if (buffer.length < 4 + len) break;
        final packet = Uint8List.fromList(buffer.sublist(4, 4 + len));
        buffer.removeRange(0, 4 + len);
        try {
          final msg = OscClient.decodeOscMessage(packet);
          if (msg != null) {
            final line = '${msg.address} args=${msg.args}';
            responses.add(line);
            print('  >>> RX: $line');
          }
        } catch (_) {
          print('  >>> RX: ${packet.length} bytes (not OSC)');
        }
      }
    },
    onError: (e) => print('Socket error: $e'),
    onDone: () => print('Socket closed by Eos'),
  );

  void sendOsc(String address, [List<dynamic>? args]) {
    final msg = OscClient.encodeOscMessage(
      OscMessage(address: address, args: args ?? []),
    );
    // TCP OSC: 4-byte big-endian length prefix
    final frame = ByteData(4 + msg.length);
    frame.setUint32(0, msg.length, Endian.big);
    final frameBytes = Uint8List.view(frame.buffer);
    frameBytes.setRange(4, 4 + msg.length, msg);
    socket.add(frameBytes);
    print('SENT: $address ${args ?? []}');
  }

  // Passive listen first — Eos may send unsolicited data on connect
  print('--- Passive listen (2s) ---');
  await Future.delayed(const Duration(seconds: 2));
  print('Received ${responses.length} unsolicited messages\n');

  // Heartbeat query: /eos/get/version
  print('--- Heartbeat: /eos/get/version ---');
  responses.clear();
  sendOsc('/eos/get/version');
  await Future.delayed(const Duration(seconds: 2));
  print('Responses: ${responses.length}\n');

  // Try other queries
  print('--- /eos/get/cue/1/0/list/count ---');
  responses.clear();
  sendOsc('/eos/get/cue/1/0/list/count');
  await Future.delayed(const Duration(seconds: 2));
  print('Responses: ${responses.length}\n');

  // Active cue
  print('--- /eos/get/cuelist/count ---');
  responses.clear();
  sendOsc('/eos/get/cuelist/count');
  await Future.delayed(const Duration(seconds: 2));
  print('Responses: ${responses.length}\n');

  // Patch count
  print('--- /eos/get/patch/count ---');
  responses.clear();
  sendOsc('/eos/get/patch/count');
  await Future.delayed(const Duration(seconds: 2));
  print('Responses: ${responses.length}\n');

  print('Done.');
  await socket.close();
}
