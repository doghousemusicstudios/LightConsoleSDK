import '../models/console_profile.dart';
import 'midi_output.dart';

/// Sends MIDI commands to a lighting console using console-specific
/// settings from a [ConsoleProfile].
///
/// Supports both raw MIDI (Note/CC) and MIDI Show Control (MSC).
class ConsoleMidiService {
  final MidiOutput _midi;
  final ConsoleProfile _profile;

  ConsoleMidiService({
    required ConsoleProfile profile,
    MidiOutput? midi,
  })  : _profile = profile,
        _midi = midi ?? MidiOutput();

  bool get isConnected => _midi.isOpen;

  ConsoleMidiSettings get _settings =>
      _profile.midiSettings ?? const ConsoleMidiSettings();

  /// List available MIDI devices.
  Future<List<MidiDevice>> listDevices() => _midi.listOutputDevices();

  /// Open a MIDI device by ID.
  Future<void> connect(String deviceId) => _midi.open(deviceId);

  /// Fire a cue on the console.
  void fireCue({String cueNumber = '1', String? cueList}) {
    if (_settings.useMsc) {
      _midi.sendMscGo(
        deviceId: _settings.mscDeviceId,
        commandFormat: _settings.mscCommandFormat,
        cueNumber: cueNumber,
        cueList: cueList,
      );
    } else if (_settings.fireCueNote != null) {
      _midi.sendNoteOn(
        _settings.channel,
        _settings.fireCueNote!,
        127,
      );
      // Note off after a short delay (the console latches on NoteOn).
      Future.delayed(const Duration(milliseconds: 100), () {
        _midi.sendNoteOff(_settings.channel, _settings.fireCueNote!);
      });
    }
  }

  /// Set a fader level on the console.
  ///
  /// [fader] — fader/CC number.
  /// [level] — 0.0 to 1.0 (mapped to 0-127 MIDI CC value).
  void setFader({required int fader, required double level}) {
    final ccValue = (level.clamp(0.0, 1.0) * 127).round();
    _midi.sendCC(_settings.channel, fader, ccValue);
  }

  /// Fire a macro.
  void fireMacro({required int macroNumber}) {
    if (_settings.useMsc) {
      _midi.sendMscGo(
        deviceId: _settings.mscDeviceId,
        commandFormat: _settings.mscCommandFormat,
        cueNumber: '$macroNumber',
      );
    } else {
      // Send as NoteOn on the macro number.
      _midi.sendNoteOn(_settings.channel, macroNumber, 127);
      Future.delayed(const Duration(milliseconds: 100), () {
        _midi.sendNoteOff(_settings.channel, macroNumber);
      });
    }
  }

  /// Stop the current cue (MSC only).
  void stop({String? cueNumber}) {
    if (_settings.useMsc) {
      _midi.sendMscStop(
        deviceId: _settings.mscDeviceId,
        commandFormat: _settings.mscCommandFormat,
        cueNumber: cueNumber,
      );
    }
  }

  /// Disconnect from the MIDI device.
  void disconnect() => _midi.close();

  void dispose() => _midi.dispose();
}
