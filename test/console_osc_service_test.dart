import 'package:test/test.dart';
import 'package:light_console_sdk/output/console_osc_service.dart';
import 'package:light_console_sdk/output/osc_client.dart';
import 'package:light_console_sdk/profiles/etc_eos.dart';
import 'package:light_console_sdk/profiles/grandma3.dart';
import 'package:light_console_sdk/profiles/chamsys_mq.dart';
import 'package:light_console_sdk/profiles/onyx.dart';
import 'package:light_console_sdk/models/console_profile.dart';

/// OscClient that records the transport passed to connect().
class _RecordingOscClient extends OscClient {
  OscTransport? lastTransport;
  int? lastPort;

  @override
  Future<void> connect(String ip, int port,
      {OscTransport transport = OscTransport.udp}) async {
    lastTransport = transport;
    lastPort = port;
    // Don't actually connect — just record what was requested.
  }
}

void main() {
  group('ConsoleOscService transport selection', () {
    test('Eos connect() passes tcpSlip transport', () async {
      final recorder = _RecordingOscClient();
      final service = ConsoleOscService(
        profile: etcEosProfile,
        client: recorder,
      );
      await service.connect('127.0.0.1');
      expect(recorder.lastTransport, OscTransport.tcpSlip);
      expect(recorder.lastPort, 3037);
    });

    test('MA3 connect() passes udp transport', () async {
      final recorder = _RecordingOscClient();
      final service = ConsoleOscService(
        profile: grandMa3Profile,
        client: recorder,
      );
      await service.connect('127.0.0.1');
      expect(recorder.lastTransport, OscTransport.udp);
    });

    test('MQ connect() passes udp transport', () async {
      final recorder = _RecordingOscClient();
      final service = ConsoleOscService(
        profile: chamsysMqProfile,
        client: recorder,
      );
      await service.connect('127.0.0.1');
      expect(recorder.lastTransport, OscTransport.udp);
    });

    test('Onyx connect() passes udp transport', () async {
      final recorder = _RecordingOscClient();
      final service = ConsoleOscService(
        profile: onyxProfile,
        client: recorder,
      );
      await service.connect('127.0.0.1');
      expect(recorder.lastTransport, OscTransport.udp);
    });

    test('explicit transport override takes precedence', () async {
      final recorder = _RecordingOscClient();
      final service = ConsoleOscService(
        profile: grandMa3Profile, // would normally be UDP
        client: recorder,
      );
      await service.connect('127.0.0.1', transport: OscTransport.tcpSlip);
      expect(recorder.lastTransport, OscTransport.tcpSlip);
    });

    test('custom profile with none heartbeat defaults to UDP', () async {
      final recorder = _RecordingOscClient();
      const custom = ConsoleProfile(
        id: 'custom',
        displayName: 'Custom',
        manufacturer: 'Test',
        preferredProtocol: ConsoleProtocol.osc,
        oscPort: 9999,
        detection: ConsoleDetectionPatterns(),
        heartbeat: HeartbeatConfig(strategy: HeartbeatStrategy.none),
      );
      final service = ConsoleOscService(profile: custom, client: recorder);
      await service.connect('127.0.0.1');
      expect(recorder.lastTransport, OscTransport.udp);
      expect(recorder.lastPort, 9999);
    });

    test('Eos profile uses port 3037', () {
      expect(etcEosProfile.oscPort, 3037);
    });

    test('Eos heartbeat port matches control port', () {
      expect(etcEosProfile.heartbeat.port, etcEosProfile.oscPort);
    });

    test('sendRaw routes through diagnostic layer when disconnected', () {
      final service = ConsoleOscService(profile: grandMa3Profile);
      // Should not throw — logs failure via event log
      service.sendRaw('/test', []);
    });
  });
}
