import 'dart:async';

import '../models/timecode_marker.dart';

/// Receives MIDI Timecode (MTC) and auto-advances ShowUp moments
/// based on timecode marker positions.
///
/// MTC uses MIDI Quarter Frame messages (status 0xF1) that arrive
/// 4 per frame, assembling a full timecode position over 2 frames.
class TimecodeService {
  final List<TimecodeMarker> _markers = [];
  TimecodePosition _currentPosition = const TimecodePosition();
  int _lastFiredIndex = -1;
  bool _isRunning = false;

  /// Callback when a moment should be activated/deactivated.
  void Function(String momentId, TimecodeAction action)? onMomentTrigger;

  /// Stream of position updates.
  final StreamController<TimecodePosition> _positionController =
      StreamController<TimecodePosition>.broadcast();

  /// Stream of current timecode position.
  Stream<TimecodePosition> get positionStream => _positionController.stream;

  /// Current timecode position.
  TimecodePosition get currentPosition => _currentPosition;

  /// Whether timecode is actively being received.
  bool get isRunning => _isRunning;

  // ── MTC Quarter Frame Assembly ──
  // MTC sends 8 quarter-frame messages per 2 frames:
  //   nibble 0: frame LSN    nibble 4: minutes LSN
  //   nibble 1: frame MSN    nibble 5: minutes MSN
  //   nibble 2: seconds LSN  nibble 6: hours LSN
  //   nibble 3: seconds MSN  nibble 7: hours MSN + rate

  final List<int> _mtcNibbles = List.filled(8, 0);
  // ignore: unused_field
  int _lastNibbleIndex = -1;

  /// Set the timecode markers (sorted by position).
  void setMarkers(List<TimecodeMarker> markers) {
    _markers.clear();
    _markers.addAll(markers);
    _markers.sort();
    _lastFiredIndex = -1;
  }

  /// Process an incoming MIDI Quarter Frame message.
  ///
  /// [data] — the data byte of the F1 message (0x00-0x7F).
  ///
  /// Quarter frame format: 0nnndddd
  ///   nnn = nibble number (0-7)
  ///   dddd = nibble data (0-15)
  void processQuarterFrame(int data) {
    final nibbleIndex = (data >> 4) & 0x07;
    final nibbleValue = data & 0x0F;

    _mtcNibbles[nibbleIndex] = nibbleValue;
    _lastNibbleIndex = nibbleIndex;
    _isRunning = true;

    // Full frame assembled when we receive nibble 7
    if (nibbleIndex == 7) {
      _assembleFullTimecode();
    }
  }

  void _assembleFullTimecode() {
    final frames = _mtcNibbles[0] | (_mtcNibbles[1] << 4);
    final seconds = _mtcNibbles[2] | (_mtcNibbles[3] << 4);
    final minutes = _mtcNibbles[4] | (_mtcNibbles[5] << 4);
    final hoursAndRate = _mtcNibbles[6] | (_mtcNibbles[7] << 4);

    final hours = hoursAndRate & 0x1F;
    final rateCode = (hoursAndRate >> 5) & 0x03;

    final fps = switch (rateCode) {
      0 => 24.0,
      1 => 25.0,
      2 => 29.97, // drop frame
      3 => 30.0,
      _ => 30.0,
    };

    _currentPosition = TimecodePosition(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      frames: frames,
      fps: fps,
    );

    _positionController.add(_currentPosition);
    _checkMarkers();
  }

  /// Manually set the timecode position (for testing or LTC input).
  void setPosition(TimecodePosition position) {
    _currentPosition = position;
    _isRunning = true;
    _positionController.add(position);
    _checkMarkers();
  }

  void _checkMarkers() {
    if (_markers.isEmpty) return;

    for (var i = 0; i < _markers.length; i++) {
      final marker = _markers[i];

      // Forward: fire markers we've passed since last check
      if (marker.position <= _currentPosition && i > _lastFiredIndex) {
        _lastFiredIndex = i;
        onMomentTrigger?.call(marker.momentId, marker.action);
      }
    }

    // Handle backward scrubbing: if position went backward, reset
    if (_lastFiredIndex >= 0 &&
        _lastFiredIndex < _markers.length &&
        _markers[_lastFiredIndex].position > _currentPosition) {
      // Find the correct index for the current position
      _lastFiredIndex = -1;
      for (var i = _markers.length - 1; i >= 0; i--) {
        if (_markers[i].position <= _currentPosition) {
          _lastFiredIndex = i;
          break;
        }
      }
    }
  }

  /// Stop receiving timecode.
  void stop() {
    _isRunning = false;
    _lastFiredIndex = -1;
    _lastNibbleIndex = -1;
    _mtcNibbles.fillRange(0, 8, 0);
  }

  void dispose() {
    stop();
    _positionController.close();
  }
}
