import 'dart:async';

import '../models/console_trigger.dart';

/// Rolling buffer of trigger events for the console debug panel.
///
/// Stores the last [maxEvents] trigger events and provides a stream
/// for real-time UI updates.
class TriggerEventLog {
  final int maxEvents;
  final List<TriggerEvent> _events = [];
  final StreamController<List<TriggerEvent>> _controller =
      StreamController<List<TriggerEvent>>.broadcast();
  bool _paused = false;

  TriggerEventLog({this.maxEvents = 100});

  /// Stream of the full event list (emitted on each new event).
  Stream<List<TriggerEvent>> get stream => _controller.stream;

  /// Current event list.
  List<TriggerEvent> get events => List.unmodifiable(_events);

  /// Number of logged events.
  int get length => _events.length;

  /// Whether logging is paused (events are still recorded but stream is not emitted).
  bool get isPaused => _paused;

  /// Add a trigger event to the log.
  void add(TriggerEvent event) {
    _events.add(event);
    if (_events.length > maxEvents) {
      _events.removeAt(0);
    }
    if (!_paused) {
      _controller.add(List.unmodifiable(_events));
    }
  }

  /// Clear all events.
  void clear() {
    _events.clear();
    _controller.add(const []);
  }

  /// Pause stream emission (events still recorded).
  void pause() => _paused = true;

  /// Resume stream emission.
  void resume() {
    _paused = false;
    _controller.add(List.unmodifiable(_events));
  }

  /// Get events filtered by direction, protocol, or success.
  List<TriggerEvent> filtered({
    TriggerProtocol? protocol,
    bool? success,
  }) {
    return _events.where((e) {
      if (protocol != null && e.protocol != protocol) return false;
      if (success != null && e.success != success) return false;
      return true;
    }).toList();
  }

  void dispose() {
    _controller.close();
  }
}
