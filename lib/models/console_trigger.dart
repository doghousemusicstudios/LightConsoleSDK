/// Binds a ShowUp moment or macro activation to a console command.
///
/// When the user taps a moment (e.g., "Chorus") or macro (e.g., "Big Finish")
/// in Perform mode, the trigger router looks up the binding and fires
/// the corresponding console command.
class ConsoleTriggerBinding {
  /// The ShowUp moment or macro ID this binding is attached to.
  final String sourceId;

  /// What to tell the console to do.
  final ConsoleTriggerAction action;

  /// Parameters for the action (cue number, fader level, etc.).
  final Map<String, dynamic> params;

  /// Which protocol to use for this trigger.
  final TriggerProtocol protocol;

  /// How to coordinate ShowUp effects and console commands.
  final TriggerExecutionMode executionMode;

  /// Optional delay (ms) before firing the console command.
  final int delayMs;

  /// Whether this binding is active.
  final bool enabled;

  const ConsoleTriggerBinding({
    required this.sourceId,
    required this.action,
    this.params = const {},
    this.protocol = TriggerProtocol.osc,
    this.executionMode = TriggerExecutionMode.both,
    this.delayMs = 0,
    this.enabled = true,
  });

  /// Convenience: get cue list parameter.
  String get cueList => params['cueList'] as String? ?? '1';

  /// Convenience: get cue number parameter.
  String get cueNumber => params['cueNumber'] as String? ?? '1';

  /// Convenience: get fader level parameter (0.0–1.0).
  double get faderLevel => (params['faderLevel'] as num?)?.toDouble() ?? 1.0;

  /// Convenience: get macro number parameter.
  int get macroNumber => params['macroNumber'] as int? ?? 1;

  ConsoleTriggerBinding copyWith({
    String? sourceId,
    ConsoleTriggerAction? action,
    Map<String, dynamic>? params,
    TriggerProtocol? protocol,
    TriggerExecutionMode? executionMode,
    int? delayMs,
    bool? enabled,
  }) =>
      ConsoleTriggerBinding(
        sourceId: sourceId ?? this.sourceId,
        action: action ?? this.action,
        params: params ?? this.params,
        protocol: protocol ?? this.protocol,
        executionMode: executionMode ?? this.executionMode,
        delayMs: delayMs ?? this.delayMs,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'action': action.name,
        'params': params,
        'protocol': protocol.name,
        'executionMode': executionMode.name,
        'delayMs': delayMs,
        'enabled': enabled,
      };

  factory ConsoleTriggerBinding.fromJson(Map<String, dynamic> json) =>
      ConsoleTriggerBinding(
        sourceId: json['sourceId'] as String? ?? '',
        action: ConsoleTriggerAction.values.firstWhere(
          (a) => a.name == json['action'],
          orElse: () => ConsoleTriggerAction.fireCue,
        ),
        params:
            (json['params'] as Map<String, dynamic>?) ?? const {},
        protocol: TriggerProtocol.values.firstWhere(
          (p) => p.name == json['protocol'],
          orElse: () => TriggerProtocol.osc,
        ),
        executionMode: TriggerExecutionMode.values.firstWhere(
          (m) => m.name == json['executionMode'],
          orElse: () => TriggerExecutionMode.both,
        ),
        delayMs: json['delayMs'] as int? ?? 0,
        enabled: json['enabled'] as bool? ?? true,
      );
}

/// What command to send to the console.
enum ConsoleTriggerAction {
  /// Go to a specific cue. Params: cueList, cueNumber.
  fireCue,

  /// Fire a macro on the console. Params: macroNumber.
  fireMacro,

  /// Set a fader level. Params: page, fader, level.
  setFader,

  /// Send a raw OSC message. Params: address, args.
  customOsc,

  /// Send raw MIDI. Params: channel, type, data1, data2.
  customMidi,

  /// Fire a playback executor. Params: page, key, pb.
  firePlayback,

  /// Release a playback. Params: pb.
  releasePlayback,

  /// Send a console blackout (all fixtures off).
  consoleBlackout,
}

/// Which protocol carries the trigger.
enum TriggerProtocol {
  /// Open Sound Control over UDP.
  osc,

  /// MIDI Note/CC messages.
  midi,

  /// MIDI Show Control (SysEx).
  msc,
}

/// How ShowUp and the console coordinate when a trigger fires.
enum TriggerExecutionMode {
  /// Only fire ShowUp's internal effects — no console command.
  showupOnly,

  /// Only fire the console command — suppress ShowUp's effects.
  consoleOnly,

  /// Fire both ShowUp effects AND console command in parallel.
  both,

  /// Fire console command first, then ShowUp effects after [delayMs].
  sequential,
}

/// A logged trigger event for the debug panel.
class TriggerEvent {
  final DateTime timestamp;
  final String sourceId;
  final String sourceLabel;
  final ConsoleTriggerAction action;
  final TriggerProtocol protocol;
  final String resolvedAddress;
  final List<dynamic> args;
  final bool success;
  final String? error;

  const TriggerEvent({
    required this.timestamp,
    required this.sourceId,
    required this.sourceLabel,
    required this.action,
    required this.protocol,
    required this.resolvedAddress,
    this.args = const [],
    this.success = true,
    this.error,
  });
}
