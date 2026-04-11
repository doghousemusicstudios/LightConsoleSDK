import 'dart:async';

import '../discovery/console_detector.dart';

/// Monitors the health of the console connection via heartbeat checks.
///
/// Emits [ConsoleHealthEvent]s when the console comes online, goes offline,
/// or reconnects after a dropout.
class ConsoleHealthMonitor {
  final ConsoleDetector? _detector;
  final StreamController<ConsoleHealthEvent> _eventController =
      StreamController<ConsoleHealthEvent>.broadcast();

  /// If provided, this external stream is used instead of the detector's
  /// state stream. Used for testing without a real ConsoleDetector.
  final Stream<ConsoleHealthEvent>? _externalEventStream;

  StreamSubscription<ConsoleConnectionState>? _stateSub;
  StreamSubscription<ConsoleHealthEvent>? _externalSub;
  DateTime? _lastOnlineAt;
  DateTime? _lastOfflineAt;
  Duration _uptime = Duration.zero;

  ConsoleHealthMonitor({required ConsoleDetector detector})
      : _detector = detector,
        _externalEventStream = null;

  /// Creates a monitor that emits events from an external stream.
  /// Used for testing FailoverService without a real ConsoleDetector.
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
    return DateTime.now().difference(_lastOnlineAt!);
  }

  /// Whether the console is currently online.
  bool get isOnline {
    if (_detector == null) return false;
    return _detector.state == ConsoleConnectionState.connected ||
        _detector.state == ConsoleConnectionState.detected ||
        _detector.state == ConsoleConnectionState.reconnected;
  }

  /// Start monitoring.
  void start() {
    if (_detector != null) {
      _stateSub = _detector.stateStream.listen(_onStateChange);
    }
    // fromStream monitors use the stream directly via events getter.
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
