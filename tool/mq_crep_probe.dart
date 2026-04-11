// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Probe MagicQ CREP protocol more thoroughly.
/// CREP packet: 4-byte header "CREP" + 2-byte version + 1-byte seq_fwd +
/// 1-byte seq_bkwd + 2-byte length + ASCII command data
///
/// Also try the remote app port 4910 (TCP).
void main() async {
  print('=== MagicQ CREP + Remote App Probe ===\n');

  // ── CREP with proper header ──
  print('--- CREP with proper header on port 6553 ---');

  final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  int rx = 0;

  sock.listen((event) {
    if (event == RawSocketEvent.read) {
      final d = sock.receive();
      if (d != null) {
        rx++;
        print('  RX: ${d.data.length} bytes');
        print('    Hex: ${d.data.take(60).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        final ascii = String.fromCharCodes(d.data.where((b) => b >= 32 && b < 127));
        if (ascii.isNotEmpty) print('    ASCII: $ascii');
      }
    }
  });

  // Build proper CREP packet
  // Header: CREP (but on wire it's sent as PERC in little-endian? Or just CREP?)
  // Let's try both
  for (final header in ['CREP', 'PERC']) {
    final cmd = '10H'; // Query command
    final headerBytes = header.codeUnits;
    final cmdBytes = cmd.codeUnits;
    final packet = Uint8List(10 + cmdBytes.length);
    packet.setRange(0, 4, headerBytes); // Header
    packet[4] = 0x01; // version low
    packet[5] = 0x00; // version high
    packet[6] = 0x01; // seq_fwd
    packet[7] = 0x00; // seq_bkwd
    packet[8] = cmdBytes.length & 0xFF; // length low
    packet[9] = (cmdBytes.length >> 8) & 0xFF; // length high
    packet.setRange(10, 10 + cmdBytes.length, cmdBytes);

    rx = 0;
    sock.send(packet, InternetAddress('127.0.0.1'), 6553);
    print('Sent CREP ($header header) cmd="$cmd" (${packet.length} bytes)');
    await Future.delayed(const Duration(seconds: 2));
    print('  Responses: $rx\n');
  }

  // Try raw command without header ("no header" mode)
  for (final cmd in ['10H', '1,1,1H', 'PB,1,1H']) {
    rx = 0;
    final cmdBytes = Uint8List.fromList([...cmd.codeUnits, 0x0D, 0x0A]);
    sock.send(cmdBytes, InternetAddress('127.0.0.1'), 6553);
    print('Sent raw "$cmd\\r\\n" to CREP port');
    await Future.delayed(const Duration(seconds: 1));
    print('  Responses: $rx');
  }

  sock.close();

  // ── Remote app port 4910 (TCP) ──
  print('\n--- Remote app port 4910 (TCP) ---');
  try {
    final socket = await Socket.connect('127.0.0.1', 4910,
        timeout: const Duration(seconds: 3));
    print('  CONNECTED to TCP 4910!');

    final rxData = <int>[];
    socket.listen(
      (data) {
        rxData.addAll(data);
        print('  TCP RX: ${data.length} bytes');
        print('    Hex: ${data.take(40).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      },
      onDone: () => print('  Connection closed'),
    );

    await Future.delayed(const Duration(seconds: 3));
    print('  Total received: ${rxData.length} bytes');
    await socket.close();
  } catch (e) {
    print('  TCP 4910 failed: $e');
  }

  // ── Remote app port 4911 (TCP — documented as TCP port for remote) ──
  print('\n--- Remote app port 4911 (TCP) ---');
  try {
    final socket = await Socket.connect('127.0.0.1', 4911,
        timeout: const Duration(seconds: 3));
    print('  CONNECTED to TCP 4911!');

    final rxData = <int>[];
    socket.listen(
      (data) {
        rxData.addAll(data);
        print('  TCP RX: ${data.length} bytes');
      },
      onDone: () => print('  Connection closed'),
    );

    await Future.delayed(const Duration(seconds: 2));
    print('  Total received: ${rxData.length} bytes');
    await socket.close();
  } catch (e) {
    print('  TCP 4911 failed: $e');
  }

  print('\nDone.');
}
