// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import '../lib/output/osc_client.dart';

/// Second attempt: use a SINGLE socket bound to port 9000 for both
/// sending and receiving. MA3's "In & Out" is configured with:
///   - Destination IP: 10.0.0.134 (our Mac)
///   - Destination Port: 9000 (where MA3 sends TO us)
///   - Source Port: 8000 (where MA3 LISTENS)
///
/// This means we should send FROM port 9000 TO port 8000, and
/// receive on the same port 9000.
void main() async {
  final ma3Ip = '10.0.0.134';
  final ma3Port = 8000;
  final ourPort = 9000;

  print('=== MA3 Heartbeat Probe v2 ===');
  print('Binding to port $ourPort (single socket for send + receive)');
  print('MA3 target: $ma3Ip:$ma3Port');
  print('');

  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, ourPort);
  socket.broadcastEnabled = true;

  int responseCount = 0;

  socket.listen((event) {
    if (event == RawSocketEvent.read) {
      final datagram = socket.receive();
      if (datagram != null) {
        responseCount++;
        try {
          final msg = OscClient.decodeOscMessage(datagram.data);
          if (msg != null) {
            print('  RECEIVED OSC: ${msg.address} args=${msg.args} '
                'from=${datagram.address.address}:${datagram.port}');
          } else {
            print('  RECEIVED raw: ${datagram.data.length} bytes '
                'from=${datagram.address.address}:${datagram.port}');
          }
        } catch (e) {
          print('  RECEIVED (decode error): ${datagram.data.length} bytes '
              'from=${datagram.address.address}:${datagram.port}');
        }
      }
    }
  });

  void sendOsc(String address, [List<dynamic>? args]) {
    final msg = OscMessage(address: address, args: args ?? []);
    final encoded = OscClient.encodeOscMessage(msg);
    socket.send(encoded, InternetAddress(ma3Ip), ma3Port);
    print('SENT: $address ${args ?? []}');
  }

  // Passive listen first
  print('--- Passive listen (3s) ---');
  await Future.delayed(const Duration(seconds: 3));
  print('Passive: $responseCount messages received');
  print('');

  // Try each query
  final queries = <(String, List<dynamic>?)>[
    ('/gma3/cmd', ['Version']),
    ('/gma3/cmd', ['']),
    ('/gma3/cmd', ['List']),
    ('/gma3/Page1/Fader201', null),
    ('/gma3/Page1/Fader201', [0.5]),
    ('/gma3/13.13.1.6.1', null),
    ('/cmd', ['Version']),
    ('/gma3/', null),
  ];

  print('--- Sending queries ---');
  for (final (address, args) in queries) {
    responseCount = 0;
    sendOsc(address, args);
    await Future.delayed(const Duration(seconds: 2));
    print('  -> $responseCount responses\n');
  }

  // Extended passive
  print('--- Extended passive listen (5s) ---');
  responseCount = 0;
  await Future.delayed(const Duration(seconds: 5));
  print('Extended passive: $responseCount messages');

  print('\nDone.');
  socket.close();
}
