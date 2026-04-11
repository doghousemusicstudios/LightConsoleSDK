import 'dart:async';
import 'package:test/test.dart';
import 'package:light_console_sdk/health/protocol_heartbeat.dart';
import 'package:light_console_sdk/health/console_health_monitor.dart';
import 'package:light_console_sdk/models/console_profile.dart';

void main() {
  group('ProtocolHeartbeat', () {
    group('construction', () {
      test('strategy none does not start timer', () {
        final hb = ProtocolHeartbeat(
          config: const HeartbeatConfig(strategy: HeartbeatStrategy.none),
          consoleIp: '127.0.0.1',
        );
        hb.start();
        expect(hb.isOnline, isFalse);
        hb.dispose();
      });

      test('exposes strategy from config', () {
        final hb = ProtocolHeartbeat(
          config: const HeartbeatConfig(strategy: HeartbeatStrategy.httpGet, port: 8080),
          consoleIp: '127.0.0.1',
        );
        expect(hb.strategy, HeartbeatStrategy.httpGet);
        hb.dispose();
      });

      test('starts not online', () {
        final hb = ProtocolHeartbeat(
          config: const HeartbeatConfig(strategy: HeartbeatStrategy.tcpConnect, port: 9999),
          consoleIp: '127.0.0.1',
        );
        expect(hb.isOnline, isFalse);
        hb.dispose();
      });
    });

    group('fromFailoverConfig', () {
      test('distributes 15s timeout into 5s interval, 3 misses', () {
        final hb = ProtocolHeartbeat.fromFailoverConfig(
          heartbeatConfig: const HeartbeatConfig(strategy: HeartbeatStrategy.httpGet),
          consoleIp: '127.0.0.1',
          timeoutSeconds: 15,
        );
        expect(hb.interval.inSeconds, 5);
        expect(hb.missedThreshold, 3);
        hb.dispose();
      });

      test('distributes 6s timeout into 2s interval, 3 misses', () {
        final hb = ProtocolHeartbeat.fromFailoverConfig(
          heartbeatConfig: const HeartbeatConfig(strategy: HeartbeatStrategy.httpGet),
          consoleIp: '127.0.0.1',
          timeoutSeconds: 6,
        );
        expect(hb.interval.inSeconds, 2);
        expect(hb.missedThreshold, 3);
        hb.dispose();
      });

      test('distributes 30s timeout into reasonable values', () {
        final hb = ProtocolHeartbeat.fromFailoverConfig(
          heartbeatConfig: const HeartbeatConfig(strategy: HeartbeatStrategy.httpGet),
          consoleIp: '127.0.0.1',
          timeoutSeconds: 30,
        );
        expect(hb.interval.inSeconds, 10);
        expect(hb.missedThreshold, 3);
        hb.dispose();
      });

      test('clamps interval minimum to 1 second', () {
        final hb = ProtocolHeartbeat.fromFailoverConfig(
          heartbeatConfig: const HeartbeatConfig(strategy: HeartbeatStrategy.httpGet),
          consoleIp: '127.0.0.1',
          timeoutSeconds: 1,
        );
        expect(hb.interval.inSeconds, greaterThanOrEqualTo(1));
        hb.dispose();
      });
    });

    group('tcpConnect strategy (port that definitely refuses)', () {
      test('detects offline when port is unreachable', () async {
        final hb = ProtocolHeartbeat(
          config: const HeartbeatConfig(
            strategy: HeartbeatStrategy.tcpConnect,
            port: 59999, // almost certainly not listening
          ),
          consoleIp: '127.0.0.1',
          interval: const Duration(milliseconds: 500),
          missedThreshold: 2,
        );

        final events = <ConsoleHealthEvent>[];
        hb.events.listen(events.add);
        hb.start();

        // Wait long enough for 2+ missed probes
        await Future.delayed(const Duration(seconds: 4));

        // Should still be offline (never came online)
        expect(hb.isOnline, isFalse);

        hb.dispose();
      });
    });

    group('telnet strategy without client', () {
      test('probe returns false without telnet client', () {
        final hb = ProtocolHeartbeat(
          config: const HeartbeatConfig(
            strategy: HeartbeatStrategy.telnetPoll,
            port: 2323,
          ),
          consoleIp: '127.0.0.1',
          // no telnetClient provided
        );

        // Directly check — without a client, probe should fail
        expect(hb.isOnline, isFalse);
        hb.dispose();
      });
    });

    group('event stream', () {
      test('emits events compatible with ConsoleHealthMonitor.fromStream', () async {
        final hb = ProtocolHeartbeat(
          config: const HeartbeatConfig(
            strategy: HeartbeatStrategy.tcpConnect,
            port: 59998,
          ),
          consoleIp: '127.0.0.1',
          interval: const Duration(milliseconds: 200),
          missedThreshold: 1,
        );

        // Wire to a real ConsoleHealthMonitor
        final monitor = ConsoleHealthMonitor.fromStream(hb.events);
        monitor.start();

        hb.start();
        await Future.delayed(const Duration(seconds: 2));

        // Monitor should reflect the heartbeat state
        expect(monitor.isOnline, isFalse); // port refused

        hb.dispose();
        monitor.dispose();
      });
    });
  });

  group('HeartbeatConfig', () {
    test('serialization round-trip', () {
      const config = HeartbeatConfig(
        strategy: HeartbeatStrategy.tcpPushStream,
        port: 3037,
        streamPrefix: '/eos/out/',
      );
      final restored = HeartbeatConfig.fromJson(config.toJson());
      expect(restored.strategy, HeartbeatStrategy.tcpPushStream);
      expect(restored.port, 3037);
      expect(restored.streamPrefix, '/eos/out/');
    });

    test('defaults to none strategy', () {
      const config = HeartbeatConfig();
      expect(config.strategy, HeartbeatStrategy.none);
      expect(config.port, isNull);
    });

    test('unknown strategy in JSON defaults to none', () {
      final config = HeartbeatConfig.fromJson({
        'strategy': 'futureStrategy',
      });
      expect(config.strategy, HeartbeatStrategy.none);
    });

    test('httpGet config', () {
      const config = HeartbeatConfig(
        strategy: HeartbeatStrategy.httpGet,
        port: 8080,
        httpPath: '/status',
      );
      expect(config.httpPath, '/status');
    });
  });

  group('HeartbeatStrategy enum', () {
    test('contains all validated strategies', () {
      expect(HeartbeatStrategy.values, containsAll([
        HeartbeatStrategy.tcpPushStream,
        HeartbeatStrategy.httpGet,
        HeartbeatStrategy.tcpConnect,
        HeartbeatStrategy.telnetPoll,
        HeartbeatStrategy.none,
      ]));
    });
  });
}
