// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import '../lib/output/osc_client.dart';

/// Quick test: try both 127.0.0.1 and LAN IP, and also check
/// if MA3's OSC config has the ports swapped.
void main() async {
  final targets = [
    ('127.0.0.1', 8000, 'loopback:8000'),
    ('10.0.0.134', 8000, 'LAN:8000'),
    ('10.0.0.134', 9000, 'LAN:9000 (swapped?)'),
  ];

  for (final (ip, port, label) in targets) {
    print('--- $label ---');
    final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    int rx = 0;
    sock.listen((event) {
      if (event == RawSocketEvent.read) {
        rx++;
        final d = sock.receive();
        if (d != null) {
          try {
            final msg = OscClient.decodeOscMessage(d.data);
            print('  RX: ${msg?.address} args=${msg?.args} from=${d.address.address}:${d.port}');
          } catch (_) {
            print('  RX: ${d.data.length} raw bytes from=${d.address.address}:${d.port}');
          }
        }
      }
    });

    final msg = OscClient.encodeOscMessage(
      OscMessage(address: '/gma3/cmd', args: ['Version']),
    );
    sock.send(msg, InternetAddress(ip), port);
    print('  Sent /gma3/cmd "Version" from ephemeral port ${sock.port}');

    // Also try setting a fader (this should produce visible feedback on MA3)
    final faderMsg = OscClient.encodeOscMessage(
      OscMessage(address: '/gma3/Page1/Fader201', args: [1.0]),
    );
    sock.send(faderMsg, InternetAddress(ip), port);
    print('  Sent /gma3/Page1/Fader201 1.0');

    await Future.delayed(const Duration(seconds: 3));
    print('  Responses: $rx\n');
    sock.close();
  }

  print('Check MA3 screen: did any fader move? If yes, packets arrived');
  print('but MA3 just doesnt send responses to our queries.');
  print('If no fader moved, packets are not reaching MA3.');
}
