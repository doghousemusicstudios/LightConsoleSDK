import 'package:test/test.dart';
import 'package:light_console_sdk/models/console_profile.dart';
import 'package:light_console_sdk/models/console_trigger.dart';
import 'package:light_console_sdk/output/http_console_client.dart';
import 'package:light_console_sdk/output/trigger_router.dart';
import 'package:light_console_sdk/profiles/avolites_titan.dart';
import 'package:light_console_sdk/discovery/console_profiles_registry.dart';

void main() {
  group('Avolites Titan Profile', () {
    test('profile has correct ID', () {
      expect(avolitesProfile.id, 'avolites_titan');
    });

    test('preferred protocol is HTTP', () {
      expect(avolitesProfile.preferredProtocol, ConsoleProtocol.http);
    });

    test('no OSC port (Titan does not support OSC)', () {
      expect(avolitesProfile.oscPort, isNull);
    });

    test('no OSC patterns', () {
      expect(avolitesProfile.oscPatterns, isNull);
    });

    test('supports MIDI Show Control', () {
      expect(avolitesProfile.midiSettings?.useMsc, isTrue);
    });

    test('heartbeat is httpGet on port 4430', () {
      expect(avolitesProfile.heartbeat.strategy, HeartbeatStrategy.httpGet);
      expect(avolitesProfile.heartbeat.port, 4430);
    });

    test('heartbeat path queries software version', () {
      expect(avolitesProfile.heartbeat.httpPath,
          '/titan/get/System/SoftwareVersion');
    });

    test('detection patterns include avolites and titan', () {
      expect(
        avolitesProfile.detection.matches(
          oemCode: 0xFFFF,
          shortName: 'Titan',
          longName: 'Avolites Tiger Touch',
        ),
        isTrue,
      );
    });

    test('detection matches by OEM code', () {
      expect(
        avolitesProfile.detection.matches(
          oemCode: 0x4176,
          shortName: '',
          longName: '',
        ),
        isTrue,
      );
    });

    test('registered in profiles registry', () {
      final registry = ConsoleProfilesRegistry();
      expect(registry.getProfile('avolites_titan'), isNotNull);
      expect(registry.getProfile('avolites_titan')?.displayName,
          'Avolites Titan');
    });

    test('registry now has 5 built-in profiles', () {
      final registry = ConsoleProfilesRegistry();
      expect(registry.profiles.length, 5);
    });

    test('serialization round-trip', () {
      final json = avolitesProfile.toJson();
      final restored = ConsoleProfile.fromJson(json);
      expect(restored.id, 'avolites_titan');
      expect(restored.preferredProtocol, ConsoleProtocol.http);
      expect(restored.heartbeat.strategy, HeartbeatStrategy.httpGet);
      expect(restored.heartbeat.port, 4430);
    });

    test('titanWebApiPort constant', () {
      expect(titanWebApiPort, 4430);
    });
  });

  group('ConsoleProtocol.http', () {
    test('http is a valid protocol', () {
      expect(ConsoleProtocol.values, contains(ConsoleProtocol.http));
    });

    test('serialization round-trip', () {
      const connection = ConsoleConnection(
        ip: '192.168.1.50',
        httpPort: 4430,
        protocol: ConsoleProtocol.http,
      );
      final restored = ConsoleConnection.fromJson(connection.toJson());
      expect(restored.protocol, ConsoleProtocol.http);
      expect(restored.httpPort, 4430);
      expect(restored.activePort, 4430);
    });

    test('activePort defaults to 4430 for HTTP', () {
      const connection = ConsoleConnection(
        ip: '192.168.1.50',
        protocol: ConsoleProtocol.http,
      );
      expect(connection.activePort, 4430);
    });
  });

  group('TriggerProtocol.http', () {
    test('http is a valid trigger protocol', () {
      expect(TriggerProtocol.values, contains(TriggerProtocol.http));
    });

    test('serialization round-trip', () {
      const binding = ConsoleTriggerBinding(
        sourceId: 'test',
        action: ConsoleTriggerAction.fireCue,
        protocol: TriggerProtocol.http,
        params: {'cueNumber': '1'},
      );
      final restored = ConsoleTriggerBinding.fromJson(binding.toJson());
      expect(restored.protocol, TriggerProtocol.http);
    });
  });

  group('HttpConsoleClient', () {
    test('starts disconnected', () {
      final client = HttpConsoleClient();
      expect(client.isConnected, isFalse);
      expect(client.ip, isNull);
    });

    test('default port is 4430', () {
      final client = HttpConsoleClient();
      expect(client.port, 4430);
    });

    test('connect to unreachable host returns false', () async {
      final client = HttpConsoleClient(
        requestTimeout: const Duration(seconds: 1),
      );
      final result = await client.connect('192.0.2.1', port: 4430);
      expect(result, isFalse);
      expect(client.isConnected, isFalse);
    });

    test('ping returns false when disconnected', () async {
      final client = HttpConsoleClient();
      expect(await client.ping(), isFalse);
    });

    test('dispose cleans up', () {
      final client = HttpConsoleClient();
      client.dispose();
      expect(client.isConnected, isFalse);
    });
  });

  group('TriggerRouter HTTP execution', () {
    test('http binding with no client logs failure', () async {
      final router = TriggerRouter(
        bindings: {
          'moment1': const ConsoleTriggerBinding(
            sourceId: 'moment1',
            action: ConsoleTriggerAction.fireCue,
            protocol: TriggerProtocol.http,
            params: {'cueNumber': '1'},
          ),
        },
      );

      final events = <TriggerEvent>[];
      router.eventLog.listen(events.add);
      router.onMomentActivated('moment1');
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].success, isFalse);
      expect(events[0].error, 'No HTTP client configured');
      expect(events[0].protocol, TriggerProtocol.http);
    });

    test('http binding with disconnected client logs failure', () async {
      final router = TriggerRouter(
        httpClient: HttpConsoleClient(),
        bindings: {
          'moment1': const ConsoleTriggerBinding(
            sourceId: 'moment1',
            action: ConsoleTriggerAction.fireCue,
            protocol: TriggerProtocol.http,
            params: {'cueNumber': '5'},
          ),
        },
      );

      final events = <TriggerEvent>[];
      router.eventLog.listen(events.add);
      router.onMomentActivated('moment1');
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].success, isFalse);
      expect(events[0].error, 'HTTP client not connected');
    });

    test('http binding returns correct execution mode', () {
      final router = TriggerRouter(
        bindings: {
          'cue1': const ConsoleTriggerBinding(
            sourceId: 'cue1',
            action: ConsoleTriggerAction.fireCue,
            protocol: TriggerProtocol.http,
            executionMode: TriggerExecutionMode.consoleOnly,
          ),
        },
      );

      final mode = router.onMomentActivated('cue1');
      expect(mode, TriggerExecutionMode.consoleOnly);
    });
  });

  group('TitanProviders', () {
    test('has standard providers', () {
      expect(TitanProviders.playbacks, 'Playbacks');
      expect(TitanProviders.fixtures, 'Fixtures');
      expect(TitanProviders.masters, 'Masters');
      expect(TitanProviders.system, 'System');
      expect(TitanProviders.show, 'Show');
    });
  });
}
