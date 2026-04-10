import 'dart:async';

import 'console_profiles_registry.dart';
import '../models/console_profile.dart';

/// Information about an Art-Net node discovered on the network.
///
/// This is a simplified representation that the SDK can consume
/// without depending on ShowUp's ArtNetNode class directly.
class DiscoveredNode {
  /// IP address of the node.
  final String ip;

  /// Short name from ArtPollReply (max 18 chars).
  final String shortName;

  /// Long name from ArtPollReply (max 64 chars).
  final String longName;

  /// OEM code from ArtPollReply.
  final int oemCode;

  /// ESTA manufacturer code.
  final int estaCode;

  /// Number of output ports.
  final int numPorts;

  /// Active output universe numbers (parsed from SwOut + NetSwitch).
  final List<int> activeUniverses;

  const DiscoveredNode({
    required this.ip,
    required this.shortName,
    required this.longName,
    required this.oemCode,
    this.estaCode = 0,
    this.numPorts = 0,
    this.activeUniverses = const [],
  });
}

/// Result of console detection: the matched profile and the node that matched.
class ConsoleDetectionResult {
  /// The detected console's profile.
  final ConsoleProfile profile;

  /// The network node that matched.
  final DiscoveredNode node;

  /// Timestamp of detection.
  final DateTime detectedAt;

  const ConsoleDetectionResult({
    required this.profile,
    required this.node,
    required this.detectedAt,
  });
}

/// Connection state of a detected console.
enum ConsoleConnectionState {
  /// No console detected on the network.
  none,

  /// Console detected but coexistence not configured.
  detected,

  /// Coexistence wizard is running.
  configuring,

  /// Console detected and coexistence fully configured.
  connected,

  /// Console was connected but has stopped responding.
  offline,

  /// Console was offline but has come back.
  reconnected,
}

/// Detects lighting consoles on the network by watching an ArtPoll
/// discovery stream and matching against known console profiles.
///
/// The detector wraps ShowUp's existing ArtPoll discovery mechanism.
/// ShowUp provides a `Stream<DiscoveredNode>` and the SDK matches
/// against its registry of console profiles.
class ConsoleDetector {
  final ConsoleProfilesRegistry _registry;
  final StreamController<ConsoleDetectionResult> _detectionController =
      StreamController<ConsoleDetectionResult>.broadcast();
  final StreamController<ConsoleConnectionState> _stateController =
      StreamController<ConsoleConnectionState>.broadcast();

  ConsoleDetectionResult? _lastDetection;
  ConsoleConnectionState _state = ConsoleConnectionState.none;
  StreamSubscription<DiscoveredNode>? _discoverySubscription;
  Timer? _heartbeatTimer;
  DateTime? _lastSeen;

  /// Heartbeat timeout — if no ArtPoll reply is seen for this duration,
  /// the console is considered offline.
  final Duration heartbeatTimeout;

  ConsoleDetector({
    ConsoleProfilesRegistry? registry,
    this.heartbeatTimeout = const Duration(seconds: 10),
  }) : _registry = registry ?? ConsoleProfilesRegistry();

  /// The profile registry used for matching.
  ConsoleProfilesRegistry get registry => _registry;

  /// Stream of console detection events.
  Stream<ConsoleDetectionResult> get detectionStream =>
      _detectionController.stream;

  /// Stream of connection state changes.
  Stream<ConsoleConnectionState> get stateStream => _stateController.stream;

  /// Current connection state.
  ConsoleConnectionState get state => _state;

  /// The most recent detection result, if any.
  ConsoleDetectionResult? get lastDetection => _lastDetection;

  /// Start watching an ArtPoll discovery stream for consoles.
  ///
  /// The [discoveryStream] should emit [DiscoveredNode] objects as they
  /// are discovered by ShowUp's ArtNetService. This method can be called
  /// multiple times — it cancels the previous subscription.
  void startWatching(Stream<DiscoveredNode> discoveryStream) {
    _discoverySubscription?.cancel();
    _discoverySubscription = discoveryStream.listen(_onNodeDiscovered);
    _startHeartbeatMonitor();
  }

  /// Stop watching for consoles.
  void stopWatching() {
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Manually check a node against known profiles.
  ConsoleDetectionResult? checkNode(DiscoveredNode node) {
    final profile = _registry.detectFromArtPoll(
      oemCode: node.oemCode,
      shortName: node.shortName,
      longName: node.longName,
      estaCode: node.estaCode,
    );
    if (profile == null) return null;
    return ConsoleDetectionResult(
      profile: profile,
      node: node,
      detectedAt: DateTime.now(),
    );
  }

  void _onNodeDiscovered(DiscoveredNode node) {
    final result = checkNode(node);
    if (result == null) return;

    _lastSeen = DateTime.now();
    _lastDetection = result;

    if (_state == ConsoleConnectionState.none ||
        _state == ConsoleConnectionState.offline) {
      final newState = _state == ConsoleConnectionState.offline
          ? ConsoleConnectionState.reconnected
          : ConsoleConnectionState.detected;
      _setState(newState);
    }

    _detectionController.add(result);
  }

  void _startHeartbeatMonitor() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkHeartbeat(),
    );
  }

  void _checkHeartbeat() {
    if (_lastSeen == null) return;
    if (_state == ConsoleConnectionState.none) return;

    final elapsed = DateTime.now().difference(_lastSeen!);
    if (elapsed > heartbeatTimeout &&
        _state != ConsoleConnectionState.none &&
        _state != ConsoleConnectionState.offline) {
      _setState(ConsoleConnectionState.offline);
    }
  }

  void _setState(ConsoleConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  /// Manually set the connection state (e.g., when user completes wizard).
  void setConfigured() => _setState(ConsoleConnectionState.connected);

  /// Reset detection state.
  void reset() {
    _lastDetection = null;
    _lastSeen = null;
    _setState(ConsoleConnectionState.none);
  }

  void dispose() {
    stopWatching();
    _detectionController.close();
    _stateController.close();
  }
}
