import 'dart:async';
import 'package:test/test.dart';
import 'package:light_console_sdk/models/coexistence_config.dart';
import 'package:light_console_sdk/models/universe_role.dart';
import 'package:light_console_sdk/health/failover_service.dart';
import 'package:light_console_sdk/health/console_health_monitor.dart';
import 'package:light_console_sdk/health/trigger_event_log.dart';
import 'package:light_console_sdk/models/console_trigger.dart';

void main() {
  group('FailoverService (production implementation)', () {
    late StreamController<ConsoleHealthEvent> events;
    late ConsoleHealthMonitor monitor;

    setUp(() {
      events = StreamController<ConsoleHealthEvent>.broadcast();
      monitor = ConsoleHealthMonitor.fromStream(events.stream);
    });

    tearDown(() {
      events.close();
    });

    test('does nothing when disabled', () async {
      final service = FailoverService(
        healthMonitor: monitor,
        config: const FailoverConfig(enabled: false),
      );
      service.onUniverseRolesChanged = (_) => fail('should not be called');
      service.onFailoverActivated = (_) => fail('should not be called');

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

    test('with requireConfirmation=true, does NOT auto-activate', () async {
      final service = FailoverService(
        healthMonitor: monitor,
        config: const FailoverConfig(enabled: true, requireConfirmation: true),
      );

      service.onUniverseRolesChanged = (_) => fail('should not auto-activate');
      service.onFailoverActivated = (_) => fail('should not auto-activate');

      List<int>? pendingUniverses;
      service.onConfirmationRequired = (u) => pendingUniverses = u;

      service.start({
        0: const UniverseConfig(universe: 0, role: UniverseRole.consoleOwned),
      });

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      // Should be pending, NOT active
      expect(service.isFailoverActive, isFalse);
      expect(service.isPendingConfirmation, isTrue);
      expect(pendingUniverses, [0]);
    });

    test('confirmFailover activates after pending', () async {
      final service = FailoverService(
        healthMonitor: monitor,
        config: const FailoverConfig(enabled: true, requireConfirmation: true),
      );

      Map<int, UniverseRole>? changedRoles;
      List<int>? activated;
      service.onConfirmationRequired = (_) {};
      service.onUniverseRolesChanged = (r) => changedRoles = r;
      service.onFailoverActivated = (u) => activated = u;

      service.start({
        0: const UniverseConfig(universe: 0, role: UniverseRole.consoleOwned),
        4: const UniverseConfig(universe: 4, role: UniverseRole.showupOwned),
      });

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(service.isPendingConfirmation, isTrue);
      service.confirmFailover();

      expect(service.isFailoverActive, isTrue);
      expect(service.isPendingConfirmation, isFalse);
      expect(changedRoles?[0], UniverseRole.showupOwned);
      expect(changedRoles?.containsKey(4), isFalse);
      expect(activated, [0]);
    });

    test('cancelFailover rejects pending failover', () async {
      final service = FailoverService(
        healthMonitor: monitor,
        config: const FailoverConfig(enabled: true, requireConfirmation: true),
      );

      service.onConfirmationRequired = (_) {};

      service.start({
        0: const UniverseConfig(universe: 0, role: UniverseRole.consoleOwned),
      });

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);
      expect(service.isPendingConfirmation, isTrue);

      service.cancelFailover();
      expect(service.isPendingConfirmation, isFalse);
      expect(service.isFailoverActive, isFalse);
    });

    test('console reconnect cancels pending confirmation', () async {
      final service = FailoverService(
        healthMonitor: monitor,
        config: const FailoverConfig(enabled: true, requireConfirmation: true),
      );

      service.onConfirmationRequired = (_) {};

      service.start({
        0: const UniverseConfig(universe: 0, role: UniverseRole.consoleOwned),
      });

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);
      expect(service.isPendingConfirmation, isTrue);

      // Console comes back while waiting for confirmation
      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.online,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(service.isPendingConfirmation, isFalse);
      expect(service.isFailoverActive, isFalse);
    });

    test('with requireConfirmation=false, activates immediately', () async {
      final service = FailoverService(
        healthMonitor: monitor,
        config: const FailoverConfig(enabled: true, requireConfirmation: false),
      );

      Map<int, UniverseRole>? changedRoles;
      List<int>? activated;
      service.onUniverseRolesChanged = (r) => changedRoles = r;
      service.onFailoverActivated = (u) => activated = u;

      service.start({
        0: const UniverseConfig(universe: 0, role: UniverseRole.consoleOwned),
        1: const UniverseConfig(universe: 1, role: UniverseRole.consoleOwned),
      });

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(service.isFailoverActive, isTrue);
      expect(changedRoles?[0], UniverseRole.showupOwned);
      expect(changedRoles?[1], UniverseRole.showupOwned);
      expect(activated, [0, 1]);
    });

    test('restores universe roles on reconnect', () async {
      final service = FailoverService(
        healthMonitor: monitor,
        config: const FailoverConfig(enabled: true, requireConfirmation: false),
      );

      List<int>? deactivated;
      service.onUniverseRolesChanged = (_) {};
      service.onFailoverActivated = (_) {};
      service.onFailoverDeactivated = (u) => deactivated = u;

      service.start({
        0: const UniverseConfig(universe: 0, role: UniverseRole.consoleOwned),
      });

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.reconnected,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(service.isFailoverActive, isFalse);
      expect(deactivated, [0]);
    });

    test('does not double-activate', () async {
      final service = FailoverService(
        healthMonitor: monitor,
        config: const FailoverConfig(enabled: true, requireConfirmation: false),
      );

      int count = 0;
      service.onUniverseRolesChanged = (_) {};
      service.onFailoverActivated = (_) => count++;

      service.start({
        0: const UniverseConfig(universe: 0, role: UniverseRole.consoleOwned),
      });

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);
      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(count, 1);
    });

    test('stop() deactivates active failover', () async {
      final service = FailoverService(
        healthMonitor: monitor,
        config: const FailoverConfig(enabled: true, requireConfirmation: false),
      );

      List<int>? deactivated;
      service.onUniverseRolesChanged = (_) {};
      service.onFailoverActivated = (_) {};
      service.onFailoverDeactivated = (u) => deactivated = u;

      service.start({
        0: const UniverseConfig(universe: 0, role: UniverseRole.consoleOwned),
      });

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      service.stop();
      expect(service.isFailoverActive, isFalse);
      expect(deactivated, [0]);
    });

    test('exposes fade timing from config', () {
      final service = FailoverService(
        healthMonitor: monitor,
        config: const FailoverConfig(
          enabled: true,
          fadeInMs: 5000,
          fadeBackMs: 3000,
          fallbackMode: FailoverMode.ambient,
        ),
      );

      expect(service.fadeInMs, 5000);
      expect(service.fadeBackMs, 3000);
      expect(service.fallbackMode, FailoverMode.ambient);
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
      expect(snapshots[0], hasLength(1));
    });
  });
}
