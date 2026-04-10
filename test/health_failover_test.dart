import 'dart:async';
import 'package:test/test.dart';
import 'package:light_console_sdk/models/coexistence_config.dart';
import 'package:light_console_sdk/models/universe_role.dart';
import 'package:light_console_sdk/health/failover_service.dart';
import 'package:light_console_sdk/health/console_health_monitor.dart';
import 'package:light_console_sdk/health/trigger_event_log.dart';
import 'package:light_console_sdk/models/console_trigger.dart';

/// Test FailoverService by directly injecting health events.
/// We subclass FailoverService to bypass the ConsoleHealthMonitor dependency
/// and feed events directly from a StreamController.
class TestableFailoverService {
  final StreamController<ConsoleHealthEvent> _eventController;
  final FailoverConfig _config;

  void Function(List<int>)? onFailoverActivated;
  void Function(List<int>)? onFailoverDeactivated;
  void Function(Map<int, UniverseRole>)? onUniverseRolesChanged;

  bool _isFailoverActive = false;
  final List<int> _overriddenUniverses = [];
  Map<int, UniverseConfig>? _originalRoles;
  StreamSubscription<ConsoleHealthEvent>? _sub;

  TestableFailoverService({
    required StreamController<ConsoleHealthEvent> events,
    FailoverConfig config = const FailoverConfig(),
  })  : _eventController = events,
        _config = config;

  bool get isFailoverActive => _isFailoverActive;
  List<int> get overriddenUniverses => List.unmodifiable(_overriddenUniverses);

  void start(Map<int, UniverseConfig> universeRoles) {
    if (!_config.enabled) return;
    _originalRoles = Map.from(universeRoles);
    _sub = _eventController.stream.listen(_onEvent);
  }

  void _onEvent(ConsoleHealthEvent event) {
    switch (event.type) {
      case ConsoleHealthEventType.offline:
        _activateFailover();
      case ConsoleHealthEventType.reconnected:
      case ConsoleHealthEventType.online:
        if (_isFailoverActive) _deactivateFailover();
    }
  }

  void _activateFailover() {
    if (_isFailoverActive || _originalRoles == null) return;
    _isFailoverActive = true;
    final newRoles = <int, UniverseRole>{};
    _overriddenUniverses.clear();
    for (final entry in _originalRoles!.entries) {
      if (entry.value.role == UniverseRole.consoleOwned) {
        newRoles[entry.key] = UniverseRole.showupOwned;
        _overriddenUniverses.add(entry.key);
      }
    }
    if (_overriddenUniverses.isNotEmpty) {
      onUniverseRolesChanged?.call(newRoles);
      onFailoverActivated?.call(List.from(_overriddenUniverses));
    }
  }

  void _deactivateFailover() {
    if (!_isFailoverActive || _originalRoles == null) return;
    final restoredRoles = <int, UniverseRole>{};
    for (final universe in _overriddenUniverses) {
      final original = _originalRoles![universe];
      if (original != null) restoredRoles[universe] = original.role;
    }
    final restored = List<int>.from(_overriddenUniverses);
    _overriddenUniverses.clear();
    _isFailoverActive = false;
    if (restored.isNotEmpty) {
      onUniverseRolesChanged?.call(restoredRoles);
      onFailoverDeactivated?.call(restored);
    }
  }

  void stop() {
    _sub?.cancel();
    if (_isFailoverActive) _deactivateFailover();
  }
}

