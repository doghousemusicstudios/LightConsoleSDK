import 'dart:io';

import 'gdtf_attribute_map.dart';

/// Parses a GDTF (General Device Type Format) file to extract
/// fixture definition data.
///
/// GDTF files are ZIP archives containing a `description.xml` file
/// that defines DMX modes, channels, attributes, and wheels.
///
/// This parser extracts enough information to create a ShowUp
/// FixtureDefinition-compatible data structure.
class GdtfParser {
  /// Parse a .gdtf file and return a fixture definition.
  ///
  /// [gdtfFile] — path to the .gdtf file (ZIP archive).
  Future<GdtfFixtureDefinition?> parse(File gdtfFile) async {
    try {
      // GDTF files are ZIP archives. We need to extract description.xml.
      final bytes = await gdtfFile.readAsBytes();
      final xmlContent = _extractDescriptionXml(bytes);
      if (xmlContent == null) return null;

      return _parseXml(xmlContent);
    } catch (e) {
      return null;
    }
  }

  /// Parse GDTF description XML content directly (for MVR-embedded GDTF).
  GdtfFixtureDefinition? parseXmlContent(String xmlContent) {
    try {
      return _parseXml(xmlContent);
    } catch (_) {
      return null;
    }
  }

  String? _extractDescriptionXml(List<int> zipBytes) {
    // Simple ZIP extraction for description.xml
    // ZIP local file header signature: 0x04034b50
    var offset = 0;
    while (offset < zipBytes.length - 30) {
      if (zipBytes[offset] == 0x50 &&
          zipBytes[offset + 1] == 0x4B &&
          zipBytes[offset + 2] == 0x03 &&
          zipBytes[offset + 3] == 0x04) {
        final nameLength = zipBytes[offset + 26] | (zipBytes[offset + 27] << 8);
        final extraLength =
            zipBytes[offset + 28] | (zipBytes[offset + 29] << 8);
        final compressedSize = zipBytes[offset + 18] |
            (zipBytes[offset + 19] << 8) |
            (zipBytes[offset + 20] << 16) |
            (zipBytes[offset + 21] << 24);
        final compressionMethod =
            zipBytes[offset + 8] | (zipBytes[offset + 9] << 8);

        final nameStart = offset + 30;
        final name =
            String.fromCharCodes(zipBytes.sublist(nameStart, nameStart + nameLength));

        final dataStart = nameStart + nameLength + extraLength;

        if (name.toLowerCase() == 'description.xml' &&
            compressionMethod == 0) {
          // Stored (no compression) — extract directly
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

  GdtfFixtureDefinition? _parseXml(String xml) {
    // Simple XML parsing for GDTF structure.
    // We extract: FixtureType name, DMXModes, and channel attributes.

    final nameMatch =
        RegExp(r'<FixtureType[^>]*\bName="([^"]*)"').firstMatch(xml);
    final manufacturerMatch =
        RegExp(r'<FixtureType[^>]*\bManufacturer="([^"]*)"').firstMatch(xml);

    final name = nameMatch?.group(1) ?? 'Unknown';
    final manufacturer = manufacturerMatch?.group(1) ?? 'Unknown';

    // Parse DMX modes
    final modes = <GdtfMode>[];
    final modeRegex = RegExp(
        r'<DMXMode\s+Name="([^"]*)"[^>]*>(.*?)</DMXMode>',
        dotAll: true);

    for (final modeMatch in modeRegex.allMatches(xml)) {
      final modeName = modeMatch.group(1) ?? 'Default';
      final modeXml = modeMatch.group(2) ?? '';

      final channels = <GdtfChannel>[];
      final channelRegex = RegExp(
          r'<DMXChannel[^>]*\bOffset="([^"]*)"[^>]*>.*?<LogicalChannel[^>]*\bAttribute="([^"]*)"',
          dotAll: true);

      for (final chMatch in channelRegex.allMatches(modeXml)) {
        final offsetStr = chMatch.group(1) ?? '0';
        final attribute = chMatch.group(2) ?? '';

        // Parse offset — can be "1" (single byte) or "1,2" (coarse+fine)
        final offsets =
            offsetStr.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
        final isFine = offsets.length > 1;

        channels.add(GdtfChannel(
          offset: offsets.first,
          fineOffset: isFine ? offsets[1] : null,
          gdtfAttribute: attribute,
          capability: resolveGdtfAttribute(attribute),
        ));
      }

      modes.add(GdtfMode(
        name: modeName,
        channels: channels,
        channelCount: channels.isEmpty
            ? 0
            : channels
                    .map((c) => c.fineOffset ?? c.offset)
                    .reduce((a, b) => a > b ? a : b) +
                1,
      ));
    }

    // Parse wheels
    final wheels = <GdtfWheel>[];
    final wheelRegex = RegExp(
        r'<Wheel\s+Name="([^"]*)"[^>]*>(.*?)</Wheel>', dotAll: true);

    for (final wheelMatch in wheelRegex.allMatches(xml)) {
      final wheelName = wheelMatch.group(1) ?? '';
      final wheelXml = wheelMatch.group(2) ?? '';

      final slots = <GdtfWheelSlot>[];
      final slotRegex =
          RegExp(r'<Slot\s+Name="([^"]*)"(?:\s+Color="([^"]*)")?');

      for (final slotMatch in slotRegex.allMatches(wheelXml)) {
        slots.add(GdtfWheelSlot(
          name: slotMatch.group(1) ?? '',
          color: slotMatch.group(2),
        ));
      }

      wheels.add(GdtfWheel(name: wheelName, slots: slots));
    }

    if (modes.isEmpty) return null;

    return GdtfFixtureDefinition(
      name: name,
      manufacturer: manufacturer,
      modes: modes,
      wheels: wheels,
    );
  }
}

/// A fixture definition parsed from a GDTF file.
class GdtfFixtureDefinition {
  final String name;
  final String manufacturer;
  final List<GdtfMode> modes;
  final List<GdtfWheel> wheels;

  const GdtfFixtureDefinition({
    required this.name,
    required this.manufacturer,
    required this.modes,
    this.wheels = const [],
  });

  /// GDTF spec string in "Manufacturer@Model" format.
  String get gdtfSpec => '$manufacturer@$name';
}

/// A DMX mode within a GDTF fixture.
class GdtfMode {
  final String name;
  final List<GdtfChannel> channels;
  final int channelCount;

  const GdtfMode({
    required this.name,
    required this.channels,
    required this.channelCount,
  });
}

/// A single DMX channel within a GDTF mode.
class GdtfChannel {
  /// Channel offset (0-based) within the mode.
  final int offset;

  /// Fine channel offset (for 16-bit resolution). Null if 8-bit only.
  final int? fineOffset;

  /// Original GDTF attribute name (e.g., "ColorAdd_R").
  final String gdtfAttribute;

  /// Resolved ShowUp capability type name (e.g., "red").
  final String capability;

  const GdtfChannel({
    required this.offset,
    this.fineOffset,
    required this.gdtfAttribute,
    required this.capability,
  });
}

/// A color/gobo wheel defined in a GDTF fixture.
class GdtfWheel {
  final String name;
  final List<GdtfWheelSlot> slots;

  const GdtfWheel({required this.name, required this.slots});
}

/// A single slot in a GDTF wheel.
class GdtfWheelSlot {
  final String name;
  final String? color; // hex RGB (e.g., "FF0000")

  const GdtfWheelSlot({required this.name, this.color});
}
