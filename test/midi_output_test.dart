import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:light_console_sdk/output/midi_output.dart';

/// Mock backend that records all sent bytes for verification.
class MockMidiBackend implements MidiOutputBackend {
  final List<Uint8List> sentBytes = [];
  final List<MidiDeviceDescriptor> mockDevices;
  String? openedDeviceId;
  bool isClosed = false;

  MockMidiBackend({this.mockDevices = const []});

  @override
  Future<List<MidiDeviceDescriptor>> listDevices() async => mockDevices;

  @override
  Future<void> openDevice(String deviceId) async {
    openedDeviceId = deviceId;
  }

  @override
  Future<void> sendBytes(Uint8List bytes) async {
    sentBytes.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> closeDevice() async {
    isClosed = true;
  }
}

void main() {
  group('MidiOutput', () {
    group('without backend', () {
      test('listOutputDevices returns empty', () async {
        final midi = MidiOutput();
        expect(await midi.listOutputDevices(), isEmpty);
      });

      test('hasBackend is false', () {
        expect(MidiOutput().hasBackend, isFalse);
      });

      test('sendNoteOn still constructs bytes (lastBytes)', () async {
        final midi = MidiOutput();
        await midi.open('test');
        midi.sendNoteOn(0, 60, 127);
        expect(midi.lastBytes, isNotNull);
        expect(midi.lastBytes![0], 0x90); // Note On, channel 0
        expect(midi.lastBytes![1], 60);   // note
        expect(midi.lastBytes![2], 127);  // velocity
      });
    });

    group('with mock backend', () {
      late MockMidiBackend backend;
      late MidiOutput midi;

      setUp(() async {
        backend = MockMidiBackend(mockDevices: [
          const MidiDeviceDescriptor(id: 'dev1', name: 'Test MIDI'),
        ]);
        midi = MidiOutput(backend: backend);
        await midi.open('dev1');
      });

      test('hasBackend is true', () {
        expect(midi.hasBackend, isTrue);
      });

      test('open delegates to backend', () {
        expect(backend.openedDeviceId, 'dev1');
      });

      test('listDevices returns backend devices', () async {
        final devices = await midi.listOutputDevices();
        expect(devices, hasLength(1));
        expect(devices[0].name, 'Test MIDI');
      });

      test('Note On sends correct bytes', () {
        midi.sendNoteOn(0, 60, 100);
        expect(backend.sentBytes.last, [0x90, 60, 100]);
      });

      test('Note On on channel 5', () {
        midi.sendNoteOn(5, 72, 80);
        expect(backend.sentBytes.last[0], 0x95);
      });

      test('Note Off sends correct bytes', () {
        midi.sendNoteOff(0, 60);
        expect(backend.sentBytes.last, [0x80, 60, 0]);
      });

      test('CC sends correct bytes', () {
        midi.sendCC(0, 7, 100); // CC7 = volume
        expect(backend.sentBytes.last, [0xB0, 7, 100]);
      });

      test('Program Change sends correct bytes', () {
        midi.sendProgramChange(0, 5);
        expect(backend.sentBytes.last, [0xC0, 5]);
      });

      test('does not send when not open', () async {
        await midi.close();
        midi.sendNoteOn(0, 60, 127);
        // Only the initial open generates no send; after close, nothing new
        final countBefore = backend.sentBytes.length;
        midi.sendNoteOn(0, 60, 127);
        expect(backend.sentBytes.length, countBefore);
      });

      test('close delegates to backend', () async {
        await midi.close();
        expect(backend.isClosed, isTrue);
        expect(midi.isOpen, isFalse);
      });
    });

    group('MSC SysEx construction', () {
      late MockMidiBackend backend;
      late MidiOutput midi;

      setUp(() async {
        backend = MockMidiBackend();
        midi = MidiOutput(backend: backend);
        await midi.open('test');
      });

      test('MSC GO builds correct SysEx', () {
        midi.sendMscGo(cueNumber: '3');
        final bytes = backend.sentBytes.last;
        expect(bytes[0], 0xF0); // SysEx start
        expect(bytes[1], 0x7F); // Realtime
        expect(bytes[2], 127);  // All call
        expect(bytes[3], 0x02); // MSC
        expect(bytes[4], 0x01); // Lighting
        expect(bytes[5], 0x01); // GO
        expect(bytes[6], 0x33); // '3' ASCII
        expect(bytes.last, 0xF7); // SysEx end
      });

      test('MSC GO with cue list', () {
        midi.sendMscGo(cueNumber: '5', cueList: '2');
        final bytes = backend.sentBytes.last;
        // Should contain: ...0x01, '5', 0x00 (delimiter), '2', 0xF7
        expect(bytes[5], 0x01); // GO
        expect(bytes[6], 0x35); // '5'
        expect(bytes[7], 0x00); // delimiter
        expect(bytes[8], 0x32); // '2'
        expect(bytes.last, 0xF7);
      });

      test('MSC STOP command', () {
        midi.sendMscStop();
        final bytes = backend.sentBytes.last;
        expect(bytes[5], 0x02); // STOP
      });

      test('MSC RESUME command', () {
        midi.sendMscResume();
        final bytes = backend.sentBytes.last;
        expect(bytes[5], 0x03); // RESUME
      });

      test('MSC GO_OFF command', () {
        midi.sendMscGoOff();
        final bytes = backend.sentBytes.last;
        expect(bytes[5], 0x0B); // GO_OFF
      });

      test('MSC with custom device ID', () {
        midi.sendMscGo(deviceId: 42, cueNumber: '1');
        final bytes = backend.sentBytes.last;
        expect(bytes[2], 42);
      });

      test('MSC with decimal cue number', () {
        midi.sendMscGo(cueNumber: '3.5');
        final bytes = backend.sentBytes.last;
        // '3.5' = [0x33, 0x2E, 0x35]
        expect(bytes.sublist(6, 9), [0x33, 0x2E, 0x35]);
      });
    });

    group('channel masking', () {
      test('channel is masked to 0-15', () async {
        final backend = MockMidiBackend();
        final midi = MidiOutput(backend: backend);
        await midi.open('test');

        midi.sendNoteOn(16, 60, 100); // channel 16 should wrap to 0
        expect(backend.sentBytes.last[0], 0x90); // channel 0
      });

      test('note is masked to 0-127', () async {
        final backend = MockMidiBackend();
        final midi = MidiOutput(backend: backend);
        await midi.open('test');

        midi.sendNoteOn(0, 200, 100); // 200 > 127
        expect(backend.sentBytes.last[1], 200 & 0x7F);
      });
    });
  });

  group('MidiDeviceDescriptor', () {
    test('has correct defaults', () {
      const desc = MidiDeviceDescriptor(id: 'x', name: 'Test');
      expect(desc.connectionType, 'unknown');
      expect(desc.isNetwork, isFalse);
      expect(desc.details, isEmpty);
    });

    test('network device', () {
      const desc = MidiDeviceDescriptor(
        id: 'net1',
        name: 'Network MIDI',
        connectionType: 'network',
        isNetwork: true,
      );
      expect(desc.isNetwork, isTrue);
      expect(desc.connectionType, 'network');
    });
  });
}
