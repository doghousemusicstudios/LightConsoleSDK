import 'dart:async';

import '../models/console_trigger.dart';
import 'console_osc_service.dart';
import 'console_midi_service.dart';

/// Routes ShowUp moment and macro activations to console commands.
///
/// When a user taps a moment (e.g., "Chorus") or macro (e.g., "Big Finish")
/// in the Perform screen, this router looks up the trigger binding and
/// fires the appropriate console command via OSC or MIDI.
///
/// Integration point: ShowUp calls [onMomentActivated] and [onMacroActivated]
/// from the Perform screen's moment/macro activation handlers.
class TriggerRouter {
  final ConsoleOscService? _oscService;
  final ConsoleMidiService? _midiService;
  final Map<String, ConsoleTriggerBinding> _bindings;
  final bool _enabled;

  final StreamController<TriggerEvent> _eventLog =
      StreamController<TriggerEvent>.broadcast();

  TriggerRouter({
    ConsoleOscService? oscService,
    ConsoleMidiService? midiService,
    Map<String, ConsoleTriggerBinding> bindings = const {},
  })  : _oscService = oscService,
        _midiService = midiService,
        _bindings = Map.from(bindings),
        _enabled = true;

  /// Create a disabled router (no-op for all calls).
  TriggerRouter.disabled()
      : _oscService = null,
        _midiService = null,
        _bindings = const {},
        _enabled = false;

  /// Stream of trigger events for the debug panel.
  Stream<TriggerEvent> get eventLog => _eventLog.stream;

  /// Whether this router is active.
  bool get isEnabled => _enabled;

  /// Update trigger bindings (e.g., when user edits in UI).
  void updateBindings(Map<String, ConsoleTriggerBinding> bindings) {
    _bindings.clear();
    _bindings.addAll(bindings);
  }

  /// Add or update a single binding.
  void setBinding(String sourceId, ConsoleTriggerBinding binding) {
    _bindings[sourceId] = binding;
  }

  /// Remove a binding.
  void removeBinding(String sourceId) {
    _bindings.remove(sourceId);
  }

  /// Get the binding for a given source ID (moment or macro).
  ConsoleTriggerBinding? getBinding(String sourceId) => _bindings[sourceId];

  /// Called when a moment is activated in the Perform screen.
  ///
  /// Returns the [TriggerExecutionMode] so the caller knows whether
  /// to proceed with ShowUp's internal effects or skip them.
  ///
  /// [momentId] — the EventPackMoment.id that was activated.
  /// [momentLabel] — human-readable label for logging.
  TriggerExecutionMode onMomentActivated(String momentId,
      {String momentLabel = ''}) {
    if (!_enabled) return TriggerExecutionMode.showupOnly;
    return _fireBinding(momentId, momentLabel);
  }

  /// Called when a macro is activated in the Perform screen.
  ///
  /// Returns the [TriggerExecutionMode] so the caller knows whether
  /// to proceed with ShowUp's internal effects or skip them.
  TriggerExecutionMode onMacroActivated(String macroId,
      {String macroLabel = ''}) {
    if (!_enabled) return TriggerExecutionMode.showupOnly;
    return _fireBinding(macroId, macroLabel);
  }

  /// Test a trigger binding without it being attached to a moment/macro.
  void testBinding(ConsoleTriggerBinding binding) {
    _executeBinding(binding, 'test', 'Test');
  }

  TriggerExecutionMode _fireBinding(String sourceId, String label) {
    final binding = _bindings[sourceId];
    if (binding == null || !binding.enabled) {
      return TriggerExecutionMode.showupOnly;
    }

    if (binding.delayMs > 0) {
      Future.delayed(
        Duration(milliseconds: binding.delayMs),
        () => _executeBinding(binding, sourceId, label),
      );
    } else {
      _executeBinding(binding, sourceId, label);
    }

    return binding.executionMode;
  }

  void _executeBinding(
      ConsoleTriggerBinding binding, String sourceId, String label) {
    switch (binding.protocol) {
      case TriggerProtocol.osc:
        _executeOsc(binding, sourceId, label);
      case TriggerProtocol.midi:
      case TriggerProtocol.msc:
        _executeMidi(binding, sourceId, label);
    }
  }

  void _executeOsc(
      ConsoleTriggerBinding binding, String sourceId, String label) {
    if (_oscService == null) return;

    switch (binding.action) {
      case ConsoleTriggerAction.fireCue:
        _oscService.fireCue(
          cueList: binding.cueList,
          cueNumber: binding.cueNumber,
        );
      case ConsoleTriggerAction.fireMacro:
        _oscService.fireMacro(macroNumber: binding.macroNumber);
      case ConsoleTriggerAction.setFader:
        final page = binding.params['page'] as int? ?? 1;
        final fader = binding.params['fader'] as int? ?? 1;
        _oscService.setFader(
          page: page,
          fader: fader,
          level: binding.faderLevel,
        );
      case ConsoleTriggerAction.firePlayback:
        final page = binding.params['page'] as int? ?? 1;
        final pb = binding.params['pb'] as int? ?? 1;
        _oscService.firePlayback(page: page, pb: pb);
      case ConsoleTriggerAction.releasePlayback:
        final pb = binding.params['pb'] as int? ?? 1;
        _oscService.releasePlayback(pb: pb);
      case ConsoleTriggerAction.customOsc:
        final address = binding.params['address'] as String? ?? '';
        final args = binding.params['args'] as List<dynamic>? ?? [];
        _oscService.client.send(address, args);
      case ConsoleTriggerAction.consoleBlackout:
        _oscService.sendCommand('BlackOut');
      case ConsoleTriggerAction.customMidi:
        break; // handled by MIDI path
    }

    _eventLog.add(TriggerEvent(
      timestamp: DateTime.now(),
      sourceId: sourceId,
      sourceLabel: label,
      action: binding.action,
      protocol: TriggerProtocol.osc,
      resolvedAddress: binding.action.name,
      args: [binding.params],
      success: true,
    ));
  }

  void _executeMidi(
      ConsoleTriggerBinding binding, String sourceId, String label) {
    if (_midiService == null) return;

    switch (binding.action) {
      case ConsoleTriggerAction.fireCue:
        _midiService.fireCue(cueNumber: binding.cueNumber);
      case ConsoleTriggerAction.fireMacro:
        _midiService.fireMacro(macroNumber: binding.macroNumber);
      case ConsoleTriggerAction.setFader:
        final fader = binding.params['fader'] as int? ?? 1;
        _midiService.setFader(fader: fader, level: binding.faderLevel);
      default:
        break;
    }

    _eventLog.add(TriggerEvent(
      timestamp: DateTime.now(),
      sourceId: sourceId,
      sourceLabel: label,
      action: binding.action,
      protocol: binding.protocol,
      resolvedAddress: binding.action.name,
      args: [binding.params],
      success: true,
    ));
  }

  void dispose() {
    _eventLog.close();
  }
}
