import 'dart:convert';
import 'package:test/test.dart';
import 'package:light_console_sdk/models/coexistence_config.dart';
import 'package:light_console_sdk/models/universe_role.dart';

void main() {
  group('CoexistenceConfig', () {
    group('V1 safety gate', () {
      test('solo is V1 safe', () {
        const config = CoexistenceConfig(mode: CoexistenceMode.solo);
        expect(config.isV1Safe, isTrue);
      });

      test('sideBySide is V1 safe', () {
        const config = CoexistenceConfig(mode: CoexistenceMode.sideBySide);
        expect(config.isV1Safe, isTrue);
      });

      test('triggerOnly is V1 safe', () {
        const config = CoexistenceConfig(mode: CoexistenceMode.triggerOnly);
        expect(config.isV1Safe, isTrue);
      });

      test('layered is NOT V1 safe', () {
        const config = CoexistenceConfig(mode: CoexistenceMode.layered);
        expect(config.isV1Safe, isFalse);
      });
    });

    group('shouldOutput — universe role enforcement', () {
      test('triggerOnly mode never outputs on any universe', () {
        const config = CoexistenceConfig(
          mode: CoexistenceMode.triggerOnly,
          universeRoles: {
            0: UniverseConfig(universe: 0, role: UniverseRole.showupOwned),
            1: UniverseConfig(universe: 1, role: UniverseRole.consoleOwned),
          },
        );
        // Even showupOwned universes get no output in trigger mode
        expect(config.shouldOutput(0), isFalse);
        expect(config.shouldOutput(1), isFalse);
        expect(config.shouldOutput(99), isFalse);
      });

      test('layered mode blocks all output (V1 safety)', () {
        const config = CoexistenceConfig(
          mode: CoexistenceMode.layered,
          universeRoles: {
            0: UniverseConfig(universe: 0, role: UniverseRole.showupOwned),
            1: UniverseConfig(universe: 1, role: UniverseRole.shared),
          },
        );
        expect(config.shouldOutput(0), isFalse);
        expect(config.shouldOutput(1), isFalse);
      });

      test('sideBySide outputs on showupOwned universes', () {
        const config = CoexistenceConfig(
          mode: CoexistenceMode.sideBySide,
          universeRoles: {
            0: UniverseConfig(universe: 0, role: UniverseRole.showupOwned),
            1: UniverseConfig(universe: 1, role: UniverseRole.consoleOwned),
          },
        );
        expect(config.shouldOutput(0), isTrue);
        expect(config.shouldOutput(1), isFalse);
      });

      test('sideBySide does NOT output on consoleOwned', () {
        const config = CoexistenceConfig(
          mode: CoexistenceMode.sideBySide,
          universeRoles: {
            0: UniverseConfig(universe: 0, role: UniverseRole.consoleOwned),
          },
        );
        expect(config.shouldOutput(0), isFalse);
      });

      test('unassigned universes default to ShowUp output', () {
        const config = CoexistenceConfig(mode: CoexistenceMode.sideBySide);
        // Universe 99 has no role assignment
        expect(config.shouldOutput(99), isTrue);
      });

      test('solo mode outputs on everything', () {
        const config = CoexistenceConfig(mode: CoexistenceMode.solo);
        expect(config.shouldOutput(0), isTrue);
        expect(config.shouldOutput(15), isTrue);
      });
    });

    group('priorityFor', () {
      test('returns configured priority', () {
        const config = CoexistenceConfig(
          universeRoles: {
            0: UniverseConfig(
                universe: 0, role: UniverseRole.shared, sacnPriority: 50),
          },
        );
        expect(config.priorityFor(0), 50);
      });

      test('returns default 100 for unconfigured universe', () {
        const config = CoexistenceConfig();
        expect(config.priorityFor(99), 100);
      });
    });

    group('serialization round-trip', () {
      test('full config survives toJson/fromJson', () {
        const config = CoexistenceConfig(
          mode: CoexistenceMode.sideBySide,
          consoleProfileId: 'grandma3',
          universeRoles: {
            0: UniverseConfig(
              universe: 0,
              role: UniverseRole.consoleOwned,
              label: 'Stage',
            ),
            4: UniverseConfig(
              universe: 4,
              role: UniverseRole.showupOwned,
              sacnPriority: 80,
            ),
          },
          failover: FailoverConfig(
            enabled: true,
            timeoutSeconds: 15,
            requireConfirmation: false,
          ),
        );

        final json = config.toJson();
        final restored = CoexistenceConfig.fromJson(json);

        expect(restored.mode, CoexistenceMode.sideBySide);
        expect(restored.consoleProfileId, 'grandma3');
        expect(restored.universeRoles[0]?.role, UniverseRole.consoleOwned);
        expect(restored.universeRoles[0]?.label, 'Stage');
        expect(restored.universeRoles[4]?.role, UniverseRole.showupOwned);
        expect(restored.universeRoles[4]?.sacnPriority, 80);
        expect(restored.failover.enabled, isTrue);
        expect(restored.failover.timeoutSeconds, 15);
        expect(restored.failover.requireConfirmation, isFalse);
      });

      test('survives JSON encode/decode cycle', () {
        const config = CoexistenceConfig(
          mode: CoexistenceMode.triggerOnly,
          consoleProfileId: 'etc_eos',
        );

        final jsonString = jsonEncode(config.toJson());
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        final restored = CoexistenceConfig.fromJson(decoded);

        expect(restored.mode, CoexistenceMode.triggerOnly);
        expect(restored.consoleProfileId, 'etc_eos');
      });

      test('missing fields default safely', () {
        final config = CoexistenceConfig.fromJson({});
        expect(config.mode, CoexistenceMode.solo);
        expect(config.consoleProfileId, isNull);
        expect(config.universeRoles, isEmpty);
        expect(config.failover.enabled, isFalse);
        expect(config.failover.timeoutSeconds, 15);
        expect(config.failover.requireConfirmation, isTrue);
      });

      test('unknown keys are ignored (backward compatibility)', () {
        final config = CoexistenceConfig.fromJson({
          'mode': 'sideBySide',
          'futureField': 'should not crash',
          'anotherNewThing': 42,
        });
        expect(config.mode, CoexistenceMode.sideBySide);
      });

      test('unknown mode value defaults to solo', () {
        final config = CoexistenceConfig.fromJson({
          'mode': 'someNewModeFromFuture',
        });
        expect(config.mode, CoexistenceMode.solo);
      });
    });
  });

  group('FailoverConfig', () {
    test('defaults are safe', () {
      const config = FailoverConfig();
      expect(config.enabled, isFalse, reason: 'Failover should be off by default');
      expect(config.timeoutSeconds, 15, reason: 'Timeout should be conservative');
      expect(config.requireConfirmation, isTrue, reason: 'Should require operator confirmation');
      expect(config.fallbackMode, FailoverMode.lastCapture, reason: 'Should default to last capture, not blackout');
      expect(config.fadeInMs, 3000, reason: 'Should fade in, not snap');
      expect(config.fadeBackMs, 2000, reason: 'Should fade back, not snap');
    });

    test('serialization preserves all fields', () {
      const config = FailoverConfig(
        enabled: true,
        timeoutSeconds: 20,
        fallbackMode: FailoverMode.ambient,
        fadeBackMs: 3000,
        requireConfirmation: false,
        fadeInMs: 5000,
      );

      final restored = FailoverConfig.fromJson(config.toJson());

      expect(restored.enabled, isTrue);
      expect(restored.timeoutSeconds, 20);
      expect(restored.fallbackMode, FailoverMode.ambient);
      expect(restored.fadeBackMs, 3000);
      expect(restored.requireConfirmation, isFalse);
      expect(restored.fadeInMs, 5000);
    });
  });

  group('UniverseConfig', () {
    test('serialization round-trip', () {
      const config = UniverseConfig(
        universe: 3,
        role: UniverseRole.shared,
        sacnPriority: 50,
        label: 'Ambient',
      );

      final restored = UniverseConfig.fromJson(config.toJson());
      expect(restored.universe, 3);
      expect(restored.role, UniverseRole.shared);
      expect(restored.sacnPriority, 50);
      expect(restored.label, 'Ambient');
    });

    test('default priority is 100', () {
      const config = UniverseConfig(
        universe: 0,
        role: UniverseRole.showupOwned,
      );
      expect(config.sacnPriority, 100);
    });
  });
}
