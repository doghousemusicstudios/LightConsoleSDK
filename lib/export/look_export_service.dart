/// Exports a lighting look as a CSV table of DMX channel values.
///
/// The exported CSV can be used by console LDs to see exactly what
/// ShowUp is doing, or imported into some consoles as presets.
class LookExportService {
  /// Export a look as a CSV string.
  ///
  /// [fixtureData] — list of fixture data to export. Each item contains:
  ///   - 'name': fixture name
  ///   - 'universe': 0-based universe index
  ///   - 'startAddress': 1-based start address
  ///   - 'channels': list of { 'offset': int, 'value': int, 'parameter': String }
  ///
  /// Returns a CSV string with headers:
  ///   Fixture, Universe, Address, Channel, Value, Parameter
  String exportAsCsv(List<Map<String, dynamic>> fixtureData) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('"Fixture","Universe","Address","Channel","Value","Parameter"');

    // Data rows
    for (final fixture in fixtureData) {
      final name = fixture['name'] as String? ?? 'Unknown';
      final universe = fixture['universe'] as int? ?? 0;
      final startAddress = fixture['startAddress'] as int? ?? 1;
      final channels = fixture['channels'] as List<Map<String, dynamic>>? ?? [];

      for (final channel in channels) {
        final offset = channel['offset'] as int? ?? 0;
        final value = channel['value'] as int? ?? 0;
        final parameter = channel['parameter'] as String? ?? 'Unknown';
        final absoluteAddress = startAddress + offset;

        buffer.writeln(
            '"$name",$universe,$absoluteAddress,$offset,$value,"$parameter"');
      }
    }

    return buffer.toString();
  }

  /// Export raw captured DMX state as a CSV.
  ///
  /// [rawDmx] — map of universe (1-based) → channel (0-based) → value.
  String exportRawDmxAsCsv(Map<int, Map<int, int>> rawDmx) {
    final buffer = StringBuffer();
    buffer.writeln('"Universe","Channel","Address","Value"');

    for (final uEntry in rawDmx.entries) {
      final universe = uEntry.key;
      final sortedChannels = uEntry.value.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      for (final chEntry in sortedChannels) {
        final channel = chEntry.key;
        final address = channel + 1; // Convert to 1-based DMX address
        final value = chEntry.value;

        buffer.writeln('$universe,$channel,$address,$value');
      }
    }

    return buffer.toString();
  }
}
