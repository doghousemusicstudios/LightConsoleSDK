/// A fixture parsed from an import source (MVR, GDTF, or CSV).
///
/// This is the common result type for all import parsers, providing
/// enough information for ShowUp to match against its fixture library
/// and add to its PatchManager.
class ParsedFixture {
  /// Name of the fixture instance (e.g., "Spot 1", "Stage Left Par 3").
  final String name;

  /// GDTF spec string: "Manufacturer@Model" (e.g., "Chauvet@Intimidator Spot 110").
  /// For CSV imports, this is the raw fixture type string from the spreadsheet.
  final String fixtureType;

  /// DMX universe (0-based).
  final int universe;

  /// DMX start address (1-based, per DMX convention).
  final int startAddress;

  /// Mode name (e.g., "Standard", "12 Channel"). Null if not specified.
  final String? mode;

  /// Group name this fixture belongs to. Null if ungrouped.
  final String? groupName;

  /// UUID from the source file (MVR fixture UUID). Null for CSV imports.
  final String? sourceUuid;

  /// Layer name from MVR. Null for non-MVR imports.
  final String? layerName;

  /// 3D position from MVR (x, y, z in meters). Null if not available.
  final (double, double, double)? position;

  const ParsedFixture({
    required this.name,
    required this.fixtureType,
    required this.universe,
    required this.startAddress,
    this.mode,
    this.groupName,
    this.sourceUuid,
    this.layerName,
    this.position,
  });

  @override
  String toString() =>
      'ParsedFixture($name, $fixtureType, U$universe A$startAddress)';
}

/// Result of parsing a rig file (MVR, GDTF, or CSV).
class ParsedRig {
  /// All fixtures found in the source file.
  final List<ParsedFixture> fixtures;

  /// Group names discovered (MVR layers, CSV groups, etc.).
  final List<String> groups;

  /// Universes used by the parsed fixtures.
  final Set<int> usedUniverses;

  /// Source file format.
  final ImportFormat format;

  /// Any warnings generated during parsing.
  final List<String> warnings;

  const ParsedRig({
    required this.fixtures,
    this.groups = const [],
    this.usedUniverses = const {},
    required this.format,
    this.warnings = const [],
  });
}

/// Source file format for rig imports.
enum ImportFormat { mvr, gdtf, csv }
