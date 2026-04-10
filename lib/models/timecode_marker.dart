/// A timecode position in HH:MM:SS:FF format.
class TimecodePosition implements Comparable<TimecodePosition> {
  final int hours;
  final int minutes;
  final int seconds;
  final int frames;

  /// Frames per second (24, 25, 29.97df, 30).
  final double fps;

  const TimecodePosition({
    this.hours = 0,
    this.minutes = 0,
    this.seconds = 0,
    this.frames = 0,
    this.fps = 30,
  });

  /// Total frames from zero.
  int get totalFrames {
    final fpsInt = fps.ceil();
    return (hours * 3600 + minutes * 60 + seconds) * fpsInt + frames;
  }

  /// Total seconds from zero (fractional).
  double get totalSeconds =>
      hours * 3600.0 + minutes * 60.0 + seconds + frames / fps;

  /// Parse a timecode string "HH:MM:SS:FF".
  factory TimecodePosition.parse(String tc, {double fps = 30}) {
    final parts = tc.split(RegExp(r'[:;.]'));
    return TimecodePosition(
      hours: parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      minutes: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      seconds: parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
      frames: parts.length > 3 ? int.tryParse(parts[3]) ?? 0 : 0,
      fps: fps,
    );
  }

  @override
  String toString() =>
      '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}:'
      '${frames.toString().padLeft(2, '0')}';

  @override
  int compareTo(TimecodePosition other) =>
      totalFrames.compareTo(other.totalFrames);

  @override
  bool operator ==(Object other) =>
      other is TimecodePosition && totalFrames == other.totalFrames;

  @override
  int get hashCode => totalFrames.hashCode;

  bool operator <(TimecodePosition other) => compareTo(other) < 0;
  bool operator >(TimecodePosition other) => compareTo(other) > 0;
  bool operator <=(TimecodePosition other) => compareTo(other) <= 0;
  bool operator >=(TimecodePosition other) => compareTo(other) >= 0;

  Map<String, dynamic> toJson() => {
        'position': toString(),
        'fps': fps,
      };

  factory TimecodePosition.fromJson(Map<String, dynamic> json) =>
      TimecodePosition.parse(
        json['position'] as String? ?? '00:00:00:00',
        fps: (json['fps'] as num?)?.toDouble() ?? 30,
      );
}

/// A timecode marker that triggers a ShowUp moment activation.
class TimecodeMarker implements Comparable<TimecodeMarker> {
  /// Timecode position for this marker.
  final TimecodePosition position;

  /// The ShowUp moment ID to activate.
  final String momentId;

  /// Action to take at this position.
  final TimecodeAction action;

  /// Optional label for UI display.
  final String? label;

  const TimecodeMarker({
    required this.position,
    required this.momentId,
    this.action = TimecodeAction.activate,
    this.label,
  });

  @override
  int compareTo(TimecodeMarker other) =>
      position.compareTo(other.position);

  Map<String, dynamic> toJson() => {
        'position': position.toString(),
        'momentId': momentId,
        'action': action.name,
        if (label != null) 'label': label,
      };

  factory TimecodeMarker.fromJson(Map<String, dynamic> json) =>
      TimecodeMarker(
        position: TimecodePosition.parse(
            json['position'] as String? ?? '00:00:00:00'),
        momentId: json['momentId'] as String? ?? '',
        action: TimecodeAction.values.firstWhere(
          (a) => a.name == json['action'],
          orElse: () => TimecodeAction.activate,
        ),
        label: json['label'] as String?,
      );
}

enum TimecodeAction { activate, deactivate }
