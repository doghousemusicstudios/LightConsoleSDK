import 'dart:async';

import '../models/console_trigger.dart';
import 'console_osc_service.dart';
import 'console_midi_service.dart';
import 'http_console_client.dart';
import 'telnet_client.dart';

/// Routes ShowUp moment and macro activations to console commands.
///
/// When a user taps a moment (e.g., "Chorus") or macro (e.g., "Big Finish")
/// in the Perform screen, this router looks up the trigger binding and
/// fires the appropriate console command via OSC, MIDI, or Telnet.
///
/// Integration point: ShowUp calls [onMomentActivated] and [onMacroActivated]
/// from the Perform screen's moment/macro activation handlers.
class TriggerRouter {
  final ConsoleOscService? _oscService;
  final ConsoleMidiService? _midiService;
  final TelnetClient? _telnetClient;
  final HttpConsoleClient? _httpClient;
  final Map<String, ConsoleTriggerBinding> _bindings;
  final bool _enabled;

  final StreamController<TriggerEvent> _eventLog =
      StreamController<TriggerEvent>.broadcast();

  TriggerRouter({
    ConsoleOscService? oscService,
    ConsoleMidiService? midiService,
    TelnetClient? telnetClient,
    HttpConsoleClient? httpClient,
    Map<String, ConsoleTriggerBinding> bindings = const {},
  })  : _oscService = oscService,
        _midiService = midiService,
        _telnetClient = telnetClient,
        _httpClient = httpClient,
        _bindings = Map.from(bindings),
        _enabled = true;

