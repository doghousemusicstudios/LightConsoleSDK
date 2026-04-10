import 'dart:io';
import 'dart:typed_data';

import 'sacn_packet.dart';
import '../models/coexistence_config.dart';

/// sACN (E1.31) DMX transport.
///
/// Implements the same transport interface contract as ShowUp's ArtNetService:
///   - connect(targetIp, port) — sets up the UDP socket
///   - sendUniverse(universe, dmxData) — sends a single universe
///   - disconnect() — tears down the socket
///
/// sACN supports both multicast (default) and unicast modes.
/// Each universe can have an independent priority level for
/// priority-based merging with other sACN sources (e.g., a console).
///
/// This class does NOT implement ShowUp's TransportInterface directly
/// to avoid a compile-time dependency on the flutter-app package.
/// Instead, ShowUp wraps it via a thin adapter in its providers.
class SacnTransport {
  static const int _defaultPort = 5568; // sACN standard port

  RawDatagramSocket? _socket;
  String? _targetIp;
  bool _isConnected = false;
  int _port = _defaultPort;

  /// Per-universe sequence counters (0-255, wrapping).
  final Map<int, int> _sequenceCounters = {};

  /// Per-universe priority overrides.
  final Map<int, int> _priorities = {};

  /// Source name embedded in sACN packets.
  String sourceName;

  /// Whether to use multicast (true) or unicast (false).
  bool useMulticast;

  /// sACN targets for unicast mode. Key = universe, value = IP.
  final Map<int, String> _unicastTargets = {};

  /// Global default priority (0-200).
  int defaultPriority;

  /// CID (Component Identifier) — unique per device.
  Uint8List? cid;

  SacnTransport({
    this.sourceName = 'ShowUp',
    this.useMulticast = true,
    this.defaultPriority = 100,
    this.cid,
  });

  bool get isConnected => _isConnected;
  String? get targetIp => _targetIp;
  List<String> get targetIps =>
      _targetIp != null ? [_targetIp!] : [];

  /// Configure sACN output from a list of [SacnTarget]s.
  void configureSacnTargets(List<SacnTarget> targets) {
    for (final target in targets) {
      _priorities[target.universe] = target.priority;
      if (!target.multicast && target.ip != null) {
        _unicastTargets[target.universe] = target.ip!;
      }
    }
  }

  /// Set the priority for a specific universe.
  void setPriority(int universe, int priority) {
    _priorities[universe] = priority.clamp(0, 200);
  }

  /// Get the current priority for a universe.
  int getPriority(int universe) =>
      _priorities[universe] ?? defaultPriority;

  /// Connect the sACN transport.
  ///
  /// [targetIp] — for unicast: the destination IP. For multicast: the
  /// local interface to bind to (use '0.0.0.0' for any).
  /// [port] — sACN port (default 5568).
  Future<void> connect(String targetIp, {int? port}) async {
    _port = port ?? _defaultPort;
    _targetIp = targetIp;

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0, // bind to any available port for sending
    );
    _socket!.broadcastEnabled = true;
    _socket!.multicastHops = 4;

    _isConnected = true;
  }

  /// Send a universe of DMX data.
  ///
  /// [universe] — 0-based universe index (converted to 1-based for sACN).
  /// [dmxData] — 512 bytes of DMX channel data.
  void sendUniverse(int universe, Uint8List dmxData) {
    if (!_isConnected || _socket == null) return;
    if (dmxData.length != 512) return;

    // sACN universes are 1-based.
    final sacnUniverse = universe + 1;

    // Increment sequence counter for this universe.
    final seq = (_sequenceCounters[sacnUniverse] ?? 0) + 1;
    _sequenceCounters[sacnUniverse] = seq > 255 ? 1 : seq;

    final priority = _priorities[sacnUniverse] ?? defaultPriority;

    final packet = SacnPacket.buildDataPacket(
      universe: sacnUniverse,
      dmxData: dmxData,
      priority: priority,
      sequence: _sequenceCounters[sacnUniverse]!,
      sourceName: sourceName,
      cid: cid,
    );

    if (useMulticast && !_unicastTargets.containsKey(sacnUniverse)) {
      // Multicast to the sACN multicast group for this universe.
      final multicastAddr = SacnPacket.multicastAddress(sacnUniverse);
      _socket!.send(
        packet,
        InternetAddress(multicastAddr),
        _port,
      );
    } else {
      // Unicast to specific IP.
      final ip = _unicastTargets[sacnUniverse] ?? _targetIp!;
      _socket!.send(
        packet,
        InternetAddress(ip),
        _port,
      );
    }
  }

  /// Disconnect and release the socket.
  void disconnect() {
    _socket?.close();
    _socket = null;
    _isConnected = false;
    _targetIp = null;
  }

  /// Disconnect a specific target IP (for API compatibility with TransportInterface).
  void disconnectTarget(String ip) {
    _unicastTargets.removeWhere((_, v) => v == ip);
    if (_unicastTargets.isEmpty && _targetIp == ip) {
      disconnect();
    }
  }

  /// Clean up resources.
  void dispose() {
    disconnect();
    _sequenceCounters.clear();
    _priorities.clear();
    _unicastTargets.clear();
  }
}
