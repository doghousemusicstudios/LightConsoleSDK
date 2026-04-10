import 'dart:async';
import 'dart:typed_data';

import 'artnet_receiver.dart';
import 'sacn_receiver.dart';

/// Unified DMX input service that merges sACN and Art-Net receivers
/// into a single stream interface.
///
/// Provides:
///   - Per-universe DMX data streams
///   - Per-universe activity level monitoring
///   - Snapshot capture (freeze current state of all universes)
class DmxInputService {
  final SacnReceiver _sacnReceiver;
  final ArtNetReceiver _artNetReceiver;

  /// Last received DMX data per universe (1-based key).
  final Map<int, Uint8List> _currentState = {};

  /// Last received timestamp per universe.
  final Map<int, DateTime> _lastReceived = {};

  /// Activity level per universe (0.0 = silent, 1.0 = full data).
  final Map<int, double> _activityLevels = {};

  final StreamController<DmxInputFrame> _mergedController =
      StreamController<DmxInputFrame>.broadcast();
  final StreamController<Map<int, double>> _activityController =
      StreamController<Map<int, double>>.broadcast();

  StreamSubscription<DmxInputFrame>? _sacnSub;
  StreamSubscription<DmxInputFrame>? _artNetSub;
  Timer? _activityTimer;

  DmxInputService({
    SacnReceiver? sacnReceiver,
    ArtNetReceiver? artNetReceiver,
  })  : _sacnReceiver = sacnReceiver ?? SacnReceiver(),
        _artNetReceiver = artNetReceiver ?? ArtNetReceiver();

  /// Stream of all incoming DMX frames (from both sACN and Art-Net).
  Stream<DmxInputFrame> get frames => _mergedController.stream;

  /// Stream of per-universe activity levels, updated periodically.
  /// Key = universe (1-based), value = 0.0 to 1.0.
  Stream<Map<int, double>> get activityStream => _activityController.stream;

  /// Current activity levels snapshot.
  Map<int, double> get activityLevels => Map.unmodifiable(_activityLevels);

  /// Start receiving DMX input.
  ///
  /// [sacnUniverses] — sACN universes to subscribe to (1-based).
  /// [listenArtNet] — whether to also listen for Art-Net input.
  Future<void> start({
    List<int> sacnUniverses = const [],
    bool listenArtNet = false,
  }) async {
    if (sacnUniverses.isNotEmpty) {
      await _sacnReceiver.start(sacnUniverses);
      _sacnSub = _sacnReceiver.frames.listen(_onFrame);
    }

    if (listenArtNet) {
      await _artNetReceiver.start();
      _artNetSub = _artNetReceiver.frames.listen(_onFrame);
    }

    // Activity level updater (10Hz)
    _activityTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _updateActivityLevels(),
    );
  }

  /// Get a stream of DMX data for a specific universe.
  Stream<Uint8List> universeStream(int universe) {
    return _mergedController.stream
        .where((f) => f.universe == universe)
        .map((f) => f.data);
  }

  /// Check if a universe is actively receiving data.
  bool isUniverseActive(int universe) {
    final lastTime = _lastReceived[universe];
    if (lastTime == null) return false;
    return DateTime.now().difference(lastTime).inSeconds < 3;
  }

  /// Capture the current DMX state of all active universes.
  ///
  /// Returns a map of universe (1-based) → 512-byte DMX data.
  Map<int, Uint8List> captureNow() {
    final snapshot = <int, Uint8List>{};
    for (final entry in _currentState.entries) {
      snapshot[entry.key] = Uint8List.fromList(entry.value);
    }
    return snapshot;
  }

  /// Get the last received DMX data for a specific universe.
  Uint8List? getUniverse(int universe) => _currentState[universe];

  void _onFrame(DmxInputFrame frame) {
    _currentState[frame.universe] = frame.data;
    _lastReceived[frame.universe] = frame.timestamp;
    _mergedController.add(frame);
  }

  void _updateActivityLevels() {
    final now = DateTime.now();
    var changed = false;

    for (final entry in _currentState.entries) {
      final lastTime = _lastReceived[entry.key];
      if (lastTime == null) continue;

      final age = now.difference(lastTime).inMilliseconds;
      double level;

      if (age > 3000) {
        level = 0.0;
      } else {
        // Calculate activity from DMX data (average non-zero channels)
        var nonZero = 0;
        for (var i = 0; i < 512; i++) {
          if (entry.value[i] > 0) nonZero++;
        }
        level = nonZero / 512.0;
      }

      if (_activityLevels[entry.key] != level) {
        _activityLevels[entry.key] = level;
        changed = true;
      }
    }

    if (changed) {
      _activityController.add(Map.unmodifiable(_activityLevels));
    }
  }

  /// Stop all receivers.
  void stop() {
    _sacnSub?.cancel();
    _artNetSub?.cancel();
    _activityTimer?.cancel();
    _sacnReceiver.stop();
    _artNetReceiver.stop();
    _currentState.clear();
    _lastReceived.clear();
    _activityLevels.clear();
  }

  void dispose() {
    stop();
    _mergedController.close();
    _activityController.close();
    _sacnReceiver.dispose();
    _artNetReceiver.dispose();
  }
}
