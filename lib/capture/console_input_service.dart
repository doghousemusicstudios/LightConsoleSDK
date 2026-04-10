import 'dart:async';

import '../models/console_input_mapping.dart';
import '../output/osc_client.dart';

/// Accepts incoming OSC or MIDI from a console to control ShowUp parameters.
///
/// The console LD can ride ShowUp's intensity with a physical fader
/// on their console, without switching to a different interface.
///
/// This service listens for incoming messages and maps them to ShowUp
/// parameter changes via a callback.
class ConsoleInputService {
  final OscClient _oscServer;
  final List<ConsoleInputMapping> _mappings;

  /// Callback invoked when a ShowUp parameter should change.
  /// [parameter] — which parameter changed.
  /// [value] — new value (0.0-1.0).
  /// [groupId] — optional group ID for group-specific parameters.
  void Function(ShowUpParameter parameter, double value, String? groupId)?
      onParameterChanged;

  /// Tracks which parameters are currently being overridden by the console.
  final Map<String, DateTime> _activeOverrides = {};

  /// Override timeout — if no input for this duration, release the override.
  final Duration overrideTimeout;

  Timer? _timeoutTimer;

  StreamSubscription<OscMessage>? _oscSub;

  ConsoleInputService({
    OscClient? oscServer,
    List<ConsoleInputMapping> mappings = const [],
    this.overrideTimeout = const Duration(seconds: 10),
    this.onParameterChanged,
  })  : _oscServer = oscServer ?? OscClient(),
        _mappings = List.from(mappings);

  /// Currently active parameter overrides (parameter key → last update time).
  Map<String, DateTime> get activeOverrides =>
      Map.unmodifiable(_activeOverrides);

  /// Whether any parameter is currently being overridden by the console.
  bool get hasActiveOverrides => _activeOverrides.isNotEmpty;

  /// Start listening for incoming OSC messages.
  ///
  /// [listenPort] — UDP port to listen on for incoming OSC.
  Future<void> startOscListener(int listenPort) async {
    // Bind to receive incoming OSC
    await _oscServer.connect('0.0.0.0', listenPort);
    _oscSub = _oscServer.incoming.listen(_onOscMessage);

    // Start timeout checker
    _timeoutTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkTimeouts(),
    );
  }

  /// Update the parameter mappings.
  void updateMappings(List<ConsoleInputMapping> mappings) {
    _mappings.clear();
    _mappings.addAll(mappings);
  }

  void _onOscMessage(OscMessage msg) {
    for (final mapping in _mappings) {
      if (msg.address == mapping.source ||
          msg.address.startsWith(mapping.source)) {
        // Extract the float value from the first argument
        double? value;
        if (msg.args.isNotEmpty) {
          if (msg.args.first is double) {
            value = msg.args.first as double;
          } else if (msg.args.first is int) {
            value = (msg.args.first as int).toDouble();
          }
        }

        if (value == null) continue;

        // Scale input range to 0.0-1.0
        final normalized = ((value - mapping.inputMin) /
                (mapping.inputMax - mapping.inputMin))
            .clamp(0.0, 1.0);

        // Track the override
        final key = mapping.groupId != null
            ? '${mapping.target.name}:${mapping.groupId}'
            : mapping.target.name;
        _activeOverrides[key] = DateTime.now();

        // Notify
        onParameterChanged?.call(
          mapping.target,
          normalized,
          mapping.groupId,
        );
      }
    }
  }

  void _checkTimeouts() {
    final now = DateTime.now();
    final expired = <String>[];

    for (final entry in _activeOverrides.entries) {
      if (now.difference(entry.value) > overrideTimeout) {
        expired.add(entry.key);
      }
    }

    for (final key in expired) {
      _activeOverrides.remove(key);
    }
  }

  /// Stop listening.
  void stop() {
    _oscSub?.cancel();
    _timeoutTimer?.cancel();
    _oscServer.disconnect();
    _activeOverrides.clear();
  }

  void dispose() {
    stop();
    _oscServer.dispose();
  }
}
