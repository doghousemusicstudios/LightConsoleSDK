import 'dart:async';

import '../discovery/console_detector.dart';

/// Monitors the health of the console connection via heartbeat checks.
///
/// Emits [ConsoleHealthEvent]s when the console comes online, goes offline,
/// or reconnects after a dropout.
///
/// Two construction modes:
/// - `ConsoleHealthMonitor(detector:)` — derives state from ArtPoll discovery.
/// - `ConsoleHealthMonitor.fromStream()` — derives state from a
///   [ProtocolHeartbeat] or test stream. Tracks [isOnline] from events.
class ConsoleHealthMonitor {
  final ConsoleDetector? _detector;
  final StreamController<ConsoleHealthEvent> _eventController =
      StreamController<ConsoleHealthEvent>.broadcast();

  /// If provided, this external stream is used instead of the detector's
  /// state stream. Used with ProtocolHeartbeat or for testing.
  final Stream<ConsoleHealthEvent>? _externalEventStream;

  StreamSubscription<ConsoleConnectionState>? _stateSub;
  StreamSubscription<ConsoleHealthEvent>? _externalSub;
  DateTime? _lastOnlineAt;
  DateTime? _lastOfflineAt;
  Duration _uptime = Duration.zero;

  /// Tracked online state for fromStream mode. Updated by listening
  /// to the external stream's events.
  bool _streamOnline = false;

  ConsoleHealthMonitor({required ConsoleDetector detector})
      : _detector = detector,
        _externalEventStream = null;

  /// Creates a monitor that derives state from an external event stream.
  ///
  /// Use with [ProtocolHeartbeat.events] for protocol-level health, or
  /// with a [StreamController] for testing.
  ///
  /// Unlike the detector-based constructor, this mode tracks [isOnline]
  /// from the events it receives — it does not return a hardcoded false.
  ConsoleHealthMonitor.fromStream(Stream<ConsoleHealthEvent> eventStream)
      : _detector = null,
        _externalEventStream = eventStream;

  /// Stream of health events.
  Stream<ConsoleHealthEvent> get events {
    if (_externalEventStream != null) return _externalEventStream;
    return _eventController.stream;
  }

  /// Current uptime since last connection.
  Duration get uptime {
    if (_lastOnlineAt == null) return Duration.zero;
    if (_detector != null &&
        _detector.state == ConsoleConnectionState.offline) {
      return _uptime;
    }
    if (_detector == null && !_streamOnline) {
      return _uptime;
    }
    return DateTime.now().difference(_lastOnlineAt!);
  }

  /// Whether the console is currently online.
  ///
  /// In detector mode: derived from ConsoleDetector.state.
  /// In fromStream mode: derived from the last event received.
  bool get isOnline {
    if (_detector != null) {
      return _detector.state == ConsoleConnectionState.connected ||
          _detector.state == ConsoleConnectionState.detected ||
          _detector.state == ConsoleConnectionState.reconnected;
    }
    // fromStream mode — tracked from events.
    return _streamOnline;
  }

  /// Start monitoring.
  ///
  /// In detector mode: subscribes to the detector's state stream.
  /// In fromStream mode: subscribes to the external stream to track
  /// [isOnline] state and update timestamps.
  void start() {
    if (_detector != null) {
      _stateSub = _detector.stateStream.listen(_onStateChange);
    } else if (_externalEventStream != null) {
      _externalSub = _externalEventStream.listen(_onExternalEvent);
    }
  }

  void _onExternalEvent(ConsoleHealthEvent event) {
    switch (event.type) {
      case ConsoleHealthEventType.online:
      case ConsoleHealthEventType.reconnected:
        _streamOnline = true;
        _lastOnlineAt = event.timestamp;
      case ConsoleHealthEventType.offline:
        _streamOnline = false;
        _uptime = _lastOnlineAt != null
            ? event.timestamp.difference(_lastOnlineAt!)
            : Duration.zero;
        _lastOfflineAt = event.timestamp;
    }
  }

  void _onStateChange(ConsoleConnectionState state) {
    switch (state) {
      case ConsoleConnectionState.detected:
      case ConsoleConnectionState.connected:
        _lastOnlineAt = DateTime.now();
        _eventController.add(ConsoleHealthEvent(
          type: ConsoleHealthEventType.online,
          timestamp: DateTime.now(),
          consoleName: _detector?.lastDetection?.profile.displayName,
          consoleIp: _detector?.lastDetection?.node.ip,
        ));

      case ConsoleConnectionState.offline:
        _uptime = _lastOnlineAt != null
            ? DateTime.now().difference(_lastOnlineAt!)
            : Duration.zero;
        _lastOfflineAt = DateTime.now();
        _eventController.add(ConsoleHealthEvent(
          type: ConsoleHealthEventType.offline,
          timestamp: DateTime.now(),
          consoleName: _detector?.lastDetection?.profile.displayName,
          consoleIp: _detector?.lastDetection?.node.ip,
          uptimeBeforeOffline: _uptime,
        ));

      case ConsoleConnectionState.reconnected:
        final downtime = _lastOfflineAt != null
            ? DateTime.now().difference(_lastOfflineAt!)
            : Duration.zero;
        _lastOnlineAt = DateTime.now();
        _eventController.add(ConsoleHealthEvent(
          type: ConsoleHealthEventType.reconnected,
          timestamp: DateTime.now(),
          consoleName: _detector?.lastDetection?.profile.displayName,
          consoleIp: _detector?.lastDetection?.node.ip,
          downtimeDuration: downtime,
        ));

      case ConsoleConnectionState.none:
      case ConsoleConnectionState.configuring:
        break;
    }
  }

  /// Stop monitoring.
  void stop() {
    _stateSub?.cancel();
    _externalSub?.cancel();
  }

  void dispose() {
    stop();
    _eventController.close();
  }
}

/// A console health event.
class ConsoleHealthEvent {
  final ConsoleHealthEventType type;
  final DateTime timestamp;
  final String? consoleName;
  final String? consoleIp;
  final Duration? uptimeBeforeOffline;
  final Duration? downtimeDuration;

  const ConsoleHealthEvent({
    required this.type,
    required this.timestamp,
    this.consoleName,
    this.consoleIp,
    this.uptimeBeforeOffline,
    this.downtimeDuration,
  });
}

enum ConsoleHealthEventType { online, offline, reconnected }
