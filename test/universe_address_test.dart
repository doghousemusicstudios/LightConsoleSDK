import 'package:test/test.dart';
import 'package:light_console_sdk/models/universe_address.dart';

void main() {
  group('UniverseAddress', () {
    group('construction and canonical value', () {
      test('stores 1-indexed DMX universe', () {
        final addr = UniverseAddress(1);
        expect(addr.dmxUniverse, 1);
      });

      test('accepts max valid universe (63999)', () {
        final addr = UniverseAddress(63999);
        expect(addr.dmxUniverse, 63999);
      });
    });

    group('Art-Net conversion (0-indexed)', () {
      test('DMX 1 = Art-Net 0', () {
        expect(UniverseAddress(1).artNet, 0);
      });

      test('DMX 2 = Art-Net 1', () {
        expect(UniverseAddress(2).artNet, 1);
      });

      test('DMX 16 = Art-Net 15', () {
        expect(UniverseAddress(16).artNet, 15);
      });

      test('fromArtNet(0) = DMX 1', () {
        expect(UniverseAddress.fromArtNet(0).dmxUniverse, 1);
      });

      test('fromArtNet(15) = DMX 16', () {
        expect(UniverseAddress.fromArtNet(15).dmxUniverse, 16);
      });

      test('round-trip: DMX -> Art-Net -> DMX', () {
        for (var i = 1; i <= 100; i++) {
          final addr = UniverseAddress(i);
          final roundTrip = UniverseAddress.fromArtNet(addr.artNet);
          expect(roundTrip.dmxUniverse, i,
              reason: 'Round-trip failed for DMX universe $i');
        }
      });
    });

    group('sACN conversion (1-indexed)', () {
      test('DMX 1 = sACN 1', () {
        expect(UniverseAddress(1).sacn, 1);
      });

      test('DMX 16 = sACN 16', () {
        expect(UniverseAddress(16).sacn, 16);
      });

      test('fromSacn(1) = DMX 1', () {
        expect(UniverseAddress.fromSacn(1).dmxUniverse, 1);
      });

      test('round-trip: DMX -> sACN -> DMX', () {
        for (var i = 1; i <= 100; i++) {
          final addr = UniverseAddress(i);
          final roundTrip = UniverseAddress.fromSacn(addr.sacn);
          expect(roundTrip.dmxUniverse, i);
        }
      });
    });

    group('buffer index conversion (0-indexed)', () {
      test('DMX 1 = buffer index 0', () {
        expect(UniverseAddress(1).bufferIndex, 0);
      });

      test('DMX 16 = buffer index 15', () {
        expect(UniverseAddress(16).bufferIndex, 15);
      });

      test('fromBufferIndex(0) = DMX 1', () {
        expect(UniverseAddress.fromBufferIndex(0).dmxUniverse, 1);
      });

      test('round-trip: DMX -> buffer -> DMX', () {
        for (var i = 1; i <= 100; i++) {
          final addr = UniverseAddress(i);
          final roundTrip = UniverseAddress.fromBufferIndex(addr.bufferIndex);
          expect(roundTrip.dmxUniverse, i);
        }
      });
    });

    group('sACN multicast address', () {
      test('universe 1 = 239.255.0.1', () {
        expect(UniverseAddress(1).sacnMulticast, '239.255.0.1');
      });

      test('universe 256 = 239.255.1.0', () {
        expect(UniverseAddress(256).sacnMulticast, '239.255.1.0');
      });

      test('universe 257 = 239.255.1.1', () {
        expect(UniverseAddress(257).sacnMulticast, '239.255.1.1');
      });

      test('universe 63999 = 239.255.249.255', () {
        expect(UniverseAddress(63999).sacnMulticast, '239.255.249.255');
      });
    });

    group('cross-protocol consistency', () {
      test('Art-Net and sACN are always offset by 1', () {
        for (var i = 1; i <= 1000; i++) {
          final addr = UniverseAddress(i);
          expect(addr.sacn - addr.artNet, 1,
              reason: 'sACN - Art-Net offset != 1 for universe $i');
        }
      });

      test('bufferIndex == artNet for all universes', () {
        for (var i = 1; i <= 1000; i++) {
          final addr = UniverseAddress(i);
          expect(addr.bufferIndex, addr.artNet,
              reason: 'bufferIndex != artNet for universe $i');
        }
      });
    });

    group('equality and comparison', () {
      test('same universe are equal', () {
        expect(UniverseAddress(5), equals(UniverseAddress(5)));
      });

      test('different universes are not equal', () {
        expect(UniverseAddress(5), isNot(equals(UniverseAddress(6))));
      });

      test('compareTo orders correctly', () {
        final a = UniverseAddress(1);
        final b = UniverseAddress(10);
        expect(a.compareTo(b), lessThan(0));
        expect(b.compareTo(a), greaterThan(0));
        expect(a.compareTo(a), 0);
      });

      test('can be used as map key', () {
        final map = <UniverseAddress, String>{};
        map[UniverseAddress(1)] = 'one';
        map[UniverseAddress(2)] = 'two';
        expect(map[UniverseAddress(1)], 'one');
        expect(map[UniverseAddress(2)], 'two');
      });
    });
  });
}
