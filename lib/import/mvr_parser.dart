import 'dart:io';

import '../models/parsed_fixture.dart';

/// Parses MVR (My Virtual Rig) files exported from lighting consoles
/// and CAD software.
///
/// MVR is a ZIP archive containing:
///   - GeneralSceneDescription.xml (fixture layout, groups, layers)
///   - Embedded GDTF fixture type files (.gdtf)
///   - Optional 3D models and textures (ignored by ShowUp)
///
/// Supported by GrandMA3, Vectorworks, Capture, WYSIWYG, and others.
class MvrParser {
  /// Parse an MVR file and return a structured rig description.
  Future<ParsedRig> parse(File mvrFile) async {
    try {
      final bytes = await mvrFile.readAsBytes();
      final xml = _extractSceneDescription(bytes);
      if (xml == null) {
        return const ParsedRig(
          fixtures: [],
          format: ImportFormat.mvr,
          warnings: ['Could not find GeneralSceneDescription.xml in MVR archive'],
        );
      }
      return _parseSceneXml(xml);
    } catch (e) {
      return ParsedRig(
        fixtures: [],
        format: ImportFormat.mvr,
        warnings: ['Failed to parse MVR file: $e'],
      );
    }
  }

  /// Parse MVR scene description XML content directly.
  ParsedRig parseXmlContent(String xml) => _parseSceneXml(xml);

  String? _extractSceneDescription(List<int> zipBytes) {
    // Find GeneralSceneDescription.xml in the ZIP archive (stored, no compression)
    var offset = 0;
    while (offset < zipBytes.length - 30) {
      if (zipBytes[offset] == 0x50 &&
          zipBytes[offset + 1] == 0x4B &&
          zipBytes[offset + 2] == 0x03 &&
          zipBytes[offset + 3] == 0x04) {
        final nameLength =
            zipBytes[offset + 26] | (zipBytes[offset + 27] << 8);
        final extraLength =
            zipBytes[offset + 28] | (zipBytes[offset + 29] << 8);
        final compressedSize = zipBytes[offset + 18] |
            (zipBytes[offset + 19] << 8) |
            (zipBytes[offset + 20] << 16) |
            (zipBytes[offset + 21] << 24);
        final compressionMethod =
            zipBytes[offset + 8] | (zipBytes[offset + 9] << 8);

        final nameStart = offset + 30;
        final name = String.fromCharCodes(
            zipBytes.sublist(nameStart, nameStart + nameLength));

        final dataStart = nameStart + nameLength + extraLength;

        if (name.toLowerCase().contains('generalscenedescription.xml') &&
            compressionMethod == 0) {
          return String.fromCharCodes(
              zipBytes.sublist(dataStart, dataStart + compressedSize));
        }

        offset = dataStart + compressedSize;
      } else {
        offset++;
      }
    }
    return null;
  }

  ParsedRig _parseSceneXml(String xml) {
    final fixtures = <ParsedFixture>[];
    final groups = <String>[];
    final usedUniverses = <int>{};
    final warnings = <String>[];

    // Parse fixtures from <Fixture> elements
    final fixtureRegex2 = RegExp(
      r'<Fixture\b([^>]*)>(.*?)</Fixture>',
      dotAll: true,
      caseSensitive: false,
    );

    for (final match in fixtureRegex2.allMatches(xml)) {
      final attrs = match.group(1) ?? '';
      final body = match.group(2) ?? '';

      final name = _extractAttr(attrs, 'name') ?? 'Unnamed';
      final uuid = _extractAttr(attrs, 'uuid');
      final gdtfSpec = _extractAttr(attrs, 'GDTFSpec') ??
          _extractAttr(attrs, 'gdtfspec') ??
          'Unknown@Unknown';

      // Parse address: <Address break="0">universe.address</Address>
      final addrMatch = RegExp(r'<Address[^>]*>(\d+)\.(\d+)</Address>')
          .firstMatch(body);
      int universe = 0;
      int address = 1;

      if (addrMatch != null) {
        universe = int.tryParse(addrMatch.group(1) ?? '0') ?? 0;
        address = int.tryParse(addrMatch.group(2) ?? '1') ?? 1;
      } else {
        // Try flat address format: <Address>123</Address>
        final flatAddr =
            RegExp(r'<Address[^>]*>(\d+)</Address>').firstMatch(body);
        if (flatAddr != null) {
          final flat = int.tryParse(flatAddr.group(1) ?? '1') ?? 1;
          universe = (flat - 1) ~/ 512;
          address = ((flat - 1) % 512) + 1;
        }
      }

      usedUniverses.add(universe);

      // Determine layer name from context
      final layerMatch = RegExp(
        r'<Layer\s+[^>]*name="([^"]*)"[^>]*>.*?<Fixture[^>]*uuid="' +
            RegExp.escape(uuid ?? '') +
            '"',
        dotAll: true,
        caseSensitive: false,
      ).firstMatch(xml);

      fixtures.add(ParsedFixture(
        name: name,
        fixtureType: gdtfSpec,
        universe: universe,
        startAddress: address,
        sourceUuid: uuid,
        layerName: layerMatch?.group(1),
      ));
    }

    // Parse groups from <GroupObject> elements
    final groupRegex = RegExp(
      r'<GroupObject\s+[^>]*name="([^"]*)"',
      caseSensitive: false,
    );

    for (final match in groupRegex.allMatches(xml)) {
      final groupName = match.group(1);
      if (groupName != null && groupName.isNotEmpty) {
        groups.add(groupName);
      }
    }

    if (fixtures.isEmpty) {
      warnings.add('No fixtures found in MVR scene description');
    }

    return ParsedRig(
      fixtures: fixtures,
      groups: groups,
      usedUniverses: usedUniverses,
      format: ImportFormat.mvr,
      warnings: warnings,
    );
  }

  String? _extractAttr(String attrs, String name) {
    final match = RegExp('$name="([^"]*)"', caseSensitive: false)
        .firstMatch(attrs);
    return match?.group(1);
  }
}
