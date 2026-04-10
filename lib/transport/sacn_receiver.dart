import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'sacn_packet.dart';

/// A frame of DMX data received via sACN.
class DmxInputFrame {
  /// sACN universe (1-based).
  final int universe;

  /// 512 bytes of DMX channel data.
  final Uint8List data;

  /// Source name from the sACN packet.
  final String sourceName;

  /// sACN priority (0-200).
  final int priority;

  /// Timestamp when the frame was received.
  final DateTime timestamp;

  const DmxInputFrame({
    required this.universe,
    required this.data,
    required this.sourceName,
    required this.priority,
    required this.timestamp,
  });
}

/// Receives sACN (E1.31) DMX data from the network.
///
/// Joins multicast groups for configured universes and emits
/// [DmxInputFrame] objects as data arrives.
class SacnReceiver {
  static const int _sacnPort = 5568;

  RawDatagramSocket? _socket;
  final StreamController<DmxInputFrame> _frameController =
      StreamController<DmxInputFrame>.broadcast();
  final Set<int> _subscribedUniverses = {};
  bool _isListening = false;

  /// Stream of received DMX frames.
  Stream<DmxInputFrame> get frames => _frameController.stream;

  /// Whether the receiver is actively listening.
  bool get isListening => _isListening;

  /// Start listening for sACN data on the specified universes.
  ///
  /// [universes] — list of sACN universe numbers (1-based) to subscribe to.
  Future<void> start(List<int> universes) async {
    if (_isListening) return;

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _sacnPort,
      reuseAddress: true,
      reusePort: true,
    );

    // Join multicast groups for each universe
    for (final universe in universes) {
      final multicastAddr = SacnPacket.multicastAddress(universe);
      try {
        _socket!.joinMulticast(InternetAddress(multicastAddr));
        _subscribedUniverses.add(universe);
      } catch (e) {
        // Multicast join may fail on some network configurations
      }
    }

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) {
          _processPacket(datagram.data);
        }
      }
    });

    _isListening = true;
  }

  /// Subscribe to additional universes while already listening.
  void addUniverse(int universe) {
    if (_socket == null) return;
    final multicastAddr = SacnPacket.multicastAddress(universe);
    try {
      _socket!.joinMulticast(InternetAddress(multicastAddr));
      _subscribedUniverses.add(universe);
    } catch (_) {}
  }

  /// Unsubscribe from a universe.
  void removeUniverse(int universe) {
    if (_socket == null) return;
    final multicastAddr = SacnPacket.multicastAddress(universe);
    try {
      _socket!.leaveMulticast(InternetAddress(multicastAddr));
      _subscribedUniverses.remove(universe);
    } catch (_) {}
  }

  void _processPacket(Uint8List data) {
    if (data.length < SacnPacket.packetSize) return;

    final universe = SacnPacket.parseUniverse(data);
    final priority = SacnPacket.parsePriority(data);
    final sourceName = SacnPacket.parseSourceName(data);
    final dmxData = SacnPacket.parseDmxData(data);

    if (universe == null || dmxData == null) return;

    // Only emit frames for subscribed universes (or all if no filter)
    if (_subscribedUniverses.isNotEmpty &&
        !_subscribedUniverses.contains(universe)) {
      return;
    }

    _frameController.add(DmxInputFrame(
      universe: universe,
      data: dmxData,
      sourceName: sourceName ?? 'Unknown',
      priority: priority ?? 100,
      timestamp: DateTime.now(),
    ));
  }

  /// Stop listening and release the socket.
  void stop() {
    _socket?.close();
    _socket = null;
    _isListening = false;
    _subscribedUniverses.clear();
  }

  void dispose() {
    stop();
    _frameController.close();
  }
}