  /// Create a disabled router (no-op for all calls).
  TriggerRouter.disabled()
      : _oscService = null,
        _midiService = null,
        _telnetClient = null,
        _httpClient = null,
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
      case TriggerProtocol.telnet:
        _executeTelnet(binding, sourceId, label);
      case TriggerProtocol.http:
        _executeHttp(binding, sourceId, label);
    }
  }

  void _executeOsc(
      ConsoleTriggerBinding binding, String sourceId, String label) {
    if (_oscService == null) {
      _logEvent(sourceId, label, binding, TriggerProtocol.osc,
          success: false, error: 'No OSC service configured');
      return;
    }

    // All OSC sends go through ConsoleOscService which checks
    // connection state and logs its own events. But for customOsc,
    // we must NOT bypass the service's diagnostic layer.
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
        // Route through the service's _send() which checks connection
        // state and logs honestly, instead of bypassing to raw client.
        final address = binding.params['address'] as String? ?? '';
        final args = binding.params['args'] as List<dynamic>? ?? [];
        _oscService.sendRaw(address, args);
      case ConsoleTriggerAction.consoleBlackout:
        _oscService.sendCommand('BlackOut');
      case ConsoleTriggerAction.customMidi:
        break; // handled by MIDI path
    }

    // The OSC service logs its own events via its internal event log.
    // The router also logs at its level for the Perform screen debug panel.
    _logEvent(sourceId, label, binding, TriggerProtocol.osc,
        success: _oscService.client.isConnected);
  }

  void _executeMidi(
      ConsoleTriggerBinding binding, String sourceId, String label) {
    if (_midiService == null) {
      _logEvent(sourceId, label, binding, binding.protocol,
          success: false, error: 'No MIDI service configured');
      return;
    }

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

    _logEvent(sourceId, label, binding, binding.protocol,
        success: _midiService.isConnected);
  }

  void _executeTelnet(
      ConsoleTriggerBinding binding, String sourceId, String label) {
    if (_telnetClient == null) {
      _logEvent(sourceId, label, binding, TriggerProtocol.telnet,
          success: false, error: 'No Telnet client configured');
      return;
    }

    if (!_telnetClient.isConnected) {
      _logEvent(sourceId, label, binding, TriggerProtocol.telnet,
          success: false, error: 'Telnet not connected');
      return;
    }

    bool sent = false;
    String resolvedCommand = '';

    switch (binding.action) {
      case ConsoleTriggerAction.fireCue:
        final cuelist = int.tryParse(binding.cueList) ?? 1;
        final cue = int.tryParse(binding.cueNumber) ?? 1;
        resolvedCommand = 'GTQ $cuelist,$cue';
        sent = _telnetClient.goToCue(cuelist, cue);
      case ConsoleTriggerAction.fireMacro:
        resolvedCommand = 'GQL ${binding.macroNumber}';
        sent = _telnetClient.fireCuelist(binding.macroNumber);
      case ConsoleTriggerAction.setFader:
        final cuelist = binding.params['cuelist'] as int? ?? 1;
        final level = (binding.faderLevel * 255).round();
        resolvedCommand = 'SQL $cuelist,$level';
        sent = _telnetClient.setCuelistLevel(cuelist, level);
      case ConsoleTriggerAction.consoleBlackout:
        resolvedCommand = 'RAQLDF';
        sent = _telnetClient.releaseAllDimmerFirst();
      case ConsoleTriggerAction.releasePlayback:
        final cuelist = binding.params['cuelist'] as int? ?? 1;
        resolvedCommand = 'RQL $cuelist';
        sent = _telnetClient.releaseCuelist(cuelist);
      default:
        break;
    }

    _logEvent(sourceId, label, binding, TriggerProtocol.telnet,
        success: sent, resolvedAddress: resolvedCommand);
  }

  void _executeHttp(
      ConsoleTriggerBinding binding, String sourceId, String label) {
    if (_httpClient == null) {
      _logEvent(sourceId, label, binding, TriggerProtocol.http,
          success: false, error: 'No HTTP client configured');
      return;
    }

    if (!_httpClient.isConnected) {
      _logEvent(sourceId, label, binding, TriggerProtocol.http,
          success: false, error: 'HTTP client not connected');
      return;
    }

    String resolvedPath = '';

    // Fire async but don't block the trigger return.
    // HTTP gives us a response we can log.
    Future<bool> execute() async {
      switch (binding.action) {
        case ConsoleTriggerAction.fireCue:
          final userNumber = int.tryParse(binding.cueNumber) ?? 1;
          resolvedPath = 'Playbacks/FirePlaybackAtLevel?userNumber=$userNumber&level=1.0';
          return await _httpClient.firePlayback(userNumber);
        case ConsoleTriggerAction.setFader:
          final userNumber = binding.params['userNumber'] as int? ?? 1;
          resolvedPath = 'Playbacks/FirePlaybackAtLevel?userNumber=$userNumber&level=${binding.faderLevel}';
          return await _httpClient.firePlayback(userNumber, level: binding.faderLevel);
        case ConsoleTriggerAction.releasePlayback:
          final userNumber = binding.params['userNumber'] as int? ?? 1;
          resolvedPath = 'Playbacks/KillPlayback?userNumber=$userNumber';
          return await _httpClient.killPlayback(userNumber);
        case ConsoleTriggerAction.consoleBlackout:
          resolvedPath = 'Playbacks/KillAllPlaybacks';
          return await _httpClient.killAllPlaybacks();
        default:
          resolvedPath = 'unsupported action: ${binding.action.name}';
          return false;
      }
    }

    execute().then((success) {
      _logEvent(sourceId, label, binding, TriggerProtocol.http,
          success: success,
          resolvedAddress: '/titan/script/$resolvedPath',
          error: success ? null : 'HTTP request failed');
    });
  }

  void _logEvent(
    String sourceId,
    String label,
    ConsoleTriggerBinding binding,
    TriggerProtocol protocol, {
    required bool success,
    String? error,
    String? resolvedAddress,
  }) {
    _eventLog.add(TriggerEvent(
      timestamp: DateTime.now(),
      sourceId: sourceId,
      sourceLabel: label,
      action: binding.action,
      protocol: protocol,
      resolvedAddress: resolvedAddress ?? binding.action.name,
      args: [binding.params],
      success: success,
      error: error,
    ));
  }

  void dispose() {
    _eventLog.close();
  }
}
