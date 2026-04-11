// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../lib/output/osc_client.dart';

/// Probe MA3 via TCP on port 9000.
/// The sstaub/gma3 Arduino library documents that MA3 speaks TCP
/// on port 9000 and has a Parser that receives "cryptic" OSC patterns
/// representing internal data structure.
void main() async {
  final ma3Ip = '10.0.0.134';

  // MA3 is listening on UDP *:9000. Let's see if it also has TCP.
  for (final port in [9000, 8000, 9001]) {
    print('--- TCP $ma3Ip:$port ---');
    try {
      final socket = await Socket.connect(ma3Ip, port,
          timeout: const Duration(seconds: 3));
      print('  CONNECTED!');

      final rxData = <int>[];
      int rxCount = 0;

      socket.listen(
        (data) {
          rxCount++;
          rxData.addAll(data);
          // Print first few messages
          if (rxCount <= 5) {
            // Try OSC decode
            try {
              final msg = OscClient.decodeOscMessage(Uint8List.fromList(data));
              if (msg != null) {
                print('  RX OSC: ${msg.address} args=${msg.args}');
              } else {
                print('  RX raw: ${data.length} bytes: ${data.take(60).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
              }
            } catch (_) {
              print('  RX raw: ${data.length} bytes: ${data.take(60).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
            }
          }
        },
        onError: (e) => print('  Error: $e'),
        onDone: () => print('  Connection closed by MA3'),
      );

      // Passive listen — does MA3 send data on TCP connect?
      print('  Passive listen (3s)...');
      await Future.delayed(const Duration(seconds: 3));
      print('  Received $rxCount chunks, ${rxData.length} total bytes');

      // Try sending a command over TCP
      if (rxData.isEmpty) {
        print('  Sending /gma3/cmd "Version" over TCP...');
        final msg = OscClient.encodeOscMessage(
          OscMessage(address: '/gma3/cmd', args: ['Version']),
        );
        socket.add(msg);
        await Future.delayed(const Duration(seconds: 2));
        print('  After send: $rxCount chunks, ${rxData.length} total bytes');
      }

      // Try moving a fader over TCP
      print('  Sending /gma3/Page1/Fader201 1.0 over TCP...');
      final faderMsg = OscClient.encodeOscMessage(
        OscMessage(address: '/gma3/Page1/Fader201', args: [1.0]),
      );
      socket.add(faderMsg);
      await Future.delayed(const Duration(seconds: 2));
      print('  After fader: $rxCount chunks, ${rxData.length} total bytes');

      await socket.close();
    } catch (e) {
      print('  Failed: $e');
    }
    print('');
  }

  print('Done.');
}
