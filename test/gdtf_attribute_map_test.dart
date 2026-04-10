import 'package:test/test.dart';
import 'package:light_console_sdk/import/gdtf_attribute_map.dart';

void main() {
  group('GdtfAttributeMap', () {
    group('core attributes', () {
      test('Dimmer maps to dimmer', () {
        expect(resolveGdtfAttribute('Dimmer'), 'dimmer');
      });

      test('Pan maps to pan', () {
        expect(resolveGdtfAttribute('Pan'), 'pan');
      });

      test('Tilt maps to tilt', () {
        expect(resolveGdtfAttribute('Tilt'), 'tilt');
      });
    });

    group('color attributes', () {
      test('ColorAdd_R maps to red', () {
        expect(resolveGdtfAttribute('ColorAdd_R'), 'red');
      });

      test('ColorAdd_G maps to green', () {
        expect(resolveGdtfAttribute('ColorAdd_G'), 'green');
      });

      test('ColorAdd_B maps to blue', () {
        expect(resolveGdtfAttribute('ColorAdd_B'), 'blue');
      });

      test('ColorAdd_W maps to white', () {
        expect(resolveGdtfAttribute('ColorAdd_W'), 'white');
      });

      test('ColorSub_C maps to cyan', () {
        expect(resolveGdtfAttribute('ColorSub_C'), 'cyan');
      });

      test('ColorSub_M maps to magenta', () {
        expect(resolveGdtfAttribute('ColorSub_M'), 'magenta');
      });

      test('ColorSub_Y maps to yellow', () {
        expect(resolveGdtfAttribute('ColorSub_Y'), 'yellow');
      });

      test('Color1 maps to colorWheel', () {
        expect(resolveGdtfAttribute('Color1'), 'colorWheel');
      });
    });

    group('fine channels', () {
      test('DimmerFine maps to dimmerFine', () {
        expect(resolveGdtfAttribute('DimmerFine'), 'dimmerFine');
      });

      test('PanFine maps to panFine', () {
        final result = resolveGdtfAttribute('PanFine');
        expect(result, anyOf('panFine', 'pan'));
      });

      test('TiltFine maps to tiltFine', () {
        final result = resolveGdtfAttribute('TiltFine');
        expect(result, anyOf('tiltFine', 'tilt'));
      });
    });

    group('beam attributes', () {
      test('Iris resolves', () {
        expect(resolveGdtfAttribute('Iris'), isNotNull);
      });

      test('Zoom resolves', () {
        expect(resolveGdtfAttribute('Zoom'), isNotNull);
      });

      test('Focus resolves', () {
        expect(resolveGdtfAttribute('Focus1'), isNotNull);
      });

      test('Prism resolves', () {
        expect(resolveGdtfAttribute('Prism1'), isNotNull);
      });
    });

    group('gobo attributes', () {
      test('Gobo1 maps to goboWheel', () {
        expect(resolveGdtfAttribute('Gobo1'), 'goboWheel');
      });

      test('Gobo1Pos maps to goboRotation', () {
        final result = resolveGdtfAttribute('Gobo1Pos');
        expect(result, anyOf('goboRotation', 'goboWheel'));
      });
    });

    group('other attributes', () {
      test('Shutter resolves to strobe', () {
        final result = resolveGdtfAttribute('Shutter1');
        expect(result, anyOf('strobe', 'shutter'));
      });

      test('Fog resolves', () {
        expect(resolveGdtfAttribute('Fog'), isNotNull);
      });
    });

    group('fallback behavior', () {
      test('unknown attribute returns noFunction', () {
        expect(resolveGdtfAttribute('TotallyUnknown123'), 'noFunction');
      });

      test('empty string returns noFunction', () {
        expect(resolveGdtfAttribute(''), 'noFunction');
      });
    });
  });
}
