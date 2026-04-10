import 'console_profile.dart';
import 'console_trigger.dart';
import 'universe_role.dart';

/// How ShowUp and the console share control of the lighting rig.
enum CoexistenceMode {
  /// No console — ShowUp controls everything (default, current behavior).
  solo,

  /// ShowUp and console each own separate universes. No overlap.
  /// Best for: church volunteer running ShowUp on LED strips while
  /// the house console handles conventionals.
  sideBySide,

  /// ShowUp only sends triggers (OSC/MIDI) to the console.
  /// ShowUp does NOT output any DMX — the console handles all fixture control.
  /// Best for: operator who wants ShowUp's moment interface but has all
  /// fixtures on the console.
  triggerOnly,

  /// ShowUp adds a reactive layer with lower sACN priority.
  /// Console output takes precedence via priority-based merging.
  /// Best for: concert venue where ShowUp runs ambient/reactive effects
  /// and the touring LD's console overrides for their show.
  layered,
}

/// Full coexistence configuration, persisted in the stage file.
///
/// This is the single source of truth for how ShowUp interacts with
/// a lighting console at a venue.
class CoexistenceConfig {
  /// Active coexistence mode.
  final CoexistenceMode mode;

  /// Which console profile is active.
  final String? consoleProfileId;

  /// Resolved console profile (populated at runtime, not persisted).
  final ConsoleProfile? consoleProfile;

  /// Console connection details.
  final ConsoleConnection? consoleConnection;

  /// Per-universe role assignments. Key = universe index (0-based).
  final Map<int, UniverseConfig> universeRoles;

  /// Trigger bindings: momentId/macroId → console command.
  final Map<String, ConsoleTriggerBinding> triggerBindings;

  /// Failover settings.
  final FailoverConfig failover;

  /// sACN-specific output targets.
  final List<SacnTarget> sacnTargets;

  const CoexistenceConfig({
    this.mode = CoexistenceMode.solo,
    this.consoleProfileId,
    this.consoleProfile,
    this.consoleConnection,
    this.universeRoles = const {},
    this.triggerBindings = const {},
    this.failover = const FailoverConfig(),
    this.sacnTargets = const [],
  });

  /// Whether coexistence is active (not solo mode).
  bool get isActive => mode != CoexistenceMode.solo;

  /// V1-safe modes: sideBySide and triggerOnly.
  /// Layer mode requires sACN channel masking (not yet implemented)
  /// and MUST NOT be shipped until SacnTransport supports per-channel
  /// output strategy. See RISKS_AND_MITIGATIONS.md RISK-01.
  static const _v1SafeModes = {
    CoexistenceMode.solo,
    CoexistenceMode.sideBySide,
    CoexistenceMode.triggerOnly,
  };

  /// Whether the current mode is safe to ship in V1.
  bool get isV1Safe => _v1SafeModes.contains(mode);

  /// Whether ShowUp should output DMX on a given universe.
  bool shouldOutput(int universe) {
    if (mode == CoexistenceMode.triggerOnly) return false;

    // V1 safety: layered mode is not safe until channel masking is
    // implemented in SacnTransport. Block all output in layered mode.
    if (mode == CoexistenceMode.layered) return false;

    final config = universeRoles[universe];
    if (config == null) return true; // unassigned = ShowUp controls
    return config.role != UniverseRole.consoleOwned;
  }

  /// Get the sACN priority for a given universe.
  int priorityFor(int universe) {
    final config = universeRoles[universe];
    return config?.sacnPriority ?? 100;
  }

  CoexistenceConfig copyWith({
    CoexistenceMode? mode,
    String? consoleProfileId,
    ConsoleProfile? consoleProfile,
    ConsoleConnection? consoleConnection,
    Map<int, UniverseConfig>? universeRoles,
    Map<String, ConsoleTriggerBinding>? triggerBindings,
    FailoverConfig? failover,
    List<SacnTarget>? sacnTargets,
  }) =>
      CoexistenceConfig(
        mode: mode ?? this.mode,
        consoleProfileId: consoleProfileId ?? this.consoleProfileId,
        consoleProfile: consoleProfile ?? this.consoleProfile,
        consoleConnection: consoleConnection ?? this.consoleConnection,
        universeRoles: universeRoles ?? this.universeRoles,
        triggerBindings: triggerBindings ?? this.triggerBindings,
        failover: failover ?? this.failover,
        sacnTargets: sacnTargets ?? this.sacnTargets,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        if (consoleProfileId != null) 'consoleProfileId': consoleProfileId,
        if (consoleConnection != null)
          'consoleConnection': consoleConnection!.toJson(),
        'universeRoles': {
          for (final entry in universeRoles.entries)
            '${entry.key}': entry.value.toJson(),
        },
        'triggerBindings': {
          for (final entry in triggerBindings.entries)
            entry.key: entry.value.toJson(),
        },
        'failover': failover.toJson(),
        'sacnTargets': sacnTargets.map((t) => t.toJson()).toList(),
      };

