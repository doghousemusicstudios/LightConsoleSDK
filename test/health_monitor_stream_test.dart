import 'dart:async';
import 'package:test/test.dart';
import 'package:light_console_sdk/health/console_health_monitor.dart';

/// Tests for ConsoleHealthMonitor in fromStream mode.
/// Verifies that isOnline, uptime, and event tracking work correctly
/// when driven by an external stream (ProtocolHeartbeat or test stream).
void main() {
  group('ConsoleHealthMonitor.fromStream', () {
    late StreamController<ConsoleHealthEvent> events;
    late ConsoleHealthMonitor monitor;

    setUp(() {
      events = StreamController<ConsoleHealthEvent>.broadcast();
      monitor = ConsoleHealthMonitor.fromStream(events.stream);
      monitor.start();
    });

    tearDown(() {
      monitor.dispose();
      events.close();
    });

    test('starts with isOnline = false', () {
      expect(monitor.isOnline, isFalse);
    });

    test('isOnline becomes true on online event', () async {
      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.online,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);
      expect(monitor.isOnline, isTrue);
    });

    test('isOnline becomes false on offline event', () async {
      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.online,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);
      expect(monitor.isOnline, isTrue);

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);
      expect(monitor.isOnline, isFalse);
    });

    test('isOnline becomes true on reconnected event', () async {
      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.online,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);
      expect(monitor.isOnline, isFalse);

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.reconnected,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);
      expect(monitor.isOnline, isTrue);
    });

    test('uptime is zero before any events', () {
      expect(monitor.uptime, Duration.zero);
    });

    test('uptime grows after online event', () async {
      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.online,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(monitor.uptime.inMilliseconds, greaterThan(0));
    });

    test('uptime freezes after offline event', () async {
      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.online,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(const Duration(milliseconds: 20));

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.offline,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      final frozenUptime = monitor.uptime;
      await Future.delayed(const Duration(milliseconds: 20));
      // Uptime should not grow while offline
      expect(monitor.uptime, frozenUptime);
    });

    test('events stream relays external events', () async {
      final received = <ConsoleHealthEvent>[];
      monitor.events.listen(received.add);

      events.add(ConsoleHealthEvent(
        type: ConsoleHealthEventType.online,
        timestamp: DateTime.now(),
      ));
      await Future.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received[0].type, ConsoleHealthEventType.online);
    });
  });
}
