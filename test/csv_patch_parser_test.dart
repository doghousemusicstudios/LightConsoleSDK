import 'package:test/test.dart';
import 'package:light_console_sdk/import/csv_patch_parser.dart';

void main() {
  group('CsvPatchParser', () {
    late CsvPatchParser parser;

    setUp(() {
      parser = CsvPatchParser();
    });

    group('delimiter detection', () {
      test('detects comma delimiter', () {
        const csv = 'Name,Universe,Address\nSpot 1,1,1';
        final result = parser.parse(csv);
        expect(result.fixtures, hasLength(1));
      });

      test('detects tab delimiter', () {
        const csv = 'Name\tUniverse\tAddress\nSpot 1\t1\t1';
        final result = parser.parse(csv);
        expect(result.fixtures, hasLength(1));
      });

      test('detects semicolon delimiter', () {
        const csv = 'Name;Universe;Address\nSpot 1;1;1';
        final result = parser.parse(csv);
        expect(result.fixtures, hasLength(1));
      });
    });

    group('address format parsing', () {
      test('universe.address format (1.001)', () {
        const csv = 'Name,Type,Address\nSpot 1,Generic Dimmer,1.001';
        final result = parser.parse(csv);
        expect(result.fixtures, hasLength(1));
        expect(result.fixtures[0].universe, 1); // preserves source numbering
        expect(result.fixtures[0].startAddress, 1);
      });

      test('universe.address high number (2.100)', () {
        const csv = 'Name,Type,Address\nSpot 1,Dimmer,2.100';
        final result = parser.parse(csv);
        expect(result.fixtures[0].universe, 2);
        expect(result.fixtures[0].startAddress, 100);
      });

      test('flat address <= 512 (channel 100)', () {
        const csv = 'Name,Type,Address\nSpot 1,Dimmer,100';
        final result = parser.parse(csv);
        expect(result.fixtures[0].universe, 0);
        expect(result.fixtures[0].startAddress, 100);
      });

      test('flat address > 512 (channel 600)', () {
        const csv = 'Name,Type,Address\nSpot 1,Dimmer,600';
        final result = parser.parse(csv);
        // 600: (600-1)~/512 = 1, ((600-1)%512)+1 = 88
        expect(result.fixtures[0].universe, 1);
        expect(result.fixtures[0].startAddress, 88);
      });

      test('slash format (1/001)', () {
        const csv = 'Name,Type,Address\nSpot 1,Dimmer,1/001';
        final result = parser.parse(csv);
        expect(result.fixtures[0].universe, 1); // preserves source
        expect(result.fixtures[0].startAddress, 1);
      });
    });

    group('column auto-detection', () {
      test('detects Name column', () {
        const csv = 'Name,Fixture Type,DMX Address\nPar 1,LED Par,1';
        final result = parser.parse(csv);
        expect(result.fixtures[0].name, 'Par 1');
      });

      test('detects Fixture column header', () {
        const csv = 'Fixture,Channel\nMover 1,50';
        final result = parser.parse(csv);
        expect(result.fixtures[0].name, 'Mover 1');
      });
    });

    group('multiple fixtures', () {
      test('parses multiple rows', () {
        const csv = '''Name,Type,Universe,Address
Spot 1,Dimmer,1,1
Spot 2,Dimmer,1,10
Mover 1,Moving Head,2,1
Mover 2,Moving Head,2,20''';
        final result = parser.parse(csv);
        expect(result.fixtures, hasLength(4));
      });

      test('tracks used universes', () {
        const csv = '''Name,Type,Universe,Address
Spot 1,Dimmer,1,1
Mover 1,Moving Head,2,1
Strip 1,LED Strip,3,1''';
        final result = parser.parse(csv);
        expect(result.usedUniverses, containsAll([1, 2, 3]));
      });
    });

    group('edge cases', () {
      test('empty input returns empty result', () {
        final result = parser.parse('');
        expect(result.fixtures, isEmpty);
      });

      test('header only returns empty result', () {
        const csv = 'Name,Type,Address';
        final result = parser.parse(csv);
        expect(result.fixtures, isEmpty);
      });

      test('quoted fields with commas', () {
        const csv = 'Name,Type,Address\n"Spot, Stage Left",Dimmer,1';
        final result = parser.parse(csv);
        expect(result.fixtures[0].name, 'Spot, Stage Left');
      });
    });

    group('ETC Eos CSV format', () {
      test('parses typical Eos export', () {
        const csv = '''Channel,Fixture Type,Universe,Address,Label
1,Source Four,1,1,Front Wash SL
2,Source Four,1,2,Front Wash SR
3,ColorSource PAR,1,10,Backlight 1''';
        final result = parser.parse(csv);
        expect(result.fixtures, hasLength(3));
        expect(result.fixtures[0].name, 'Front Wash SL');
      });
    });

    group('ChamSys MagicQ CSV format', () {
      test('parses typical MQ export', () {
        // MQ uses "Name" and "DMX Address" headers
        const csv = '''Name,Fixture Type,DMX Address
Spot 1,Generic Dimmer,1.001
Spot 2,Generic Dimmer,1.002
Mover 1,Robe Robin 600,2.001''';
        final result = parser.parse(csv);
        expect(result.fixtures, hasLength(3));
        expect(result.fixtures[2].universe, 2); // preserves source: universe 2
      });
    });
  });
}
