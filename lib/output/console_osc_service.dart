import 'dart:async';

import '../models/console_profile.dart';
import '../models/console_trigger.dart';
import 'osc_client.dart';

/// Sends OSC commands to a lighting console using console-specific
/// address patterns from a [ConsoleProfile].
///
/// This service translates high-level operations (fire cue, set fader)
/// into the correct OSC messages for the connected console type.
class ConsoleOscService {
  final OscClient client;
  final ConsoleProfile _profile;
  final StreamController<TriggerEvent> _eventLog =
      StreamController<TriggerEvent>.broadcast();

  ConsoleOscService({
    required ConsoleProfile profile,
    OscClient? client,
  })  : _profile = profile,
        client = client ?? OscClient();

  /// Stream of trigger events for the debug panel.
  Stream<TriggerEvent> get eventLog => _eventLog.stream;

  /// Whether the OSC client is connected.
  bool get isConnected => client.isConnected;

  /// Connect to the console's OSC server.
  Future<void> connect(String ip, {int? port}) async {
    final oscPort = port ?? _profile.oscPort ?? 8000;
    await client.connect(ip, oscPort);
  }

  /// Fire a cue on the console.
  ///
  /// [cueList] — cue list number (default '1').
  /// [cueNumber] — cue number (e.g., '3', '3.5', '12').
  void fireCue({String cueList = '1', required String cueNumber}) {
    final patterns = _profile.oscPatterns;
    if (patterns == null) return;

    if (patterns.cueViaCommand && patterns.sendCommand != null) {
      // MA3 style: send text command
      _send(patterns.sendCommand!, ['Go+ Cue $cueNumber'], 'fireCue');
    } else if (patterns.fireCue != null) {
      // Eos/MagicQ/Onyx style: address-based
      final address = patterns.resolve(
          patterns.fireCue!, {'cueList': cueList, 'cue': cueNumber});
      _send(address, [], 'fireCue');
    }
  }

  /// Set a fader level on the console.
  ///
  /// [page] — page number (MA3/Eos).
  /// [fader] — fader number.
  /// [level] — 0.0 to 1.0.
  void setFader({int page = 1, required int fader, required double level}) {
    final patterns = _profile.oscPatterns;
    if (patterns?.setFader == null) return;

    final address = patterns!.resolve(
        patterns.setFader!, {'page': '$page', 'fader': '$fader'});
    _send(address, [level.clamp(0.0, 1.0)], 'setFader');
  }

  /// Fire a playback/executor.
  void firePlayback({int page = 1, int? key, int? pb}) {
    final patterns = _profile.oscPatterns;
    if (patterns?.firePlayback == null) return;

    final address = patterns!.resolve(patterns.firePlayback!, {
      'page': '$page',
      'key': '${key ?? 1}',
      'pb': '${pb ?? 1}',
    });
    _send(address, [], 'firePlayback');
  }

  /// Fire a macro on the console.
  void fireMacro({required int macroNumber}) {
    final patterns = _profile.oscPatterns;
    if (patterns == null) return;

    if (patterns.cueViaCommand && patterns.sendCommand != null) {
      // MA3 style
      _send(patterns.sendCommand!, ['Macro $macroNumber'], 'fireMacro');
    } else if (patterns.fireMacro != null) {
      final address =
          patterns.resolve(patterns.fireMacro!, {'macro': '$macroNumber'});
      _send(address, [], 'fireMacro');
    }
  }

  /// Send a raw command string (MA3's /gma3/cmd style).
  void sendCommand(String command) {
    final patterns = _profile.oscPatterns;
    if (patterns?.sendCommand == null) return;
    _send(patterns!.sendCommand!, [command], 'sendCommand');
  }

  /// Go back one cue.
  void goBack({String cueList = '1', String? cueNumber}) {
    final patterns = _profile.oscPatterns;
    if (patterns == null) return;

    if (patterns.cueViaCommand && patterns.sendCommand != null) {
      _send(patterns.sendCommand!,
          ['GoBack Cue ${cueNumber ?? ""}'], 'goBack');
    } else if (patterns.goBack != null) {
      final address = patterns.resolve(
          patterns.goBack!, {'cueList': cueList, 'cue': cueNumber ?? ''});
      _send(address, [], 'goBack');
    }
  }

  /// Release a playback.
  void releasePlayback({required int pb}) {
    final patterns = _profile.oscPatterns;
    if (patterns == null) return;

    if (patterns.cueViaCommand && patterns.sendCommand != null) {
      _send(patterns.sendCommand!, ['Off Executor $pb'], 'releasePlayback');
    } else if (patterns.releasePlayback != null) {
      final address =
          patterns.resolve(patterns.releasePlayback!, {'pb': '$pb'});
      _send(address, [], 'releasePlayback');
    }
  }

  /// Disconnect from the console.
  void disconnect() => client.disconnect();

  void dispose() {
    client.dispose();
    _eventLog.close();
  }

  void _send(String address, List<dynamic> args, String actionLabel) {
    // Check connection state BEFORE sending — a disconnected client
    // silently returns from send(), which would log a false success.
    if (!client.isConnected) {
      _eventLog.add(TriggerEvent(
        timestamp: DateTime.now(),
        sourceId: '',
        sourceLabel: actionLabel,
        action: ConsoleTriggerAction.customOsc,
        protocol: TriggerProtocol.osc,
        resolvedAddress: address,
        args: args,
        success: false,
        error: 'OSC client not connected',
      ));
      return;
    }

    try {
      client.send(address, args);
      _eventLog.add(TriggerEvent(
        timestamp: DateTime.now(),
        sourceId: '',
        sourceLabel: actionLabel,
        action: ConsoleTriggerAction.customOsc,
        protocol: TriggerProtocol.osc,
        resolvedAddress: address,
        args: args,
        success: true,
      ));
    } catch (e) {
      _eventLog.add(TriggerEvent(
        timestamp: DateTime.now(),
        sourceId: '',
        sourceLabel: actionLabel,
        action: ConsoleTriggerAction.customOsc,
        protocol: TriggerProtocol.osc,
        resolvedAddress: address,
        args: args,
        success: false,
        error: e.toString(),
      ));
    }
  }
}
