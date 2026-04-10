/// Type-safe universe addressing that prevents off-by-one bugs
/// between Art-Net (0-indexed), sACN (1-indexed), and internal buffers.
///
/// All universe references in the SDK should use this type instead
/// of raw [int]. The canonical internal representation is 1-indexed
/// (DMX convention), matching what users see in the UI.
///
/// See RISKS_AND_MITIGATIONS.md RISK-08 and RISK-15.
class UniverseAddress implements Comparable<UniverseAddress> {
  /// The canonical universe number (1-indexed, DMX convention).
  /// This is what the user sees in the UI.
  final int dmxUniverse;

  /// Create from 1-indexed DMX universe number.
  const UniverseAddress(this.dmxUniverse)
      : assert(dmxUniverse >= 1 && dmxUniverse <= 63999,
            'DMX universe must be 1-63999, got $dmxUniverse');

  /// Create from a 0-indexed Art-Net universe number.
  factory UniverseAddress.fromArtNet(int artNetUniverse) =>
      UniverseAddress(artNetUniverse + 1);

  /// Create from a 1-indexed sACN universe number (same as DMX).
  factory UniverseAddress.fromSacn(int sacnUniverse) =>
      UniverseAddress(sacnUniverse);

  /// Create from a 0-indexed internal buffer index.
  factory UniverseAddress.fromBufferIndex(int index) =>
      UniverseAddress(index + 1);

  /// Convert to Art-Net wire format (0-indexed).
  /// Art-Net Universe 0 = DMX Universe 1.
  int get artNet => dmxUniverse - 1;

  /// Convert to sACN wire format (1-indexed, same as DMX).
  int get sacn => dmxUniverse;

  /// Convert to internal buffer index (0-indexed array).
  int get bufferIndex => dmxUniverse - 1;

  /// Compute the sACN multicast group address.
  /// Per E1.31: 239.255.{high}.{low} where universe is 1-indexed.
  String get sacnMulticast {
    final high = (dmxUniverse >> 8) & 0xFF;
    final low = dmxUniverse & 0xFF;
    return '239.255.$high.$low';
  }

  @override
  int compareTo(UniverseAddress other) =>
      dmxUniverse.compareTo(other.dmxUniverse);

  @override
  bool operator ==(Object other) =>
      other is UniverseAddress && other.dmxUniverse == dmxUniverse;

  @override
  int get hashCode => dmxUniverse.hashCode;

  @override
  String toString() => 'Universe $dmxUniverse';
}
