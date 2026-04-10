import '../models/parsed_fixture.dart';

/// Parses CSV/TSV patch lists exported from lighting consoles.
///
/// Handles various delimiter formats, header detection, and
/// multiple DMX address conventions used by different consoles.
class CsvPatchParser {
  /// Parse a CSV/TSV/semicolon-delimited patch list.
  ///
  /// [content] — raw file content.
  /// [mapping] — optional column mapping. If null, auto-detects columns.
  ParsedRig parse(String content, {CsvColumnMapping? mapping}) {
    final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      return const ParsedRig(
        fixtures: [],
        format: ImportFormat.csv,
        warnings: ['Empty file'],
      );
    }

    // Detect delimiter
    final delimiter = _detectDelimiter(lines.first);

    // Parse all rows
    final rows = lines.map((line) => _splitRow(line, delimiter)).toList();
    if (rows.length < 2) {
      return const ParsedRig(
        fixtures: [],
        format: ImportFormat.csv,
        warnings: ['File has fewer than 2 rows (need header + data)'],
      );
    }

    // Detect or use provided column mapping
    final effectiveMapping = mapping ?? _autoDetectMapping(rows.first);
    if (effectiveMapping == null) {
      return const ParsedRig(
        fixtures: [],
        format: ImportFormat.csv,
        warnings: ['Could not auto-detect column mapping. Please specify manually.'],
      );
    }

