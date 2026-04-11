import 'package:test/test.dart';
import 'package:light_console_sdk/output/telnet_client.dart';

void main() {
  group('TelnetResponse', () {
    group('parse', () {
      test('extracts status code from response', () {
        final response = TelnetResponse.parse('200 Ok\r\nSome data');
        expect(response.statusCode, 200);
      });

      test('handles response with no status code', () {
        final response = TelnetResponse.parse('Just some text');
        expect(response.statusCode, isNull);
      });

      test('filters status lines from content', () {
        final response = TelnetResponse.parse('200 Ok\r\nContent line 1\r\nContent line 2');
        expect(response.lines, ['Content line 1', 'Content line 2']);
      });

      test('handles empty input', () {
        final response = TelnetResponse.parse('');
        expect(response.lines, isEmpty);
        expect(response.statusCode, isNull);
      });

      test('isSuccess for 200', () {
        final response = TelnetResponse.parse('200 Ok');
        expect(response.isSuccess, isTrue);
      });

      test('isSuccess false for 404', () {
        final response = TelnetResponse.parse('404 Not Found');
        expect(response.isSuccess, isFalse);
      });

      test('isSuccess false when no status', () {
        final response = TelnetResponse.parse('No status here');
        expect(response.isSuccess, isFalse);
      });
    });

    group('parseCuelists', () {
      test('parses QLList format', () {
        final response = TelnetResponse.parse(
          '200 Ok\r\n00001 - Main Show\r\n00002 - House Lights\r\n00005 - Dance Floor',
        );
        final cuelists = response.parseCuelists();
        expect(cuelists, hasLength(3));
        expect(cuelists[0].number, 1);
        expect(cuelists[0].name, 'Main Show');
        expect(cuelists[1].number, 2);
        expect(cuelists[1].name, 'House Lights');
        expect(cuelists[2].number, 5);
        expect(cuelists[2].name, 'Dance Floor');
      });

      test('handles empty response', () {
        final response = TelnetResponse.parse('200 Ok');
        expect(response.parseCuelists(), isEmpty);
      });

      test('skips malformed lines', () {
        final response = TelnetResponse.parse(
          '200 Ok\r\n00001 - Valid\r\ngarbage\r\n00003 - Also Valid',
        );
        final cuelists = response.parseCuelists();
        expect(cuelists, hasLength(2));
        expect(cuelists[0].name, 'Valid');
        expect(cuelists[1].name, 'Also Valid');
      });

      test('handles cuelist names with hyphens', () {
        final response = TelnetResponse.parse(
          '200 Ok\r\n00010 - Stage Left - Blue',
        );
        final cuelists = response.parseCuelists();
        expect(cuelists, hasLength(1));
        expect(cuelists[0].number, 10);
        expect(cuelists[0].name, 'Stage Left - Blue');
      });
    });
  });

  group('OnyxCuelist', () {
    test('toString', () {
      const cuelist = OnyxCuelist(number: 5, name: 'Dance');
      expect(cuelist.toString(), 'OnyxCuelist(5: Dance)');
    });
  });

  group('TelnetClient', () {
    test('starts disconnected', () {
      final client = TelnetClient();
      expect(client.isConnected, isFalse);
      expect(client.ip, isNull);
    });

    test('sendCommand returns false when disconnected', () {
      final client = TelnetClient();
      expect(client.sendCommand('GQL 1'), isFalse);
    });

    test('fireCuelist returns false when disconnected', () {
      final client = TelnetClient();
      expect(client.fireCuelist(1), isFalse);
    });

    test('goToCue returns false when disconnected', () {
      final client = TelnetClient();
      expect(client.goToCue(1, 3), isFalse);
    });

    test('releaseCuelist returns false when disconnected', () {
      final client = TelnetClient();
      expect(client.releaseCuelist(1), isFalse);
    });

    test('setCuelistLevel returns false when disconnected', () {
      final client = TelnetClient();
      expect(client.setCuelistLevel(1, 200), isFalse);
    });

    test('releaseAll returns false when disconnected', () {
      final client = TelnetClient();
      expect(client.releaseAll(), isFalse);
    });

    test('requestCuelists returns false when disconnected', () {
      final client = TelnetClient();
      expect(client.requestCuelists(), isFalse);
    });

    test('requestActiveCuelists returns false when disconnected', () {
      final client = TelnetClient();
      expect(client.requestActiveCuelists(), isFalse);
    });

    test('default port is 2323', () {
      final client = TelnetClient();
      expect(client.port, 2323);
    });
  });
}
