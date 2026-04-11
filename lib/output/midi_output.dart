import 'dart:typed_data';

/// Abstract backend for platform-specific MIDI output.
///
/// ShowUp provides the concrete implementation via [ShowUpMidiOutputBackend]
/// which delegates to CoreMIDI on macOS/iOS through a Flutter MethodChannel.
/// The SDK never touches native code directly — it constructs MIDI byte
/// sequences and hands them to the backend.
abstract class MidiOutputBackend {
  /// List available MIDI output devices on this platform.
  Future<List<MidiDeviceDescriptor>> listDevices();

  /// Open a MIDI output device for sending.
  Future<void> openDevice(String deviceId);

  /// Send raw MIDI bytes to the open device.
  Future<void> sendBytes(Uint8List bytes);

  /// Close the currently open device.
  Future<void> closeDevice();
}

/// Describes a MIDI output device discovered on the platform.
class MidiDeviceDescriptor {
  final String id;
  final String name;
  final String connectionType; // 'network', 'device', 'virtual', 'unknown'
  final bool isNetwork;
  final Map<String, Object?> details;

  const MidiDeviceDescriptor({
    required this.id,
    required this.name,
    this.connectionType = 'unknown',
    this.isNetwork = false,
    this.details = const {},
  });
}

/// MIDI output with message construction and optional platform backend.
///
/// Constructs valid MIDI byte sequences (Note On/Off, CC, Program Change,
/// MSC SysEx) and sends them via an injected [MidiOutputBackend].
/// If no backend is provided, message construction still works (useful
/// for testing) but bytes are silently dropped.
///
/// Usage:
/// ```dart
/// // With backend (ShowUp injects this):
/// final midi = MidiOutput(backend: ShowUpMidiOutputBackend(bridge));
/// await midi.open('device-id');
/// midi.sendNoteOn(0, 60, 127);
///
/// // Without backend (testing/inspection):
/// final midi = MidiOutput();
/// midi.sendMscGo(cueNumber: '3'); // builds bytes but doesn't send
/// print(midi.lastBytes); // inspect the constructed message
/// ```
class MidiOutput {
  final MidiOutputBackend? _backend;
  bool _isOpen = false;
  String? _deviceId;

  /// The last bytes constructed by any send method (for testing/inspection).
  Uint8List? lastBytes;

  MidiOutput({MidiOutputBackend? backend}) : _backend = backend;

  /// Whether a MIDI device is open.
  bool get isOpen => _isOpen;

  /// The currently open device ID.
  String? get deviceId => _deviceId;

  /// Whether a backend is available for actual MIDI transmission.
  bool get hasBackend => _backend != null;

  /// List available MIDI output devices.
  Future<List<MidiDeviceDescriptor>> listOutputDevices() async {
    if (_backend == null) return [];
    return _backend.listDevices();
  }

  /// Open a MIDI output device.
  ///
  /// Sets [isOpen] only after the backend successfully opens.
  /// If the backend throws, the device remains closed.
  Future<void> open(String deviceId) async {
    _deviceId = deviceId;
    try {
      await _backend?.openDevice(deviceId);
      _isOpen = true;
    } catch (_) {
      _deviceId = null;
      _isOpen = false;
      rethrow;
    }
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

  /// Last send error, if any. Null if last send succeeded or no send attempted.
  Object? lastSendError;

  Future<void> _sendBytes(List<int> bytes) async {
    final data = Uint8List.fromList(bytes);
    lastBytes = data;
    lastSendError = null;
    try {
      await _backend?.sendBytes(data);
    } catch (e) {
      lastSendError = e;
    }
  }

  /// Close the MIDI device.
  Future<void> close() async {
    _isOpen = false;
    _deviceId = null;
    await _backend?.closeDevice();
  }

  Future<void> dispose() => close();
}

/// Describes a MIDI output device (legacy compatibility).
/// Prefer [MidiDeviceDescriptor] for new code.
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
