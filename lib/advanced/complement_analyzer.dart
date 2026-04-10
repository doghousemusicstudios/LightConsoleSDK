import 'dart:math';
import 'dart:typed_data';

/// Analyzes console DMX output and suggests complementary lighting
/// parameters for ShowUp's reactive layer.
///
/// When in layered coexistence mode, ShowUp should complement the
/// console's look rather than clash with it. This analyzer reads
/// the console's current DMX state and recommends:
///   - Complementary color palette
///   - Matching energy level (speed/movement)
///   - Contrast mode (warm console → cool ShowUp, or vice versa)
class ComplementAnalyzer {
  /// Analyze the console's DMX output and suggest complementary parameters.
  ///
  /// [consoleDmx] — raw DMX data from console-owned universes.
  ///   Key = universe (1-based), value = 512-byte DMX data.
  /// [fixtureChannels] — mapping of fixture name → list of
  ///   { 'channel': int (absolute), 'capability': String }.
  ///   Used to identify which channels are RGB vs dimmer vs movement.
  ComplementSuggestion analyze({
    required Map<int, Uint8List> consoleDmx,
    List<Map<String, dynamic>> fixtureChannels = const [],
  }) {
    // Extract dominant color from console output
    final dominantColor = _analyzeDominantColor(consoleDmx, fixtureChannels);

    // Compute complementary color (opposite on color wheel)
    final complementColor = _complementaryColor(dominantColor);

    // Estimate energy level from DMX activity
    final energyLevel = _analyzeEnergy(consoleDmx);

    // Suggest speed based on energy
    final suggestedSpeed = _suggestSpeed(energyLevel);

    return ComplementSuggestion(
      dominantConsoleColor: dominantColor,
      suggestedColor: complementColor,
      suggestedPaletteHue: _rgbToHue(complementColor),
      suggestedSpeed: suggestedSpeed,
      energyLevel: energyLevel,
      contrastMode: energyLevel > 0.6
          ? ContrastMode.complementary
          : ContrastMode.analogous,
    );
  }

  /// Analyze the dominant RGB color from console DMX data.
  (int, int, int) _analyzeDominantColor(
    Map<int, Uint8List> consoleDmx,
    List<Map<String, dynamic>> fixtureChannels,
  ) {
    var totalR = 0, totalG = 0, totalB = 0;
    var count = 0;

    if (fixtureChannels.isNotEmpty) {
      // Use fixture channel info if available
      for (final fixture in fixtureChannels) {
        final channels = fixture['channels'] as List<Map<String, dynamic>>?;
        if (channels == null) continue;

        int? r, g, b;
        for (final ch in channels) {
          final capability = ch['capability'] as String?;
          final channel = ch['channel'] as int?;
          final universe = ch['universe'] as int?;
          if (capability == null || channel == null || universe == null) continue;

          final dmx = consoleDmx[universe];
          if (dmx == null || channel >= 512) continue;

          final value = dmx[channel];
          if (capability == 'red') r = value;
          if (capability == 'green') g = value;
          if (capability == 'blue') b = value;
        }

        if (r != null && g != null && b != null) {
          totalR += r;
          totalG += g;
          totalB += b;
          count++;
        }
      }
    } else {
      // Fallback: scan for 3-channel RGB patterns in DMX data
      for (final data in consoleDmx.values) {
        for (var i = 0; i < 510; i += 3) {
          final r = data[i], g = data[i + 1], b = data[i + 2];
          if (r > 10 || g > 10 || b > 10) {
            totalR += r;
            totalG += g;
            totalB += b;
            count++;
          }
        }
      }
    }

    if (count == 0) return (128, 128, 128); // neutral gray

    return (totalR ~/ count, totalG ~/ count, totalB ~/ count);
  }

