/// Role assignment for a DMX universe in console coexistence.
///
/// Determines whether ShowUp, the console, or both control a given universe.
enum UniverseRole {
  /// ShowUp owns this universe — full output, console stays out.
  showupOwned,

  /// Console owns this universe — ShowUp does not output DMX here.
  /// ShowUp may still monitor/capture incoming DMX on this universe.
  consoleOwned,

  /// Shared universe — both ShowUp and console may output.
  /// sACN priority determines who wins (highest priority takes precedence).
  shared,
}

/// Configuration for a single DMX universe in a coexistence setup.
class UniverseConfig {
  /// Universe index (0-based).
  final int universe;

  /// Who controls this universe.
  final UniverseRole role;

  /// sACN priority for this universe (0-200, default 100).
  /// Only meaningful for [UniverseRole.showupOwned] and [UniverseRole.shared].
  final int sacnPriority;

  /// Optional human-readable label (e.g., "Stage Left", "House Lights").
  final String? label;

  const UniverseConfig({
    required this.universe,
    required this.role,
    this.sacnPriority = 100,
    this.label,
  });

  Map<String, dynamic> toJson() => {
        'universe': universe,
        'role': role.name,
        'sacnPriority': sacnPriority,
        if (label != null) 'label': label,
      };

  factory UniverseConfig.fromJson(Map<String, dynamic> json) => UniverseConfig(
        universe: json['universe'] as int,
        role: UniverseRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => UniverseRole.showupOwned,
        ),
        sacnPriority: json['sacnPriority'] as int? ?? 100,
        label: json['label'] as String?,
      );

  UniverseConfig copyWith({
    int? universe,
    UniverseRole? role,
    int? sacnPriority,
    String? label,
  }) =>
      UniverseConfig(
        universe: universe ?? this.universe,
        role: role ?? this.role,
        sacnPriority: sacnPriority ?? this.sacnPriority,
        label: label ?? this.label,
      );
}
