// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import '../lib/output/osc_client.dart';

/// Try to move visible MA3 faders to confirm packets are arriving.
void main() async {
  final ma3Ip = '10.0.0.134';
  final ma3Port = 9000;

  final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  sock.broadcastEnabled = true;

  sock.listen((event) {
    if (event == RawSocketEvent.read) {
      final d = sock.receive();
      if (d != null) {
        try {
          final msg = OscClient.decodeOscMessage(d.data);
          print('  >>> RESPONSE: ${msg?.address} args=${msg?.args}');
        } catch (_) {
          print('  >>> RESPONSE: ${d.data.length} bytes');
        }
      }
    }
  });

  void send(String address, List<dynamic> args) {
    final msg = OscClient.encodeOscMessage(OscMessage(address: address, args: args));
    sock.send(msg, InternetAddress(ma3Ip), ma3Port);
    print('SENT: $address $args');
  }

  print('=== MA3 Fader Move Test ===');
  print('Sending to $ma3Ip:$ma3Port from port ${sock.port}');
  print('Watch the MA3 screen for fader movement!\n');

  // Try Grand Master via command
  print('--- 1. Grand Master to 50% via command ---');
  send('/gma3/cmd', ['Master 50']);
  await Future.delayed(const Duration(seconds: 2));

  // Try Grand Master via direct address
  print('--- 2. Page1/Fader201 to 100% ---');
  send('/gma3/Page1/Fader201', [1.0]);
  await Future.delayed(const Duration(seconds: 2));

  // Try without /gma3/ prefix (some MA3 versions)
  print('--- 3. /Page1/Fader201 to 0.5 (no gma3 prefix) ---');
  send('/Page1/Fader201', [0.5]);
  await Future.delayed(const Duration(seconds: 2));

  // Try Fader1 (first executor)
  print('--- 4. /gma3/Page1/Fader1 to 1.0 ---');
  send('/gma3/Page1/Fader1', [1.0]);
  await Future.delayed(const Duration(seconds: 2));

  // Try the documented format: /gma3/Fader201
  print('--- 5. /gma3/Fader201 to 0.75 (short format) ---');
  send('/gma3/Fader201', [0.75]);
  await Future.delayed(const Duration(seconds: 2));

  // Try Fader201 with int value 0-100
  print('--- 6. /gma3/Page1/Fader201 with int 75 ---');
  send('/gma3/Page1/Fader201', [75]);
  await Future.delayed(const Duration(seconds: 2));

  // Try a simple command that should show in command line
  print('--- 7. /gma3/cmd "ClearAll" ---');
  send('/gma3/cmd', ['ClearAll']);
  await Future.delayed(const Duration(seconds: 2));

  print('\nDid anything move or change on the MA3 screen?');
  sock.close();
}
