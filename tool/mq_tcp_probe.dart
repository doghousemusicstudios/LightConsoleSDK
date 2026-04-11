// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

/// Probe the new MagicQ TCP port 4914 and UDP ports 4910/4920.
void main() async {
  print('=== MagicQ TCP + New UDP Probe ===\n');

  // ── TCP 4914 ──
  print('--- TCP 4914 ---');
  try {
    final socket = await Socket.connect('127.0.0.1', 4914,
        timeout: const Duration(seconds: 3));
    print('  CONNECTED!');

    final rxData = <int>[];
    socket.listen(
      (data) {
        rxData.addAll(data);
        print('  TCP RX: ${data.length} bytes');
        print('    Hex: ${data.take(60).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        final ascii = String.fromCharCodes(data.where((b) => b >= 32 && b < 127));
        if (ascii.isNotEmpty) print('    ASCII: $ascii');
      },
      onDone: () => print('  Connection closed'),
    );

    // Passive listen
    print('  Passive listen (3s)...');
    await Future.delayed(const Duration(seconds: 3));
    print('  Received: ${rxData.length} bytes');

    // Try sending something
    if (rxData.isEmpty) {
      print('  Sending "10H\\r\\n"...');
      socket.write('10H\r\n');
      await Future.delayed(const Duration(seconds: 2));
      print('  After send: ${rxData.length} bytes');
    }

    await socket.close();
  } catch (e) {
    print('  Failed: $e');
  }

  // ── UDP 4910, 4920, 4809 ──
  for (final port in [4910, 4920, 4809, 25957]) {
    print('\n--- UDP $port ---');
    final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    int rx = 0;
    sock.listen((event) {
      if (event == RawSocketEvent.read) {
        final d = sock.receive();
        if (d != null) {
          rx++;
          print('  UDP RX: ${d.data.length} bytes from ${d.address.address}:${d.port}');
          final ascii = String.fromCharCodes(d.data.where((b) => b >= 32 && b < 127));
          print('    Hex: ${d.data.take(40).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          if (ascii.isNotEmpty) print('    ASCII: $ascii');
        }
      }
    });

    // Send a simple ping
    sock.send('10H\r\n'.codeUnits, InternetAddress('127.0.0.1'), port);
    print('  Sent "10H" to port $port');
    await Future.delayed(const Duration(seconds: 2));
    print('  Responses: $rx');
    sock.close();
  }

  print('\nDone.');
}
