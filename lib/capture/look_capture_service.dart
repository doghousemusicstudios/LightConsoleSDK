import 'dart:typed_data';

import '../models/captured_look.dart';
import '../transport/dmx_input_service.dart';

/// Captures the console's current DMX output as a [CapturedLook].
///
/// This is the "take a photo of the lighting" feature. The house LD
/// programs a look on the console, and ShowUp captures it so the DJ
/// can recall it later without touching the console.
class LookCaptureService {
  final DmxInputService _dmxInput;

  LookCaptureService({required DmxInputService dmxInput})
      : _dmxInput = dmxInput;

  /// Capture the current DMX state from all active input universes.
  ///
  /// [id] — unique ID for this captured look.
  /// [name] — human-readable name.
  /// [universes] — specific universes to capture (1-based). If empty,
  ///   captures all active universes.
  CapturedLook captureNow({
    required String id,
    required String name,
    List<int> universes = const [],
  }) {
    final allData = _dmxInput.captureNow();
    final rawDmx = <int, Map<int, int>>{};

    final targetUniverses =
        universes.isEmpty ? allData.keys : universes;

    for (final universe in targetUniverses) {
      final data = allData[universe];
      if (data == null) continue;

      final channels = <int, int>{};
      for (var ch = 0; ch < 512; ch++) {
        if (data[ch] > 0) {
          channels[ch] = data[ch];
        }
      }

      if (channels.isNotEmpty) {
        rawDmx[universe] = channels;
      }
    }

    final dmxState = CapturedDmxState(
      rawDmx: rawDmx,
      captureSource: 'console',
      capturedAt: DateTime.now(),
    );

    // Attempt to estimate effect parameters from the raw DMX.
    final estimated = _estimateSnapshot(rawDmx);

    return CapturedLook(
      id: id,
      name: name,
      dmxState: dmxState,
      estimatedSnapshot: estimated,
    );
  }

  /// Convert raw DMX values back to a universe buffer for direct playback.
  ///
  /// Returns a map of universe (0-based) → 512-byte buffer.
  static Map<int, Uint8List> toUniverseBuffers(CapturedDmxState state) {
    final buffers = <int, Uint8List>{};

    for (final entry in state.rawDmx.entries) {
      final universe = entry.key - 1; // Convert to 0-based
      final buffer = Uint8List(512);

      for (final ch in entry.value.entries) {
        if (ch.key >= 0 && ch.key < 512) {
          buffer[ch.key] = ch.value.clamp(0, 255);
        }
      }

      buffers[universe] = buffer;
    }

    return buffers;
  }

  /// Estimate a LightLookSnapshot from raw DMX values.
  ///
  /// This is inherently lossy — we can extract static color and
  /// dimmer values, but dynamic effects (chases, rainbows) will be
  /// captured as a single freeze frame.
  ///
  /// Returns a Map matching LightLookSnapshot.toJson() format,
  /// or null if estimation is not possible.
  Map<String, dynamic>? _estimateSnapshot(Map<int, Map<int, int>> rawDmx) {
    if (rawDmx.isEmpty) return null;

    // Find average brightness across all channels
    var totalValue = 0;
    var channelCount = 0;

    for (final universe in rawDmx.values) {
      for (final value in universe.values) {
        totalValue += value;
        channelCount++;
      }
    }

    if (channelCount == 0) return null;

    final avgBrightness = totalValue / (channelCount * 255.0);

    // Static look with estimated dimmer
    return {
      'colorEffect': 'static_',
      'colorSpeed': 0.5,
      'colorSize': 0.5,
      'colorFade': 0.5,
      'colorPhase': 0.0,
      'paletteIndices': [16], // default white
      'movementEffect': 'static_',
      'movementSpeed': 0.5,
      'movementSize': 0.5,
      'movementFade': 0.5,
      'movementPhase': 0.0,
      'centreX': 0.5,
      'centreY': 0.5,
      'fan': 0.0,
      'mainDimmer': avgBrightness.clamp(0.0, 1.0),
    };
  }
}
