// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import '../lib/output/osc_client.dart';

/// MA3 OSC config shows:
///   Destination IP: 10.0.0.134
///   Port: 8000 (this is where MA3 SENDS TO us)
///   Receive/Send/ReceiveCommand/SendCommand: all Yes
///
/// So we should LISTEN on 8000 and SEND to... where?
/// MA3 onPC listens on the same port it sends from.
/// The source port in MA3's UDP packets will tell us.
///
/// Strategy: bind to port 8000, listen for anything, and also
/// try sending TO port 8000 on MA3's IP.
void main() async {
  final ma3Ip = '10.0.0.134';

  print('=== MA3 Heartbeat Probe v3 ===');
  print('');

  // Listen on port 8000 — where MA3 is configured to send
  print('--- Binding to port 8000 (MA3 sends here) ---');
  late RawDatagramSocket sock;
  try {
    sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8000);
  } catch (e) {
    print('ERROR: Could not bind to port 8000: $e');
    print('Something else is using this port. Checking...');
    final result = await Process.run('lsof', ['-i', ':8000', '-P']);
    print(result.stdout);
    return;
  }

  print('Bound to port 8000');
  sock.broadcastEnabled = true;

  int rxCount = 0;
  sock.listen((event) {
    if (event == RawSocketEvent.read) {
      final d = sock.receive();
      if (d != null) {
        rxCount++;
        try {
          final msg = OscClient.decodeOscMessage(d.data);
          if (msg != null) {
            print('  RX: ${msg.address} args=${msg.args} '
                'from=${d.address.address}:${d.port}');
          }
        } catch (_) {
          print('  RX: ${d.data.length} raw bytes from=${d.address.address}:${d.port}');
        }
      }
    }
  });

  // Phase 1: passive listen — does MA3 send anything unprompted?
  print('\n--- Phase 1: Passive listen on 8000 (5s) ---');
  await Future.delayed(const Duration(seconds: 5));
  print('Received: $rxCount messages');

  // Phase 2: Send commands TO MA3 on port 8000 FROM port 8000
  // (same port for both directions)
  print('\n--- Phase 2: Send queries from port 8000 to $ma3Ip:8000 ---');

  void send(String address, [List<dynamic>? args]) {
    final msg = OscClient.encodeOscMessage(
      OscMessage(address: address, args: args ?? []),
    );
    sock.send(msg, InternetAddress(ma3Ip), 8000);
    print('SENT: $address ${args ?? []}');
  }

  rxCount = 0;
  send('/gma3/cmd', ['Version']);
  await Future.delayed(const Duration(seconds: 2));
  print('  After Version: $rxCount responses');

  rxCount = 0;
  send('/gma3/Page1/Fader201', [1.0]);
  await Future.delayed(const Duration(seconds: 2));
  print('  After Fader201=1.0: $rxCount responses');

  rxCount = 0;
  send('/gma3/Page1/Fader201', [0.0]);
  await Future.delayed(const Duration(seconds: 2));
  print('  After Fader201=0.0: $rxCount responses');

  // Phase 3: Try sending to different ports on MA3
  print('\n--- Phase 3: Try other destination ports ---');
  for (final port in [9000, 8001, 9001, 7000]) {
    rxCount = 0;
    final msg = OscClient.encodeOscMessage(
      OscMessage(address: '/gma3/cmd', args: ['Version']),
    );
    sock.send(msg, InternetAddress(ma3Ip), port);
    print('SENT /gma3/cmd "Version" to port $port');
    await Future.delayed(const Duration(seconds: 1));
    print('  Responses: $rxCount');
  }

  print('\n--- Phase 4: Final passive listen (3s) ---');
  rxCount = 0;
  await Future.delayed(const Duration(seconds: 3));
  print('Final passive: $rxCount messages');

  print('\nDone.');
  sock.close();
}