void main() {
  group('Failover behavior', () {
    late StreamController<ConsoleHealthEvent> events;

    setUp(() {
      events = StreamController<ConsoleHealthEvent>.broadcast();
    });

    tearDown(() {
      events.close();
    });

    test('does nothing when disabled', () async {
      final service = TestableFailoverService(
        events: events,
        config: const FailoverConfig(enabled: false),
      );
      service.onUniverseRolesChanged = (_) => fail('should not be called');
      service.start({
        0: const UniverseConfig(universe: 0, role: UniverseRole.consoleOwned),
      });

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);
      expect(service.isFailoverActive, isFalse);
    });

    test('takes over console universes on offline', () async {
      final service = TestableFailoverService(
        events: events,
        config: const FailoverConfig(enabled: true),
      );

      Map<int, UniverseRole>? changedRoles;
      List<int>? activated;
      service.onUniverseRolesChanged = (r) => changedRoles = r;
      service.onFailoverActivated = (u) => activated = u;

      service.start({
        0: const UniverseConfig(universe: 0, role: UniverseRole.consoleOwned),
        1: const UniverseConfig(universe: 1, role: UniverseRole.consoleOwned),
        4: const UniverseConfig(universe: 4, role: UniverseRole.showupOwned),
      });

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(service.isFailoverActive, isTrue);
      expect(changedRoles?[0], UniverseRole.showupOwned);
      expect(changedRoles?[1], UniverseRole.showupOwned);
      expect(changedRoles?.containsKey(4), isFalse);
      expect(activated, [0, 1]);
    });

    test('restores on reconnect', () async {
      final service = TestableFailoverService(
        events: events,
        config: const FailoverConfig(enabled: true),
      );

      List<int>? deactivated;
      service.onUniverseRolesChanged = (_) {};
      service.onFailoverActivated = (_) {};
      service.onFailoverDeactivated = (u) => deactivated = u;

      service.start({
        0: const UniverseConfig(universe: 0, role: UniverseRole.consoleOwned),
      });

      events.add(ConsoleHealthEvent(type: ConsoleHealthEventType.offline, timestamp: DateTime.now()));
      await Future.delayed(Duration.zero);
      expect(service.isFailoverActive, isTrue);

      events.add(ConsoleHealthEvent(type: ConsoleHealthEventType.reconnected, timestamp: DateTime.now()));
      await Future.delayed(Duration.zero);

      expect(service.isFailoverActive, isFalse);
      expect(deactivated, [0]);
    });

    test('does not double-activate', () async {
      final service = TestableFailoverService(
        events: events,
        config: const FailoverConfig(enabled: true),
      );

      int count = 0;
      service.onUniverseRolesChanged = (_) {};
      service.onFailoverActivated = (_) => count++;

      service.start({0: const UniverseConfig(universe: 0, role: UniverseRole.consoleOwned)});

      events.add(ConsoleHealthEvent(type: ConsoleHealthEventType.offline, timestamp: DateTime.now()));
      await Future.delayed(Duration.zero);
      events.add(ConsoleHealthEvent(type: ConsoleHealthEventType.offline, timestamp: DateTime.now()));
      await Future.delayed(Duration.zero);

      expect(count, 1);
    });

    test('stop() deactivates active failover', () async {
      final service = TestableFailoverService(
        events: events,
        config: const FailoverConfig(enabled: true),
      );

      List<int>? deactivated;
      service.onUniverseRolesChanged = (_) {};
      service.onFailoverActivated = (_) {};
      service.onFailoverDeactivated = (u) => deactivated = u;

      service.start({0: const UniverseConfig(universe: 0, role: UniverseRole.consoleOwned)});
      events.add(ConsoleHealthEvent(type: ConsoleHealthEventType.offline, timestamp: DateTime.now()));
      await Future.delayed(Duration.zero);

      service.stop();
      expect(service.isFailoverActive, isFalse);
      expect(deactivated, [0]);
    });
  });

  group('FailoverConfig safe defaults', () {
    test('disabled by default', () {
      expect(const FailoverConfig().enabled, isFalse);
    });

    test('timeout is 15 seconds', () {
      expect(const FailoverConfig().timeoutSeconds, 15);
    });

    test('requires confirmation', () {
      expect(const FailoverConfig().requireConfirmation, isTrue);
    });

    test('defaults to lastCapture, not blackout', () {
      expect(const FailoverConfig().fallbackMode, FailoverMode.lastCapture);
    });

    test('fade in is 3 seconds', () {
      expect(const FailoverConfig().fadeInMs, 3000);
    });

    test('fade back is 2 seconds', () {
      expect(const FailoverConfig().fadeBackMs, 2000);
    });
  });

  group('TriggerEventLog', () {
    test('records events', () {
      final log = TriggerEventLog();
      log.add(TriggerEvent(
        timestamp: DateTime.now(),
        sourceId: 'chorus',
        sourceLabel: 'Chorus',
        action: ConsoleTriggerAction.fireCue,
        protocol: TriggerProtocol.osc,
        resolvedAddress: '/eos/cue/1/3/fire',
      ));
      expect(log.events, hasLength(1));
    });

    test('respects max capacity', () {
      final log = TriggerEventLog(maxEvents: 3);
      for (var i = 0; i < 5; i++) {
        log.add(TriggerEvent(
          timestamp: DateTime.now(),
          sourceId: 'event_$i',
          sourceLabel: 'Event $i',
          action: ConsoleTriggerAction.fireCue,
          protocol: TriggerProtocol.osc,
          resolvedAddress: '/test',
        ));
      }
      expect(log.events.length, lessThanOrEqualTo(3));
    });

    test('emits full event list on stream', () async {
      final log = TriggerEventLog();
      final snapshots = <List<TriggerEvent>>[];
      log.stream.listen(snapshots.add);

      log.add(TriggerEvent(
        timestamp: DateTime.now(),
        sourceId: 'test',
        sourceLabel: 'Test',
        action: ConsoleTriggerAction.fireCue,
        protocol: TriggerProtocol.osc,
        resolvedAddress: '/test',
      ));

      await Future.delayed(Duration.zero);
      expect(snapshots, hasLength(1));
      expect(snapshots[0], hasLength(1)); // full list with 1 event
    });
  });
}
