import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'sacn_receiver.dart'; // for DmxInputFrame

/// Receives Art-Net DMX data from the network.
///
/// Listens on UDP port 6454 for incoming ArtDmx (opcode 0x5000) packets
/// and emits [DmxInputFrame] objects.
///
/// This receiver can coexist with ShowUp's ArtNetService send socket
/// since they operate on the same port but in different directions.
class ArtNetReceiver {
  static const int _artNetPort = 6454;
  static const String _artNetHeader = 'Art-Net';
  static const int _opCodeDmx = 0x5000;

  RawDatagramSocket? _socket;
  final StreamController<DmxInputFrame> _frameController =
      StreamController<DmxInputFrame>.broadcast();
  bool _isListening = false;

  /// Stream of received DMX frames.
  Stream<DmxInputFrame> get frames => _frameController.stream;

  /// Whether the receiver is actively listening.
  bool get isListening => _isListening;

  /// Start listening for Art-Net DMX data.
  Future<void> start() async {
    if (_isListening) return;

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _artNetPort,
      reuseAddress: true,
      reusePort: true,
    );

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) {
          _processPacket(datagram.data, datagram.address.address);
        }
      }
    });

    _isListening = true;
  }

  void _processPacket(Uint8List data, String sourceIp) {
    // Minimum ArtDmx packet: 18 header + at least 2 DMX channels
    if (data.length < 20) return;

    // Verify Art-Net header
    final header = String.fromCharCodes(data.sublist(0, 7));
    if (header != _artNetHeader) return;
    if (data[7] != 0) return; // null terminator

    // Check opcode (little-endian)
    final opCode = data[8] | (data[9] << 8);
    if (opCode != _opCodeDmx) return;

    // Parse universe from SubUni (byte 14) and Net (byte 15)
    final subUni = data[14];
    final net = data[15];
    final universe = (net << 8) | subUni;

    // Parse DMX data length (big-endian, bytes 16-17)
    final length = (data[16] << 8) | data[17];
    final dmxLength = length.clamp(0, 512);

    if (data.length < 18 + dmxLength) return;

    // Extract DMX data (pad to 512 if shorter)
    final dmxData = Uint8List(512);
    dmxData.setRange(0, dmxLength, data.sublist(18, 18 + dmxLength));

    _frameController.add(DmxInputFrame(
      universe: universe + 1, // Convert to 1-based like sACN
      data: dmxData,
      sourceName: sourceIp,
      priority: 100, // Art-Net has no priority concept
      timestamp: DateTime.now(),
    ));
  }

  /// Stop listening and release the socket.
  void stop() {
    _socket?.close();
    _socket = null;
    _isListening = false;
  }

  void dispose() {
    stop();
    _frameController.close();
  }
}
