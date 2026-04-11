// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import '../lib/output/osc_client.dart';

/// MA3 port changed to 9000. MA3 should now:
///   - Listen on port 9000
///   - Send responses back to the source port of incoming packets
void main() async {
  final ma3Ip = '10.0.0.134';
  final ma3Port = 9000;

  print('=== MA3 Heartbeat Probe v4 ===');
  print('Sending to $ma3Ip:$ma3Port');
  print('');

  // Verify MA3 is now on port 9000
  final lsof = await Process.run('lsof', ['-i', ':9000', '-P']);
  print('Port 9000 check:\n${lsof.stdout}');

  final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  sock.broadcastEnabled = true;
  print('Our socket: port ${sock.port}');

  int rxCount = 0;
  sock.listen((event) {
    if (event == RawSocketEvent.read) {
      final d = sock.receive();
      if (d != null) {
        rxCount++;
        try {
          final msg = OscClient.decodeOscMessage(d.data);
          if (msg != null) {
            print('  >>> RX: ${msg.address} args=${msg.args} from=${d.address.address}:${d.port}');
          }
        } catch (_) {
          print('  >>> RX: ${d.data.length} raw bytes from=${d.address.address}:${d.port}');
        }
      }
    }
  });

  void send(String address, [List<dynamic>? args]) {
    final msg = OscClient.encodeOscMessage(
      OscMessage(address: address, args: args ?? []),
    );
    sock.send(msg, InternetAddress(ma3Ip), ma3Port);
    print('SENT: $address ${args ?? []}');
  }

  // Test 1: fader move (visible on MA3 screen)
  print('\n--- Test 1: Move fader (should be visible on MA3) ---');
  rxCount = 0;
  send('/gma3/Page1/Fader201', [1.0]);
  await Future.delayed(const Duration(seconds: 2));
  print('Responses: $rxCount');

  // Test 2: command
  print('\n--- Test 2: Version command ---');
  rxCount = 0;
  send('/gma3/cmd', ['Version']);
  await Future.delayed(const Duration(seconds: 2));
  print('Responses: $rxCount');

  // Test 3: fader back to 0
  print('\n--- Test 3: Fader back to 0 ---');
  rxCount = 0;
  send('/gma3/Page1/Fader201', [0.0]);
  await Future.delayed(const Duration(seconds: 2));
  print('Responses: $rxCount');

  // Test 4: empty command
  print('\n--- Test 4: Empty command ---');
  rxCount = 0;
  send('/gma3/cmd', ['']);
  await Future.delayed(const Duration(seconds: 2));
  print('Responses: $rxCount');

  print('\nDone.');
  sock.close();
}