  factory CoexistenceConfig.fromJson(Map<String, dynamic> json) {
    final rolesJson = json['universeRoles'] as Map<String, dynamic>? ?? {};
    final triggersJson =
        json['triggerBindings'] as Map<String, dynamic>? ?? {};

    return CoexistenceConfig(
      mode: CoexistenceMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => CoexistenceMode.solo,
      ),
      consoleProfileId: json['consoleProfileId'] as String?,
      consoleConnection: json['consoleConnection'] != null
          ? ConsoleConnection.fromJson(
              json['consoleConnection'] as Map<String, dynamic>)
          : null,
      universeRoles: {
        for (final entry in rolesJson.entries)
          int.parse(entry.key):
              UniverseConfig.fromJson(entry.value as Map<String, dynamic>),
      },
      triggerBindings: {
        for (final entry in triggersJson.entries)
          entry.key: ConsoleTriggerBinding.fromJson(
              entry.value as Map<String, dynamic>),
      },
      failover: json['failover'] != null
          ? FailoverConfig.fromJson(json['failover'] as Map<String, dynamic>)
          : const FailoverConfig(),
      sacnTargets: (json['sacnTargets'] as List?)
              ?.map((e) => SacnTarget.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// What ShowUp does when the console goes offline.
class FailoverConfig {
  /// Whether auto-failover is enabled.
  final bool enabled;

  /// Seconds of no heartbeat before declaring console offline.
  final int timeoutSeconds;

  /// What to do when failing over.
  final FailoverMode fallbackMode;

  /// Duration (ms) to fade back to normal when console reconnects.
  final int fadeBackMs;

  /// Whether operator must confirm before failover activates.
  /// When true, ShowUp shows a notification instead of auto-acting.
  final bool requireConfirmation;

  /// Duration (ms) to fade in when taking over (avoids hard snap).
  final int fadeInMs;

  const FailoverConfig({
    this.enabled = false,
    this.timeoutSeconds = 15,
    this.fallbackMode = FailoverMode.lastCapture,
    this.fadeBackMs = 2000,
    this.requireConfirmation = true,
    this.fadeInMs = 3000,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'timeoutSeconds': timeoutSeconds,
        'fallbackMode': fallbackMode.name,
        'fadeBackMs': fadeBackMs,
        'requireConfirmation': requireConfirmation,
        'fadeInMs': fadeInMs,
      };

  factory FailoverConfig.fromJson(Map<String, dynamic> json) => FailoverConfig(
        enabled: json['enabled'] as bool? ?? false,
        timeoutSeconds: json['timeoutSeconds'] as int? ?? 15,
        fallbackMode: FailoverMode.values.firstWhere(
          (m) => m.name == json['fallbackMode'],
          orElse: () => FailoverMode.lastCapture,
        ),
        fadeBackMs: json['fadeBackMs'] as int? ?? 2000,
        requireConfirmation: json['requireConfirmation'] as bool? ?? true,
        fadeInMs: json['fadeInMs'] as int? ?? 3000,
      );
}

enum FailoverMode {
  /// Recall the last captured console look.
  lastCapture,

  /// Go to blackout (all zeros).
  blackout,

  /// Apply ShowUp's current ambient/reactive look.
  ambient,
}

/// sACN output target configuration.
class SacnTarget {
  /// Universe number.
  final int universe;

  /// sACN priority (0-200).
  final int priority;

  /// Use multicast (true) or unicast to specific IP (false).
  final bool multicast;

  /// Unicast IP (only used if multicast is false).
  final String? ip;

  const SacnTarget({
    required this.universe,
    this.priority = 100,
    this.multicast = true,
    this.ip,
  });

  Map<String, dynamic> toJson() => {
        'universe': universe,
        'priority': priority,
        'multicast': multicast,
        if (ip != null) 'ip': ip,
      };

  factory SacnTarget.fromJson(Map<String, dynamic> json) => SacnTarget(
        universe: json['universe'] as int,
        priority: json['priority'] as int? ?? 100,
        multicast: json['multicast'] as bool? ?? true,
        ip: json['ip'] as String?,
      );
}
