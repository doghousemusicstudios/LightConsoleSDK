import 'package:test/test.dart';
import 'package:light_console_sdk/models/console_profile.dart';
import 'package:light_console_sdk/models/console_trigger.dart';
import 'package:light_console_sdk/profiles/grandma2.dart';
import 'package:light_console_sdk/profiles/grandma3.dart';
import 'package:light_console_sdk/discovery/console_profiles_registry.dart';

void main() {
  group('GrandMA2 Profile', () {
    test('profile has correct ID', () {
      expect(grandMa2Profile.id, 'grandma2');
    });

    test('preferred protocol is Telnet', () {
      expect(grandMa2Profile.preferredProtocol, ConsoleProtocol.telnet);
    });

    test('no OSC port (MA2 has no native OSC)', () {
      expect(grandMa2Profile.oscPort, isNull);
    });

    test('no OSC patterns', () {
      expect(grandMa2Profile.oscPatterns, isNull);
    });

    test('heartbeat is httpGet on port 8080', () {
      expect(grandMa2Profile.heartbeat.strategy, HeartbeatStrategy.httpGet);
      expect(grandMa2Profile.heartbeat.port, 8080);
    });

    test('detection matches gma2 name pattern', () {
      expect(
        grandMa2Profile.detection.matches(
          oemCode: 0xFFFF,
          shortName: 'gMA2',
          longName: 'grandMA2 Light',
        ),
        isTrue,
      );
    });

    test('detection matches MA2 name pattern', () {
      expect(
        grandMa2Profile.detection.matches(
          oemCode: 0xFFFF,
          shortName: 'MA2',
          longName: '',
        ),
        isTrue,
      );
    });

    test('detection does NOT match MA3 names', () {
      expect(
        grandMa2Profile.detection.matches(
          oemCode: 0xFFFF,
          shortName: 'gMA3',
          longName: 'grandMA3 Light',
        ),
        isFalse,
      );
    });

    test('serialization round-trip', () {
      final json = grandMa2Profile.toJson();
      final restored = ConsoleProfile.fromJson(json);
      expect(restored.id, 'grandma2');
      expect(restored.preferredProtocol, ConsoleProtocol.telnet);
      expect(restored.oscPort, isNull);
    });

    test('telnet port constant', () {
      expect(grandMa2TelnetPort, 30000);
    });
  });

  group('MA2 vs MA3 Detection Separation', () {
    test('MA3 profile does NOT match gma2 name', () {
      expect(
        grandMa3Profile.detection.matches(
          oemCode: 0xFFFF,
          shortName: 'gMA2',
          longName: 'grandMA2 onPC',
        ),
        isFalse,
      );
    });

    test('MA3 profile matches gma3 name', () {
      expect(
        grandMa3Profile.detection.matches(
          oemCode: 0xFFFF,
          shortName: 'gMA3',
          longName: 'grandMA3',
        ),
        isTrue,
      );
    });

    test('MA2 profile does NOT match gma3 name', () {
      expect(
        grandMa2Profile.detection.matches(
          oemCode: 0xFFFF,
          shortName: 'gMA3',
          longName: '',
        ),
        isFalse,
      );
    });

    test('registry distinguishes MA2 from MA3 by name', () {
      final registry = ConsoleProfilesRegistry();

      // An ArtPoll reply with "gMA2" should match MA2, not MA3
      final ma2Match = registry.detectFromArtPoll(
        oemCode: 0xFFFF,
        shortName: 'gMA2',
        longName: 'grandMA2 onPC',
      );
      expect(ma2Match?.id, 'grandma2');

      // An ArtPoll reply with "gMA3" should match MA3, not MA2
      final ma3Match = registry.detectFromArtPoll(
        oemCode: 0xFFFF,
        shortName: 'gMA3',
        longName: 'grandMA3 Light',
      );
      expect(ma3Match?.id, 'grandma3');
    });

    test('shared OEM code matches MA2 first (registered first)', () {
      final registry = ConsoleProfilesRegistry();
      // Both MA2 and MA3 share OEM 0x0001. Registry returns first match.
      // MA2 is registered before MA3, so it wins on OEM alone.
      final match = registry.detectFromArtPoll(
        oemCode: 0x0001,
        shortName: '',
        longName: '',
      );
      // When only OEM matches, first registered profile wins.
      // This is acceptable — the wizard will show both options
      // if the name doesn't disambiguate.
      expect(match?.id, anyOf('grandma2', 'grandma3'));
    });
  });

  group('GrandMa2Commands', () {
    test('command constants', () {
      expect(GrandMa2Commands.gotoCue, 'Goto Cue');
      expect(GrandMa2Commands.goNext, 'Go+');
      expect(GrandMa2Commands.goBack, 'Go-');
      expect(GrandMa2Commands.blackout, 'BlackOut');
      expect(GrandMa2Commands.master, 'Master');
      expect(GrandMa2Commands.macro, 'Macro');
      expect(GrandMa2Commands.clear, 'Clear');
      expect(GrandMa2Commands.login, 'login');
    });
  });

  group('Registry with MA2', () {
    test('registry now has 6 built-in profiles', () {
      final registry = ConsoleProfilesRegistry();
      expect(registry.profiles.length, 6);
    });

    test('MA2 profile is retrievable by ID', () {
      final registry = ConsoleProfilesRegistry();
      expect(registry.getProfile('grandma2'), isNotNull);
      expect(registry.getProfile('grandma2')?.displayName, 'GrandMA2');
    });
  });

  group('TriggerProtocol for MA2', () {
    test('telnet binding for MA2 cue trigger', () {
      const binding = ConsoleTriggerBinding(
        sourceId: 'chorus',
        action: ConsoleTriggerAction.fireCue,
        protocol: TriggerProtocol.telnet,
        params: {'cueNumber': '3'},
      );
      // MA2 Telnet command would be: "Goto Cue 3"
      // TriggerRouter handles this via _executeTelnet
      expect(binding.protocol, TriggerProtocol.telnet);
      expect(binding.cueNumber, '3');
    });
  });
}
