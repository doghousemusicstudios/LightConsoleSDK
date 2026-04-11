// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import '../lib/output/osc_client.dart';

/// Two MA3 heartbeat strategies that don't need the Companion Plugin:
///
/// 1. Echo pattern: /gma3/cmd "Echo 'heartbeat'" with Send Command = ON
///    MA3 should echo the command output back via OSC
///
/// 2. Web Remote HTTP ping: http://<ma3-ip>:8080
///    MA3 exposes a web interface — HTTP 200 = alive
void main() async {
  final ma3Ip = '10.0.0.134';
  final ma3OscPort = 9000;

  print('=== MA3 Echo + HTTP Heartbeat Probe ===\n');

  // ── Strategy 1: Echo command ──
  print('--- Strategy 1: Echo via /gma3/cmd ---');
  print('Requires: Send Command = ON in MA3 OSC settings\n');

  final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  sock.broadcastEnabled = true;

  final responses = <String>[];
  sock.listen((event) {
    if (event == RawSocketEvent.read) {
      final d = sock.receive();
      if (d != null) {
        try {
          final msg = OscClient.decodeOscMessage(d.data);
          if (msg != null) {
            responses.add('${msg.address} args=${msg.args}');
            print('  >>> OSC RX: ${msg.address} args=${msg.args} from=${d.address.address}:${d.port}');
          }
        } catch (_) {
          print('  >>> RAW RX: ${d.data.length} bytes from=${d.address.address}:${d.port}');
        }
      }
    }
  });

  void sendOsc(String address, List<dynamic> args) {
    final msg = OscClient.encodeOscMessage(OscMessage(address: address, args: args));
    sock.send(msg, InternetAddress(ma3Ip), ma3OscPort);
    print('SENT: $address $args');
  }

  // Test Echo command
  sendOsc('/gma3/cmd', ["Echo 'heartbeat'"]);
  await Future.delayed(const Duration(seconds: 3));
  print('Echo responses: ${responses.length}');

  // Try variations
  responses.clear();
  sendOsc('/gma3/cmd', ['Echo "alive"']);
  await Future.delayed(const Duration(seconds: 2));
  print('Echo "alive" responses: ${responses.length}');

  // Try just getting MA3 to output anything via command feedback
  responses.clear();
  sendOsc('/gma3/cmd', ['List Page']);
  await Future.delayed(const Duration(seconds: 2));
  print('List Page responses: ${responses.length}');

  responses.clear();
  sendOsc('/gma3/cmd', ['Help']);
  await Future.delayed(const Duration(seconds: 2));
  print('Help responses: ${responses.length}');

  sock.close();

  // ── Strategy 2: HTTP Web Remote ping ──
  print('\n--- Strategy 2: HTTP Web Remote ping ---');
  print('Testing http://$ma3Ip:8080\n');

  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);

    final request = await client.getUrl(Uri.parse('http://$ma3Ip:8080'));
    final response = await request.close();

    print('HTTP Status: ${response.statusCode}');
    print('HTTP Reason: ${response.reasonPhrase}');

    if (response.statusCode == 200) {
      print('\n  HTTP 200 = MA3 is alive!');
      print('  This works as a heartbeat without any OSC configuration.');
    }

    // Read a bit of the response body
    final body = await response.transform(const SystemEncoding().decoder).join();
    final preview = body.substring(0, body.length.clamp(0, 200));
    print('  Body preview: $preview');

    client.close();
  } catch (e) {
    print('HTTP failed: $e');
  }

  // Also try port 80
  print('\n--- HTTP on port 80 ---');
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);
    final request = await client.getUrl(Uri.parse('http://$ma3Ip:80'));
    final response = await request.close();
    print('HTTP :80 Status: ${response.statusCode}');
    client.close();
  } catch (e) {
    print('HTTP :80 failed: $e');
  }

  print('\nDone.');
}
