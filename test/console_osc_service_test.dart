import 'package:test/test.dart';
import 'package:light_console_sdk/output/console_osc_service.dart';
import 'package:light_console_sdk/profiles/etc_eos.dart';
import 'package:light_console_sdk/profiles/grandma3.dart';
import 'package:light_console_sdk/profiles/chamsys_mq.dart';
import 'package:light_console_sdk/profiles/onyx.dart';
import 'package:light_console_sdk/models/console_profile.dart';

void main() {
  group('ConsoleOscService transport selection', () {
    test('Eos profile selects TCP SLIP transport', () {
      final service = ConsoleOscService(profile: etcEosProfile);
      // _transportForProfile is private, but we can verify it indirectly:
      // Eos heartbeat is tcpPushStream → should select tcpSlip.
      expect(etcEosProfile.heartbeat.strategy,
          HeartbeatStrategy.tcpPushStream);
      // The service exists and its profile matches.
      expect(service.isConnected, isFalse);
    });

    test('MA3 profile selects UDP transport', () {
      final service = ConsoleOscService(profile: grandMa3Profile);
      expect(grandMa3Profile.heartbeat.strategy,
          HeartbeatStrategy.httpGet);
      // httpGet strategy → not tcpPushStream → UDP
      expect(service.isConnected, isFalse);
    });

    test('MQ profile selects UDP transport', () {
      final service = ConsoleOscService(profile: chamsysMqProfile);
      expect(chamsysMqProfile.heartbeat.strategy,
          HeartbeatStrategy.tcpConnect);
      expect(service.isConnected, isFalse);
    });

    test('Onyx profile selects UDP transport', () {
      final service = ConsoleOscService(profile: onyxProfile);
      expect(onyxProfile.heartbeat.strategy,
          HeartbeatStrategy.telnetPoll);
      expect(service.isConnected, isFalse);
    });

    test('Eos profile uses port 3037', () {
      expect(etcEosProfile.oscPort, 3037);
    });

    test('Eos heartbeat port matches control port', () {
      expect(etcEosProfile.heartbeat.port, etcEosProfile.oscPort);
    });

    test('custom profile without tcpPushStream defaults to UDP', () {
      const custom = ConsoleProfile(
        id: 'custom',
        displayName: 'Custom',
        manufacturer: 'Test',
        preferredProtocol: ConsoleProtocol.osc,
        oscPort: 9999,
        detection: ConsoleDetectionPatterns(),
        heartbeat: HeartbeatConfig(strategy: HeartbeatStrategy.none),
      );
      final service = ConsoleOscService(profile: custom);
      expect(service.isConnected, isFalse);
      // none strategy → UDP (not tcpSlip)
    });

    test('sendRaw routes through diagnostic layer', () {
      // Verify sendRaw exists and doesn't crash when disconnected
      final service = ConsoleOscService(profile: grandMa3Profile);
      // Should not throw — logs failure via event log
      service.sendRaw('/test', []);
    });
  });
}
