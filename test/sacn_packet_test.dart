import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:light_console_sdk/transport/sacn_packet.dart';

void main() {
  group('SacnPacket', () {
    group('buildDataPacket', () {
      test('produces correct packet size (638 bytes)', () {
        final dmx = Uint8List(512);
        final packet = SacnPacket.buildDataPacket(
          universe: 1,
          dmxData: dmx,
        );
        expect(packet.length, 638);
      });

      test('preamble is 0x0010', () {
        final packet = SacnPacket.buildDataPacket(
          universe: 1,
          dmxData: Uint8List(512),
        );
        final data = ByteData.view(packet.buffer);
        expect(data.getUint16(0, Endian.big), 0x0010);
      });

      test('postamble is 0x0000', () {
        final packet = SacnPacket.buildDataPacket(
          universe: 1,
          dmxData: Uint8List(512),
        );
        final data = ByteData.view(packet.buffer);
        expect(data.getUint16(2, Endian.big), 0x0000);
      });

      test('ACN packet identifier is correct', () {
        final packet = SacnPacket.buildDataPacket(
          universe: 1,
          dmxData: Uint8List(512),
        );
        // "ASC-E1.17\0\0\0" starting at byte 4
        final expected = [
          0x41, 0x53, 0x43, 0x2D, 0x45, 0x31, 0x2E, 0x31,
          0x37, 0x00, 0x00, 0x00
        ];
        expect(packet.sublist(4, 16), expected);
      });

      test('universe is encoded correctly at correct offset', () {
        final packet = SacnPacket.buildDataPacket(
          universe: 42,
          dmxData: Uint8List(512),
        );
        final parsed = SacnPacket.parseUniverse(packet);
        expect(parsed, 42);
      });

      test('priority is encoded correctly', () {
        final packet = SacnPacket.buildDataPacket(
          universe: 1,
          dmxData: Uint8List(512),
          priority: 75,
        );
        final parsed = SacnPacket.parsePriority(packet);
        expect(parsed, 75);
      });

      test('source name is encoded and parseable', () {
        final packet = SacnPacket.buildDataPacket(
          universe: 1,
          dmxData: Uint8List(512),
          sourceName: 'ShowUp Test',
        );
        final name = SacnPacket.parseSourceName(packet);
        expect(name, 'ShowUp Test');
      });

      test('DMX data is at correct offset and intact', () {
        final dmx = Uint8List(512);
        dmx[0] = 255; // channel 1
        dmx[1] = 128; // channel 2
        dmx[511] = 42; // channel 512

        final packet = SacnPacket.buildDataPacket(
          universe: 1,
          dmxData: dmx,
        );

        final parsed = SacnPacket.parseDmxData(packet);
        expect(parsed, isNotNull);
        expect(parsed![0], 255);
        expect(parsed[1], 128);
        expect(parsed[511], 42);
      });

      test('full DMX data round-trip for all 512 channels', () {
        final dmx = Uint8List(512);
        for (var i = 0; i < 512; i++) {
          dmx[i] = i % 256;
        }

        final packet = SacnPacket.buildDataPacket(
          universe: 1,
          dmxData: dmx,
        );
        final parsed = SacnPacket.parseDmxData(packet)!;

        for (var i = 0; i < 512; i++) {
          expect(parsed[i], dmx[i],
              reason: 'Channel $i mismatch');
        }
      });

      test('different universes produce different packets', () {
        final dmx = Uint8List(512);
        final p1 = SacnPacket.buildDataPacket(universe: 1, dmxData: dmx);
        final p2 = SacnPacket.buildDataPacket(universe: 2, dmxData: dmx);

        expect(SacnPacket.parseUniverse(p1), 1);
        expect(SacnPacket.parseUniverse(p2), 2);
      });

      test('sequence number is encoded', () {
        final packet = SacnPacket.buildDataPacket(
          universe: 1,
          dmxData: Uint8List(512),
          sequence: 42,
        );
        // Sequence byte is at offset 111
        // Root(38) + FramingFlags(2) + FramingVector(4) + Name(64) + Priority(1) + Sync(2) = 111
        expect(packet[111], 42);
      });

      test('priority 0 and 200 are valid edge cases', () {
        final dmx = Uint8List(512);

        final pLow = SacnPacket.buildDataPacket(
          universe: 1, dmxData: dmx, priority: 0);
        expect(SacnPacket.parsePriority(pLow), 0);

        final pHigh = SacnPacket.buildDataPacket(
          universe: 1, dmxData: dmx, priority: 200);
        expect(SacnPacket.parsePriority(pHigh), 200);
      });
    });

    group('multicastAddress', () {
      test('universe 1 = 239.255.0.1', () {
        expect(SacnPacket.multicastAddress(1), '239.255.0.1');
      });

      test('universe 256 = 239.255.1.0', () {
        expect(SacnPacket.multicastAddress(256), '239.255.1.0');
      });

      test('universe 63999 = 239.255.249.255', () {
        expect(SacnPacket.multicastAddress(63999), '239.255.249.255');
      });
    });

    group('parse from invalid data', () {
      test('short packet returns null for universe', () {
        expect(SacnPacket.parseUniverse(Uint8List(10)), isNull);
      });

      test('short packet returns null for priority', () {
        expect(SacnPacket.parsePriority(Uint8List(10)), isNull);
      });

      test('short packet returns null for source name', () {
        expect(SacnPacket.parseSourceName(Uint8List(10)), isNull);
      });

      test('short packet returns null for DMX data', () {
        expect(SacnPacket.parseDmxData(Uint8List(10)), isNull);
      });
    });
  });
}
