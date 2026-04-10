/// Raw DMX state captured from a console's output.
///
/// This is a "photo" of the lighting state at a point in time,
/// stored as raw channel values for faithful reproduction.
class CapturedDmxState {
  /// Raw DMX values per universe.
  /// Key = universe (1-based), value = map of channel (0-based) → value (0-255).
  final Map<int, Map<int, int>> rawDmx;

  /// Source of the capture.
  final String captureSource;

  /// When the capture was taken.
  final DateTime capturedAt;

  const CapturedDmxState({
    required this.rawDmx,
    this.captureSource = 'console',
    required this.capturedAt,
  });

  /// Get a flat list of non-zero channels across all universes.
  int get activeChannelCount {
    var count = 0;
    for (final universe in rawDmx.values) {
      count += universe.values.where((v) => v > 0).length;
    }
    return count;
  }

  Map<String, dynamic> toJson() => {
        'rawDmx': {
          for (final entry in rawDmx.entries)
            '${entry.key}': {
              for (final ch in entry.value.entries)
                '${ch.key}': ch.value,
            },
        },
        'captureSource': captureSource,
        'capturedAt': capturedAt.toIso8601String(),
      };

  factory CapturedDmxState.fromJson(Map<String, dynamic> json) {
    final rawDmxJson = json['rawDmx'] as Map<String, dynamic>? ?? {};
    final rawDmx = <int, Map<int, int>>{};

    for (final uEntry in rawDmxJson.entries) {
      final universe = int.parse(uEntry.key);
      final channels = <int, int>{};
      final chMap = uEntry.value as Map<String, dynamic>;
      for (final cEntry in chMap.entries) {
        channels[int.parse(cEntry.key)] = cEntry.value as int;
      }
      rawDmx[universe] = channels;
    }

    return CapturedDmxState(
      rawDmx: rawDmx,
      captureSource: json['captureSource'] as String? ?? 'console',
      capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// A captured look: raw DMX state plus an estimated effect-based snapshot.
///
/// The raw DMX enables faithful reproduction (bypassing the compositor),
/// while the estimated snapshot allows editing in ShowUp's effect-based system.
class CapturedLook {
  /// Unique identifier.
  final String id;

  /// Human-readable name.
  final String name;

  /// The raw DMX capture.
  final CapturedDmxState dmxState;

  /// Best-guess effect parameters estimated from the DMX values.
  /// This is a Map matching LightLookSnapshot.toJson() format.
  /// Null if reverse-mapping was not possible.
  final Map<String, dynamic>? estimatedSnapshot;

  const CapturedLook({
    required this.id,
    required this.name,
    required this.dmxState,
    this.estimatedSnapshot,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'capturedAt': dmxState.capturedAt.toIso8601String(),
        'rawDmx': dmxState.toJson()['rawDmx'],
        'captureSource': dmxState.captureSource,
        if (estimatedSnapshot != null)
          'estimatedSnapshot': estimatedSnapshot,
      };

  factory CapturedLook.fromJson(Map<String, dynamic> json) {
    final rawDmxJson = json['rawDmx'] as Map<String, dynamic>? ?? {};
    final rawDmx = <int, Map<int, int>>{};

    for (final uEntry in rawDmxJson.entries) {
      final universe = int.parse(uEntry.key);
      final channels = <int, int>{};
      final chMap = uEntry.value as Map<String, dynamic>;
      for (final cEntry in chMap.entries) {
        channels[int.parse(cEntry.key)] = cEntry.value as int;
      }
      rawDmx[universe] = channels;
    }

    return CapturedLook(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Captured Look',
      dmxState: CapturedDmxState(
        rawDmx: rawDmx,
        captureSource: json['captureSource'] as String? ?? 'console',
        capturedAt:
            DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
                DateTime.now(),
      ),
      estimatedSnapshot:
          json['estimatedSnapshot'] as Map<String, dynamic>?,
    );
  }
}