  /// Compute the complementary color (opposite on the HSV wheel).
  (int, int, int) _complementaryColor((int, int, int) rgb) {
    final (r, g, b) = rgb;

    // Convert RGB → HSV
    final rf = r / 255.0, gf = g / 255.0, bf = b / 255.0;
    final cMax = [rf, gf, bf].reduce(max);
    final cMin = [rf, gf, bf].reduce(min);
    final delta = cMax - cMin;

    double hue = 0;
    if (delta > 0) {
      if (cMax == rf) {
        hue = 60 * (((gf - bf) / delta) % 6);
      } else if (cMax == gf) {
        hue = 60 * ((bf - rf) / delta + 2);
      } else {
        hue = 60 * ((rf - gf) / delta + 4);
      }
    }
    if (hue < 0) hue += 360;

    // Rotate 180 degrees for complement
    final complementHue = (hue + 180) % 360;

    // Convert back to RGB (keep same saturation and value)
    final saturation = cMax > 0 ? delta / cMax : 0.0;
    final value = cMax;

    return _hsvToRgb(complementHue, saturation, value);
  }

  (int, int, int) _hsvToRgb(double h, double s, double v) {
    final c = v * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = v - c;

    double r, g, b;
    if (h < 60) {
      (r, g, b) = (c, x, 0.0);
    } else if (h < 120) {
      (r, g, b) = (x, c, 0.0);
    } else if (h < 180) {
      (r, g, b) = (0.0, c, x);
    } else if (h < 240) {
      (r, g, b) = (0.0, x, c);
    } else if (h < 300) {
      (r, g, b) = (x, 0.0, c);
    } else {
      (r, g, b) = (c, 0.0, x);
    }

    return (
      ((r + m) * 255).round().clamp(0, 255),
      ((g + m) * 255).round().clamp(0, 255),
      ((b + m) * 255).round().clamp(0, 255),
    );
  }

  double _rgbToHue((int, int, int) rgb) {
    final (r, g, b) = rgb;
    final rf = r / 255.0, gf = g / 255.0, bf = b / 255.0;
    final cMax = [rf, gf, bf].reduce(max);
    final cMin = [rf, gf, bf].reduce(min);
    final delta = cMax - cMin;

    if (delta == 0) return 0;

    double hue;
    if (cMax == rf) {
      hue = 60 * (((gf - bf) / delta) % 6);
    } else if (cMax == gf) {
      hue = 60 * ((bf - rf) / delta + 2);
    } else {
      hue = 60 * ((rf - gf) / delta + 4);
    }

    return hue < 0 ? hue + 360 : hue;
  }

  /// Estimate energy level from DMX data (0.0 = static/dim, 1.0 = bright/active).
  double _analyzeEnergy(Map<int, Uint8List> consoleDmx) {
    if (consoleDmx.isEmpty) return 0.5;

    var totalValue = 0;
    var channelCount = 0;

    for (final data in consoleDmx.values) {
      for (var i = 0; i < 512; i++) {
        if (data[i] > 0) {
          totalValue += data[i];
          channelCount++;
        }
      }
    }

    if (channelCount == 0) return 0.0;
    return (totalValue / (channelCount * 255.0)).clamp(0.0, 1.0);
  }

  /// Suggest effect speed based on console energy level.
  double _suggestSpeed(double energy) {
    // Match the console's energy: slow console → slow ShowUp
    return (energy * 0.8).clamp(0.1, 0.9);
  }
}

/// Suggested complementary parameters for ShowUp's reactive layer.
class ComplementSuggestion {
  /// The dominant RGB color detected in the console's output.
  final (int, int, int) dominantConsoleColor;

  /// Suggested complementary RGB color for ShowUp.
  final (int, int, int) suggestedColor;

  /// Hue angle (0-360) of the suggested color.
  final double suggestedPaletteHue;

  /// Suggested effect speed (0.0-1.0).
  final double suggestedSpeed;

  /// Estimated energy level of the console's current look (0.0-1.0).
  final double energyLevel;

  /// Recommended contrast strategy.
  final ContrastMode contrastMode;

  const ComplementSuggestion({
    required this.dominantConsoleColor,
    required this.suggestedColor,
    required this.suggestedPaletteHue,
    required this.suggestedSpeed,
    required this.energyLevel,
    required this.contrastMode,
  });
}

/// How ShowUp should contrast with the console's current look.
enum ContrastMode {
  /// Use complementary colors (opposite on color wheel).
  /// Best for high-energy scenes where ShowUp should stand out.
  complementary,

  /// Use analogous colors (adjacent on color wheel).
  /// Best for low-energy scenes where ShowUp should blend in.
  analogous,
}
