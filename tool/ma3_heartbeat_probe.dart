// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../lib/output/osc_client.dart';

/// Probes a GrandMA3 onPC instance to determine which OSC queries
/// get a response, for heartbeat validation.
///
/// MA3 config:
///   - Destination IP: 10.0.0.134
///   - Destination Port (where MA3 sends TO us): 9000
///   - Source Port (where MA3 LISTENS): 8000
///
/// Usage: dart run tool/ma3_heartbeat_probe.dart
void main() async {
  final ma3Ip = '10.0.0.134';
  final ma3Port = 8000; // port MA3 listens on
  final listenPort = 9000; // port MA3 sends responses to

  print('=== MA3 Heartbeat Probe ===');
  print('MA3 target: $ma3Ip:$ma3Port');
  print('Listening for responses on port $listenPort');
  print('');

  // Open a listener for MA3 responses
  final listener = await RawDatagramSocket.bind(InternetAddress.anyIPv4, listenPort);
  print('Listener bound to port $listenPort');

  // Collect any incoming messages
  final responses = <String>[];
  listener.listen((event) {
    if (event == RawSocketEvent.read) {
      final datagram = listener.receive();
      if (datagram != null) {
        try {
          final msg = OscClient.decodeOscMessage(datagram.data);
          if (msg != null) {
            final timestamp = DateTime.now().toIso8601String().substring(11, 23);
            responses.add('[$timestamp] ${msg.address} ${msg.args}');
            print('  RECEIVED: ${msg.address} args=${msg.args} from=${datagram.address.address}:${datagram.port}');
          }
        } catch (e) {
          print('  RECEIVED (non-OSC): ${datagram.data.length} bytes');
        }
      }
    }
  });

  // Open a sender to MA3
  final sender = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  sender.broadcastEnabled = true;

  void sendOsc(String address, [List<dynamic>? args]) {
    final msg = OscMessage(address: address, args: args ?? []);
    final encoded = OscClient.encodeOscMessage(msg);
    sender.send(encoded, InternetAddress(ma3Ip), ma3Port);
    print('SENT: $address ${args ?? []}');
  }

  print('');
  print('--- Phase 1: Passive listen (3s) ---');
  print('Checking if MA3 sends anything unprompted...');
  await Future.delayed(const Duration(seconds: 3));

  if (responses.isNotEmpty) {
    print('MA3 IS sending unsolicited data (${responses.length} messages)');
  } else {
    print('No unsolicited data from MA3.');
  }

  print('');
  print('--- Phase 2: Heartbeat candidate queries ---');
  responses.clear();

  // Query 1: Empty command (documented no-op)
  sendOsc('/gma3/cmd', ['']);
  await Future.delayed(const Duration(seconds: 2));
  print('  After /gma3/cmd "": ${responses.length} responses');

  // Query 2: Version query via command
  responses.clear();
  sendOsc('/gma3/cmd', ['Version']);
  await Future.delayed(const Duration(seconds: 2));
  print('  After /gma3/cmd "Version": ${responses.length} responses');

  // Query 3: Fader query
  responses.clear();
  sendOsc('/gma3/Page1/Fader201', []);
  await Future.delayed(const Duration(seconds: 2));
  print('  After /gma3/Page1/Fader201: ${responses.length} responses');

  // Query 4: Fader set to current value (read-back test)
  responses.clear();
  sendOsc('/gma3/Page1/Fader201', [0.0]);
  await Future.delayed(const Duration(seconds: 2));
  print('  After /gma3/Page1/Fader201 0.0: ${responses.length} responses');

  // Query 5: Simple ping-style
  responses.clear();
  sendOsc('/ping', []);
  await Future.delayed(const Duration(seconds: 2));
  print('  After /ping: ${responses.length} responses');

  // Query 6: Request something from the pool
  responses.clear();
  sendOsc('/gma3/13.13.1.6.1', []);
  await Future.delayed(const Duration(seconds: 2));
  print('  After /gma3/13.13.1.6.1 (pool object): ${responses.length} responses');

  print('');
  print('--- Summary ---');
  print('Total responses received across all probes: check output above');
  print('');

  // Final passive listen
  print('--- Phase 3: Extended passive listen (5s) ---');
  responses.clear();
  await Future.delayed(const Duration(seconds: 5));
  if (responses.isNotEmpty) {
    print('Received ${responses.length} messages during passive listen:');
    for (final r in responses) {
      print('  $r');
    }
  } else {
    print('No additional messages.');
  }

  print('');
  print('Done. Closing sockets.');
  sender.close();
  listener.close();
}
