import 'package:test/test.dart';
import 'package:light_console_sdk/models/console_trigger.dart';
import 'package:light_console_sdk/output/trigger_router.dart';
import 'package:light_console_sdk/output/telnet_client.dart';

void main() {
  group('TriggerRouter Telnet execution', () {
    test('telnet binding with no client returns showupOnly gracefully', () {
      final router = TriggerRouter(
        bindings: {
          'moment1': const ConsoleTriggerBinding(
            sourceId: 'moment1',
            action: ConsoleTriggerAction.fireCue,
            protocol: TriggerProtocol.telnet,
            params: {'cueList': '1', 'cueNumber': '3'},
          ),
        },
      );

      // No telnet client configured — should not crash, should return
      // the binding's execution mode (both) regardless.
      final result = router.onMomentActivated('moment1');
      expect(result, TriggerExecutionMode.both);
    });

    test('telnet binding logs failure when no client', () async {
      final router = TriggerRouter(
        bindings: {
          'moment1': const ConsoleTriggerBinding(
            sourceId: 'moment1',
            action: ConsoleTriggerAction.fireCue,
            protocol: TriggerProtocol.telnet,
          ),
        },
      );

      final events = <TriggerEvent>[];
      router.eventLog.listen(events.add);

      router.onMomentActivated('moment1');
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].success, isFalse);
      expect(events[0].error, 'No Telnet client configured');
      expect(events[0].protocol, TriggerProtocol.telnet);
    });

    test('telnet binding logs failure when client disconnected', () async {
      // TelnetClient starts disconnected by default
      final router = TriggerRouter(
        telnetClient: TelnetClient(autoReconnect: false),
        bindings: {
          'moment1': const ConsoleTriggerBinding(
            sourceId: 'moment1',
            action: ConsoleTriggerAction.fireCue,
            protocol: TriggerProtocol.telnet,
            params: {'cueList': '1', 'cueNumber': '5'},
          ),
        },
      );

      final events = <TriggerEvent>[];
      router.eventLog.listen(events.add);

      router.onMomentActivated('moment1');
      await Future.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events[0].success, isFalse);
      expect(events[0].error, 'Telnet not connected');
    });
  });

  group('TriggerProtocol enum', () {
    test('telnet is a valid protocol', () {
      expect(TriggerProtocol.values, contains(TriggerProtocol.telnet));
    });

    test('telnet serialization round-trip', () {
      const binding = ConsoleTriggerBinding(
        sourceId: 'test',
        action: ConsoleTriggerAction.fireCue,
        protocol: TriggerProtocol.telnet,
      );
      final restored = ConsoleTriggerBinding.fromJson(binding.toJson());
      expect(restored.protocol, TriggerProtocol.telnet);
    });
  });
}

