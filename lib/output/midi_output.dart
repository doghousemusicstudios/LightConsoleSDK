import 'dart:typed_data';

/// Platform MIDI output abstraction.
///
/// On macOS/iOS, this uses CoreMIDI via dart:ffi.
/// On other platforms, this is a stub that logs warnings.
///
/// For the initial implementation, this provides the public API and
/// MSC (MIDI Show Control) SysEx construction. The native CoreMIDI
/// bridge will be implemented as a separate native plugin.
class MidiOutput {
  bool _isOpen = false;
  String? _deviceId;

  /// Whether a MIDI device is open.
  bool get isOpen => _isOpen;

  /// The currently open device ID.
  String? get deviceId => _deviceId;

  /// List available MIDI output devices.
  ///
  /// Returns a list of device descriptors with id and name.
  Future<List<MidiDevice>> listOutputDevices() async {
    // TODO: Implement via CoreMIDI FFI on macOS/iOS.
    return [];
  }

  /// Open a MIDI output device.
  Future<void> open(String deviceId) async {
    _deviceId = deviceId;
    _isOpen = true;
    // TODO: Implement via CoreMIDI.
  }

  /// Send a Note On message.
  void sendNoteOn(int channel, int note, int velocity) {
    if (!_isOpen) return;
    final status = 0x90 | (channel & 0x0F);
    _sendBytes([status, note & 0x7F, velocity & 0x7F]);
  }

  /// Send a Note Off message.
  void sendNoteOff(int channel, int note) {
    if (!_isOpen) return;
    final status = 0x80 | (channel & 0x0F);
    _sendBytes([status, note & 0x7F, 0]);
  }

  /// Send a Control Change message.
  void sendCC(int channel, int controller, int value) {
    if (!_isOpen) return;
    final status = 0xB0 | (channel & 0x0F);
    _sendBytes([status, controller & 0x7F, value & 0x7F]);
  }

  /// Send a Program Change message.
  void sendProgramChange(int channel, int program) {
    if (!_isOpen) return;
    final status = 0xC0 | (channel & 0x0F);
    _sendBytes([status, program & 0x7F]);
  }

  /// Send a MIDI Show Control (MSC) GO command.
  ///
  /// MSC format: F0 7F {deviceId} 02 {commandFormat} {command} {cueData} F7
  ///
  /// [deviceId] — MSC device ID (0-111, 127 = all call).
  /// [commandFormat] — 0x01 = lighting.general.
  /// [cueNumber] — cue number as string (e.g., "3.5").
  /// [cueList] — cue list as string (e.g., "1").
  void sendMscGo({
    int deviceId = 127,
    int commandFormat = 0x01,
    String cueNumber = '1',
    String? cueList,
  }) {
    _sendMsc(
      deviceId: deviceId,
      commandFormat: commandFormat,
      command: 0x01, // GO
      cueNumber: cueNumber,
      cueList: cueList,
    );
  }

  /// Send a MIDI Show Control STOP command.
  void sendMscStop({
    int deviceId = 127,
    int commandFormat = 0x01,
    String? cueNumber,
  }) {
    _sendMsc(
      deviceId: deviceId,
      commandFormat: commandFormat,
      command: 0x02, // STOP
      cueNumber: cueNumber,
    );
  }

  /// Send a MIDI Show Control RESUME command.
  void sendMscResume({
    int deviceId = 127,
    int commandFormat = 0x01,
    String? cueNumber,
  }) {
    _sendMsc(
      deviceId: deviceId,
      commandFormat: commandFormat,
      command: 0x03, // RESUME
      cueNumber: cueNumber,
    );
  }

  /// Send a MIDI Show Control GO_OFF command.
  void sendMscGoOff({
    int deviceId = 127,
    int commandFormat = 0x01,
    String? cueNumber,
  }) {
    _sendMsc(
      deviceId: deviceId,
      commandFormat: commandFormat,
      command: 0x0B, // GO_OFF
      cueNumber: cueNumber,
    );
  }

  /// Build and send a raw MSC SysEx message.
  void _sendMsc({
    required int deviceId,
    required int commandFormat,
    required int command,
    String? cueNumber,
    String? cueList,
  }) {
    if (!_isOpen) return;

    final bytes = <int>[
      0xF0, // SysEx start
      0x7F, // Realtime
      deviceId & 0x7F,
      0x02, // MSC
      commandFormat & 0x7F,
      command & 0x7F,
    ];

    // Cue number: ASCII bytes
    if (cueNumber != null) {
      bytes.addAll(cueNumber.codeUnits);
    }

    // Delimiter between cue number and cue list
    if (cueList != null) {
      bytes.add(0x00); // delimiter
      bytes.addAll(cueList.codeUnits);
    }

    bytes.add(0xF7); // SysEx end

    _sendBytes(bytes);
  }

  void _sendBytes(List<int> bytes) {
    // TODO: Send via CoreMIDI native bridge.
    // For now, this is a stub. The actual implementation will use
    // dart:ffi to call MIDISend() on macOS/iOS.
    final _ = Uint8List.fromList(bytes);
  }

  /// Close the MIDI device.
  void close() {
    _isOpen = false;
    _deviceId = null;
    // TODO: Close CoreMIDI port.
  }

  void dispose() => close();
}

/// Describes a MIDI output device.
class MidiDevice {
  final String id;
  final String name;
  final String? manufacturer;

  const MidiDevice({
    required this.id,
    required this.name,
    this.manufacturer,
  });
}