    // Parse fixtures from data rows (skip header)
    final fixtures = <ParsedFixture>[];
    final usedUniverses = <int>{};
    final groups = <String>{};
    final warnings = <String>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= effectiveMapping.maxColumn) {
        warnings.add('Row $i has too few columns, skipping');
        continue;
      }

      final name = row[effectiveMapping.nameColumn].trim();
      if (name.isEmpty) continue;

      final fixtureType =
          effectiveMapping.fixtureTypeColumn != null
              ? row[effectiveMapping.fixtureTypeColumn!].trim()
              : 'Unknown';

      // Parse address
      final (universe, address) = _parseAddress(
        universeStr: effectiveMapping.universeColumn != null
            ? row[effectiveMapping.universeColumn!].trim()
            : null,
        addressStr: row[effectiveMapping.addressColumn].trim(),
      );

      usedUniverses.add(universe);

      final mode = effectiveMapping.modeColumn != null
          ? row[effectiveMapping.modeColumn!].trim()
          : null;

      final groupName = effectiveMapping.groupColumn != null
          ? row[effectiveMapping.groupColumn!].trim()
          : null;

      if (groupName != null && groupName.isNotEmpty) {
        groups.add(groupName);
      }

      fixtures.add(ParsedFixture(
        name: name,
        fixtureType: fixtureType,
        universe: universe,
        startAddress: address,
        mode: mode,
        groupName: groupName,
      ));
    }

    return ParsedRig(
      fixtures: fixtures,
      groups: groups.toList(),
      usedUniverses: usedUniverses,
      format: ImportFormat.csv,
      warnings: warnings,
    );
  }

  /// Get a preview of the CSV structure for the column mapping UI.
  CsvPreview preview(String content) {
    final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const CsvPreview(headers: [], sampleRows: [], delimiter: ',');

    final delimiter = _detectDelimiter(lines.first);
    final rows = lines.map((line) => _splitRow(line, delimiter)).toList();
    final headers = rows.isNotEmpty ? rows.first : <String>[];
    final samples = rows.length > 1 ? rows.sublist(1, rows.length.clamp(0, 6)) : <List<String>>[];
    final autoMapping = _autoDetectMapping(headers);

    return CsvPreview(
      headers: headers,
      sampleRows: samples,
      delimiter: delimiter,
      suggestedMapping: autoMapping,
    );
  }

  // ── Private helpers ──

  String _detectDelimiter(String firstLine) {
    final tabCount = firstLine.split('\t').length;
    final commaCount = firstLine.split(',').length;
    final semicolonCount = firstLine.split(';').length;

    if (tabCount >= commaCount && tabCount >= semicolonCount && tabCount > 1) {
      return '\t';
    }
    if (semicolonCount > commaCount && semicolonCount > 1) return ';';
    return ',';
  }

  List<String> _splitRow(String line, String delimiter) {
    // Handle quoted fields
    final fields = <String>[];
    var inQuotes = false;
    final current = StringBuffer();

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == delimiter && !inQuotes) {
        fields.add(current.toString());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    fields.add(current.toString());
    return fields;
  }

  CsvColumnMapping? _autoDetectMapping(List<String> headers) {
    int? nameCol, typeCol, universeCol, addressCol, modeCol, groupCol;

    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().trim();
      if (_matches(h, ['name', 'fixture name', 'label', 'fixture'])) {
        nameCol ??= i;
      } else if (_matches(h, ['type', 'fixture type', 'model', 'fixture model'])) {
        typeCol ??= i;
      } else if (_matches(h, ['universe', 'uni', 'univ'])) {
        universeCol ??= i;
      } else if (_matches(h, ['address', 'addr', 'dmx', 'dmx address', 'start address', 'channel'])) {
        addressCol ??= i;
      } else if (_matches(h, ['mode', 'dmx mode', 'personality'])) {
        modeCol ??= i;
      } else if (_matches(h, ['group', 'group name', 'layer'])) {
        groupCol ??= i;
      }
    }

    // Must have at least name and address
    if (nameCol == null || addressCol == null) return null;

    return CsvColumnMapping(
      nameColumn: nameCol,
      fixtureTypeColumn: typeCol,
      universeColumn: universeCol,
      addressColumn: addressCol,
      modeColumn: modeCol,
      groupColumn: groupCol,
    );
  }

  bool _matches(String value, List<String> patterns) {
    return patterns.any((p) => value == p || value.replaceAll(RegExp(r'[_\-\s]+'), '') == p.replaceAll(RegExp(r'[_\-\s]+'), ''));
  }

  /// Parse various DMX address formats into (universe, address).
  ///
  /// Supported formats:
  ///   - "1.001" or "1.1" — universe.address
  ///   - "U1 A001" — universe/address prefix notation
  ///   - "1/001" — slash separator
  ///   - "001" or "1" — flat address (no universe, defaults to 0)
  ///   - "513" — flat address > 512 implies universe 1+ (auto-calculated)
  (int, int) _parseAddress({String? universeStr, required String addressStr}) {
    int universe = 0;
    int address = 1;

    // If universe column is provided, use it directly
    if (universeStr != null && universeStr.isNotEmpty) {
      universe = int.tryParse(universeStr) ?? 0;
      address = int.tryParse(addressStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      return (universe, address);
    }

    // Try "universe.address" format
    final dotMatch = RegExp(r'^(\d+)\.(\d+)$').firstMatch(addressStr);
    if (dotMatch != null) {
      universe = int.tryParse(dotMatch.group(1)!) ?? 0;
      address = int.tryParse(dotMatch.group(2)!) ?? 1;
      return (universe, address);
    }

    // Try "U1 A001" format
    final uaMatch =
        RegExp(r'[Uu](\d+)\s*[Aa](\d+)').firstMatch(addressStr);
    if (uaMatch != null) {
      universe = int.tryParse(uaMatch.group(1)!) ?? 0;
      address = int.tryParse(uaMatch.group(2)!) ?? 1;
      return (universe, address);
    }

    // Try "universe/address" format
    final slashMatch = RegExp(r'^(\d+)/(\d+)$').firstMatch(addressStr);
    if (slashMatch != null) {
      universe = int.tryParse(slashMatch.group(1)!) ?? 0;
      address = int.tryParse(slashMatch.group(2)!) ?? 1;
      return (universe, address);
    }

    // Flat address — calculate universe from absolute address
    final flat = int.tryParse(addressStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    if (flat > 512) {
      universe = (flat - 1) ~/ 512;
      address = ((flat - 1) % 512) + 1;
    } else {
      address = flat;
    }

    return (universe, address);
  }
}

/// Column mapping for CSV patch list parsing.
class CsvColumnMapping {
  final int nameColumn;
  final int? fixtureTypeColumn;
  final int? universeColumn;
  final int addressColumn;
  final int? modeColumn;
  final int? groupColumn;

  const CsvColumnMapping({
    required this.nameColumn,
    this.fixtureTypeColumn,
    this.universeColumn,
    required this.addressColumn,
    this.modeColumn,
    this.groupColumn,
  });

  int get maxColumn {
    var max = nameColumn;
    if (fixtureTypeColumn != null && fixtureTypeColumn! > max) max = fixtureTypeColumn!;
    if (universeColumn != null && universeColumn! > max) max = universeColumn!;
    if (addressColumn > max) max = addressColumn;
    if (modeColumn != null && modeColumn! > max) max = modeColumn!;
    if (groupColumn != null && groupColumn! > max) max = groupColumn!;
    return max;
  }
}

/// Preview of a CSV file's structure for the column mapping UI.
class CsvPreview {
  final List<String> headers;
  final List<List<String>> sampleRows;
  final String delimiter;
  final CsvColumnMapping? suggestedMapping;

  const CsvPreview({
    required this.headers,
    required this.sampleRows,
    required this.delimiter,
    this.suggestedMapping,
  });
}
