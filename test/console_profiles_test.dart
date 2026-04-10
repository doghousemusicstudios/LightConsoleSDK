import 'package:test/test.dart';
import 'package:light_console_sdk/models/console_profile.dart';
import 'package:light_console_sdk/profiles/grandma3.dart';
import 'package:light_console_sdk/profiles/etc_eos.dart';
import 'package:light_console_sdk/profiles/chamsys_mq.dart';
import 'package:light_console_sdk/profiles/onyx.dart';
import 'package:light_console_sdk/discovery/console_profiles_registry.dart';

void main() {
  group('Console Profiles', () {
    group('GrandMA3', () {
      test('profile has correct ID', () {
        expect(grandMa3Profile.id, 'grandma3');
      });

      test('preferred protocol is OSC', () {
        expect(grandMa3Profile.preferredProtocol, ConsoleProtocol.osc);
      });

      test('fireCue uses command-based pattern', () {
        expect(grandMa3Profile.oscPatterns?.cueViaCommand, isTrue);
      });

      test('sendCommand address is /gma3/cmd', () {
        expect(grandMa3Profile.oscPatterns?.sendCommand, '/gma3/cmd');
      });

      test('setFader pattern resolves correctly', () {
        final pattern = grandMa3Profile.oscPatterns!.setFader!;
        final resolved = grandMa3Profile.oscPatterns!.resolve(
          pattern,
          {'page': '1', 'fader': '201'},
        );
        expect(resolved, contains('Page1'));
        expect(resolved, contains('Fader201'));
      });

      test('detection matches MA OEM codes', () {
        expect(
          grandMa3Profile.detection.matches(
            oemCode: 0x0001,
            shortName: 'anything',
            longName: 'anything',
          ),
          isTrue,
        );
      });

      test('detection matches name pattern', () {
        expect(
          grandMa3Profile.detection.matches(
            oemCode: 0xFFFF,
            shortName: 'gMA3',
            longName: 'grandMA3 Light',
          ),
          isTrue,
        );
      });
    });

    group('ETC Eos', () {
      test('profile has correct ID', () {
        expect(etcEosProfile.id, 'eos');
      });

      test('fireCue has dedicated address pattern', () {
        expect(etcEosProfile.oscPatterns?.fireCue, isNotNull);
        expect(etcEosProfile.oscPatterns?.cueViaCommand, isFalse);
      });

      test('fireCue resolves to /eos/cue/{list}/{cue}/fire', () {
        final pattern = etcEosProfile.oscPatterns!.fireCue!;
        final resolved = etcEosProfile.oscPatterns!.resolve(
          pattern,
          {'cueList': '1', 'cue': '3'},
        );
        expect(resolved, '/eos/cue/1/3/fire');
      });

      test('fireMacro resolves correctly', () {
        final pattern = etcEosProfile.oscPatterns!.fireMacro!;
        final resolved = etcEosProfile.oscPatterns!.resolve(
          pattern,
          {'macro': '5'},
        );
        expect(resolved, '/eos/macro/5/fire');
      });

      test('supports MSC', () {
        expect(etcEosProfile.midiSettings?.useMsc, isTrue);
      });
    });

    group('ChamSys MagicQ', () {
      test('profile has correct ID', () {
        expect(chamsysMqProfile.id, 'chamsys_mq');
      });

      test('fireCue resolves to /ch/playback/{pb}/go', () {
        final pattern = chamsysMqProfile.oscPatterns!.fireCue!;
        final resolved = chamsysMqProfile.oscPatterns!.resolve(
          pattern,
          {'pb': '1'},
        );
        expect(resolved, contains('/ch/playback/1/go'));
      });

      test('releasePlayback resolves correctly', () {
        final pattern = chamsysMqProfile.oscPatterns!.releasePlayback!;
        final resolved = chamsysMqProfile.oscPatterns!.resolve(
          pattern,
          {'pb': '3'},
        );
        expect(resolved, contains('3'));
        expect(resolved, contains('release'));
      });
    });

    group('Obsidian Onyx', () {
      test('profile has correct ID', () {
        expect(onyxProfile.id, 'onyx');
      });

      test('preferred protocol is OSC', () {
        expect(onyxProfile.preferredProtocol, ConsoleProtocol.osc);
      });

      test('supports MSC', () {
        expect(onyxProfile.midiSettings?.useMsc, isTrue);
      });
    });

    group('ConsoleDetectionPatterns', () {
      test('matches by OEM code', () {
        const patterns = ConsoleDetectionPatterns(oemCodes: [0x0068]);
        expect(
          patterns.matches(oemCode: 0x0068, shortName: '', longName: ''),
          isTrue,
        );
      });

      test('does not match wrong OEM code', () {
        const patterns = ConsoleDetectionPatterns(oemCodes: [0x0068]);
        expect(
          patterns.matches(oemCode: 0x0001, shortName: '', longName: ''),
          isFalse,
        );
      });

      test('matches by name pattern (case insensitive)', () {
        const patterns = ConsoleDetectionPatterns(namePatterns: ['grandMA']);
        expect(
          patterns.matches(oemCode: 0, shortName: 'GrandMA3', longName: ''),
          isTrue,
        );
      });

      test('matches by ESTA code', () {
        const patterns = ConsoleDetectionPatterns(estaCodes: [0x4D41]);
        expect(
          patterns.matches(
            oemCode: 0,
            shortName: '',
            longName: '',
            estaCode: 0x4D41,
          ),
          isTrue,
        );
      });

      test('no match returns false', () {
        const patterns = ConsoleDetectionPatterns(
          oemCodes: [0x0001],
          namePatterns: ['grandMA'],
        );
        expect(
          patterns.matches(oemCode: 0x9999, shortName: 'Other', longName: 'Console'),
          isFalse,
        );
      });
    });

    group('ConsoleOscPatterns template resolution', () {
      test('resolves single variable', () {
        const patterns = ConsoleOscPatterns(fireCue: '/cue/{cue}/fire');
        final result = patterns.resolve(patterns.fireCue!, {'cue': '5'});
        expect(result, '/cue/5/fire');
      });

      test('resolves multiple variables', () {
        const patterns = ConsoleOscPatterns(
          fireCue: '/eos/cue/{cueList}/{cue}/fire',
        );
        final result = patterns.resolve(
          patterns.fireCue!,
          {'cueList': '2', 'cue': '7.5'},
        );
        expect(result, '/eos/cue/2/7.5/fire');
      });

      test('unresolved variables remain in output', () {
        const patterns = ConsoleOscPatterns(fireCue: '/cue/{cue}/fire');
        final result = patterns.resolve(patterns.fireCue!, {});
        expect(result, '/cue/{cue}/fire');
      });
    });

    group('ConsoleProfilesRegistry', () {
      test('contains all 4 built-in profiles', () {
        final registry = ConsoleProfilesRegistry();
        expect(registry.getProfile('grandma3'), isNotNull);
        expect(registry.getProfile('eos'), isNotNull);
        expect(registry.getProfile('chamsys_mq'), isNotNull);
        expect(registry.getProfile('onyx'), isNotNull);
      });

      test('returns null for unknown ID', () {
        final registry = ConsoleProfilesRegistry();
        expect(registry.getProfile('nonexistent'), isNull);
      });

      test('custom profile can be registered', () {
        final registry = ConsoleProfilesRegistry();
        registry.register(const ConsoleProfile(
          id: 'custom',
          displayName: 'Custom Console',
          manufacturer: 'Test',
          preferredProtocol: ConsoleProtocol.osc,
          detection: ConsoleDetectionPatterns(),
        ));
        expect(registry.getProfile('custom'), isNotNull);
        expect(registry.getProfile('custom')?.displayName, 'Custom Console');
      });
    });

    group('Profile serialization', () {
      test('GrandMA3 survives toJson/fromJson', () {
        final json = grandMa3Profile.toJson();
        final restored = ConsoleProfile.fromJson(json);
        expect(restored.id, grandMa3Profile.id);
        expect(restored.displayName, grandMa3Profile.displayName);
        expect(restored.preferredProtocol, grandMa3Profile.preferredProtocol);
        expect(restored.oscPatterns?.cueViaCommand, isTrue);
      });

      test('ETC Eos survives toJson/fromJson', () {
        final json = etcEosProfile.toJson();
        final restored = ConsoleProfile.fromJson(json);
        expect(restored.id, etcEosProfile.id);
        expect(restored.midiSettings?.useMsc, isTrue);
      });
    });
  });
}
