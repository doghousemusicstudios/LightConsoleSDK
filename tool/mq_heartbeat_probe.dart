// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';


/// Probe ChamSys MagicQ PC for heartbeat options:
/// 1. HTTP on port 8080 (like MA3)
/// 2. HTTP on other common ports
/// 3. CREP on port 6553 (binary UDP protocol — already listening)
/// 4. OSC (if unlocked)
void main() async {
  final mqIp = '127.0.0.1';

  print('=== ChamSys MagicQ Heartbeat Probe ===\n');

  // ── Strategy 1: HTTP on various ports ──
  print('--- Strategy 1: HTTP ping ---');
  for (final port in [8080, 80, 8000, 8888, 9090, 4910]) {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final request = await client.getUrl(Uri.parse('http://$mqIp:$port'));
      final response = await request.close();
      print('  http://$mqIp:$port → HTTP ${response.statusCode} ✓');
      final body = await response.transform(const SystemEncoding().decoder).join();
      print('    Body: ${body.substring(0, body.length.clamp(0, 100))}');
      client.close();
    } catch (_) {
      print('  http://$mqIp:$port → Failed');
    }
  }

  // Also try LAN IP
  print('\n  Trying LAN IP...');
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 2);
    final request = await client.getUrl(Uri.parse('http://10.0.0.134:8080'));
    final response = await request.close();
    print('  http://10.0.0.134:8080 → HTTP ${response.statusCode} ✓');
    client.close();
  } catch (_) {
    print('  http://10.0.0.134:8080 → Failed');
  }

  // ── Strategy 2: CREP on port 6553 ──
  print('\n--- Strategy 2: CREP binary protocol on 6553 ---');
  print('MagicQ is already listening on UDP 6553 (CREP).');
  print('CREP uses a 4-byte "CREP" header + ASCII commands.');

  final crepSock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  int crepRx = 0;

  crepSock.listen((event) {
    if (event == RawSocketEvent.read) {
      final d = crepSock.receive();
      if (d != null) {
        crepRx++;
        print('  CREP RX: ${d.data.length} bytes from ${d.address.address}:${d.port}');
        print('    Hex: ${d.data.take(40).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        print('    ASCII: ${String.fromCharCodes(d.data.where((b) => b >= 32 && b < 127))}');
      }
    }
  });

  // Send a simple CREP message: "PERC" header (little-endian "CREP") + version + seq + empty
  // Actually, try just sending a raw ASCII command without header (MagicQ has "no header" mode)
  crepSock.send([0x31, 0x30, 0x48, 0x0d, 0x0a], InternetAddress(mqIp), 6553); // "10H\r\n" = get status
  print('  Sent raw ASCII "10H" to CREP port');
  await Future.delayed(const Duration(seconds: 2));
  print('  CREP responses: $crepRx');

  crepSock.close();

  // ── Strategy 3: OSC (may be locked in demo mode) ──
  print('\n--- Strategy 3: OSC probes ---');

  // Check if MagicQ has any OSC port open
  final lsof = await Process.run('lsof', ['-i', '-P']);
  final magicLines = (lsof.stdout as String)
      .split('\n')
      .where((l) => l.contains('MagicQ'))
      .toList();
  print('  MagicQ open ports:');
  for (final line in magicLines) {
    print('    $line');
  }

  print('\nDone.');
}
