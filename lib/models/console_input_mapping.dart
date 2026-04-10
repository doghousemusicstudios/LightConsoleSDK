/// Maps an incoming OSC address or MIDI CC to a ShowUp parameter.
///
/// Used by [ConsoleInputService] to translate fader movements on the
/// console into ShowUp parameter changes (e.g., master dimmer, color speed).
class ConsoleInputMapping {
  /// The incoming source identifier.
  /// For OSC: the full address (e.g., '/gma3/Page1/Fader9').
  /// For MIDI: 'cc:{channel}:{controller}' (e.g., 'cc:0:1').
  final String source;

  /// The ShowUp parameter to control.
  final ShowUpParameter target;

  /// Input range minimum (default 0.0).
  final double inputMin;

  /// Input range maximum (default 1.0).
  final double inputMax;

  /// Optional group ID (for group-specific parameters like group dimmer).
  final String? groupId;

  const ConsoleInputMapping({
    required this.source,
    required this.target,
    this.inputMin = 0.0,
    this.inputMax = 1.0,
    this.groupId,
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        'target': target.name,
        'inputMin': inputMin,
        'inputMax': inputMax,
        if (groupId != null) 'groupId': groupId,
      };

  factory ConsoleInputMapping.fromJson(Map<String, dynamic> json) =>
      ConsoleInputMapping(
        source: json['source'] as String,
        target: ShowUpParameter.values.firstWhere(
          (p) => p.name == json['target'],
          orElse: () => ShowUpParameter.masterDimmer,
        ),
        inputMin: (json['inputMin'] as num?)?.toDouble() ?? 0.0,
        inputMax: (json['inputMax'] as num?)?.toDouble() ?? 1.0,
        groupId: json['groupId'] as String?,
      );
}

/// ShowUp parameters that can be controlled by incoming console messages.
enum ShowUpParameter {
  /// Global master dimmer (0.0-1.0).
  masterDimmer,

  /// Color effect speed (0.0-1.0).
  colorSpeed,

  /// Movement effect speed (0.0-1.0).
  movementSpeed,

  /// Effect intensity / excitement (0.0-1.0).
  excitement,

  /// Color warmth (0.0-1.0).
  warmth,

  /// A specific group's dimmer level (requires groupId).
  groupDimmer,

  /// Color effect size (0.0-1.0).
  colorSize,

  /// Movement effect size (0.0-1.0).
  movementSize,
}
