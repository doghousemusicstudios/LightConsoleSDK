import '../models/console_profile.dart';
import '../profiles/chamsys_mq.dart';
import '../profiles/etc_eos.dart';
import '../profiles/grandma3.dart';
import '../profiles/avolites_titan.dart';
import '../profiles/onyx.dart';

/// Registry of known lighting console profiles.
///
/// Ships with built-in profiles for GrandMA3, ETC Eos, ChamSys MagicQ,
/// Obsidian Onyx, and Avolites Titan. Users can add custom profiles.
class ConsoleProfilesRegistry {
  final Map<String, ConsoleProfile> _profiles = {};

  ConsoleProfilesRegistry() {
    // Register built-in profiles.
    register(grandMa3Profile);
    register(etcEosProfile);
    register(chamsysMqProfile);
    register(onyxProfile);
    register(avolitesProfile);
  }

  /// All registered profiles.
  Iterable<ConsoleProfile> get profiles => _profiles.values;

  /// Get a profile by ID.
  ConsoleProfile? getProfile(String id) => _profiles[id];

  /// Register a new profile (or replace an existing one).
  void register(ConsoleProfile profile) {
    _profiles[profile.id] = profile;
  }

  /// Remove a profile by ID.
  void remove(String id) {
    _profiles.remove(id);
  }

  /// Try to match ArtPoll reply data against known profiles.
  /// Returns the first matching profile, or null.
  ConsoleProfile? detectFromArtPoll({
    required int oemCode,
    required String shortName,
    required String longName,
    int? estaCode,
  }) {
    for (final profile in _profiles.values) {
      if (profile.detection.matches(
        oemCode: oemCode,
        shortName: shortName,
        longName: longName,
        estaCode: estaCode,
      )) {
        return profile;
      }
    }
    return null;
  }
}
