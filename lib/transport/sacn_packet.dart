import 'dart:typed_data';

/// E1.31 (sACN) packet construction per ANSI E1.31-2018.
///
/// Packet structure:
///   Root Layer (38 bytes) → Framing Layer (77 bytes) → DMP Layer (523 bytes)
///   Total: 638 bytes for a full 512-channel universe.
class SacnPacket {
  /// ACN packet identifier (12 bytes).
  static const List<int> _acnPacketIdentifier = [
    0x41, 0x53, 0x43, 0x2D, 0x45, 0x31, 0x2E, 0x31, 0x37, 0x00, 0x00, 0x00,
  ];

  /// Root layer vector for E1.31 data packets.
  static const int _rootVector = 0x00000004;

  /// Framing layer vector for E1.31 data packets.
  static const int _framingVector = 0x00000002;

  /// DMP layer vector.
  static const int _dmpVector = 0x02;

  /// Full packet size for 512 channels.
  static const int packetSize = 638;

  /// Build a complete E1.31 data packet.
  ///
  /// [universe] — sACN universe number (1-63999).
  /// [dmxData] — 512 bytes of DMX channel data.
  /// [priority] — sACN priority (0-200, default 100).
  /// [sequence] — sequence number (0-255, should increment per universe).
  /// [sourceName] — source name (max 64 chars, padded with nulls).
  /// [cid] — Component Identifier (16 bytes UUID). If null, uses a default.
  static Uint8List buildDataPacket({
    required int universe,
    required Uint8List dmxData,
    int priority = 100,
    int sequence = 0,
    String sourceName = 'ShowUp',
    Uint8List? cid,
  }) {
    assert(dmxData.length == 512, 'DMX data must be exactly 512 bytes');
    assert(universe >= 1 && universe <= 63999, 'Universe must be 1-63999');
    assert(priority >= 0 && priority <= 200, 'Priority must be 0-200');

    final packet = Uint8List(packetSize);
    final data = ByteData.view(packet.buffer);
    var offset = 0;

    // ── Root Layer (38 bytes) ──

    // Preamble Size (2 bytes, big-endian) = 0x0010
    data.setUint16(offset, 0x0010, Endian.big);
    offset += 2;

    // Postamble Size (2 bytes) = 0x0000
    data.setUint16(offset, 0x0000, Endian.big);
    offset += 2;

    // ACN Packet Identifier (12 bytes)
    packet.setRange(offset, offset + 12, _acnPacketIdentifier);
    offset += 12;

    // Flags & Length (2 bytes) — low 12 bits = length of remaining root layer
    // Remaining from here: 2 (this field counted from after flags) + 4 (vector) + 16 (CID) + framing + DMP
    final rootRemaining = packetSize - offset;
    data.setUint16(offset, 0x7000 | (rootRemaining & 0x0FFF), Endian.big);
    offset += 2;

    // Vector (4 bytes) — identifies this as E1.31 data
    data.setUint32(offset, _rootVector, Endian.big);
    offset += 4;

    // CID — Component Identifier (16 bytes UUID)
    final cidBytes = cid ?? _defaultCid();
    packet.setRange(offset, offset + 16, cidBytes);
    offset += 16;

    // ── Framing Layer (77 bytes) ──

    // Flags & Length (2 bytes)
    final framingRemaining = packetSize - offset;
    data.setUint16(offset, 0x7000 | (framingRemaining & 0x0FFF), Endian.big);
    offset += 2;

    // Vector (4 bytes)
    data.setUint32(offset, _framingVector, Endian.big);
    offset += 4;

    // Source Name (64 bytes, null-terminated, padded)
    final nameBytes = sourceName.codeUnits;
    final nameLen = nameBytes.length.clamp(0, 63);
    packet.setRange(offset, offset + nameLen, nameBytes.sublist(0, nameLen));
    // Rest is already zero-filled
    offset += 64;

    // Priority (1 byte)
    packet[offset] = priority.clamp(0, 200);
    offset += 1;

    // Synchronization Address (2 bytes) — 0 = no sync
    data.setUint16(offset, 0, Endian.big);
    offset += 2;

    // Sequence Number (1 byte)
    packet[offset] = sequence & 0xFF;
    offset += 1;

    // Options (1 byte) — 0 = no options
    packet[offset] = 0;
    offset += 1;

    // Universe (2 bytes, big-endian)
    data.setUint16(offset, universe, Endian.big);
    offset += 2;

    // ── DMP Layer (523 bytes) ──

    // Flags & Length (2 bytes)
    final dmpRemaining = packetSize - offset;
    data.setUint16(offset, 0x7000 | (dmpRemaining & 0x0FFF), Endian.big);
    offset += 2;

    // Vector (1 byte)
    packet[offset] = _dmpVector;
    offset += 1;

    // Address Type & Data Type (1 byte) = 0xA1
    packet[offset] = 0xA1;
    offset += 1;

    // First Property Address (2 bytes) = 0x0000
    data.setUint16(offset, 0x0000, Endian.big);
    offset += 2;

    // Address Increment (2 bytes) = 0x0001
    data.setUint16(offset, 0x0001, Endian.big);
    offset += 2;

    // Property Value Count (2 bytes) = 513 (1 start code + 512 channels)
    data.setUint16(offset, 513, Endian.big);
    offset += 2;

    // Start Code (1 byte) = 0x00 (DMX512 data)
    packet[offset] = 0x00;
    offset += 1;

    // DMX Channel Data (512 bytes)
    packet.setRange(offset, offset + 512, dmxData);

    return packet;
  }

  /// Compute the multicast address for a given sACN universe.
  ///
  /// Per E1.31: `239.255.{universe_high}.{universe_low}`
  static String multicastAddress(int universe) {
    final high = (universe >> 8) & 0xFF;
    final low = universe & 0xFF;
    return '239.255.$high.$low';
  }

  /// Default CID (Component Identifier) — a fixed UUID for ShowUp.
  /// In production, this should be unique per device.
  static Uint8List _defaultCid() {
    // ShowUp sACN CID: 53686F77-5570-4C69-6768-74436F6E736F
    // Encodes "ShowUpLightConso" in ASCII-like hex
    return Uint8List.fromList([
      0x53, 0x68, 0x6F, 0x77, 0x55, 0x70, 0x4C, 0x69,
      0x67, 0x68, 0x74, 0x43, 0x6F, 0x6E, 0x73, 0x6F,
    ]);
  }

  /// Parse the universe number from a received E1.31 packet.
  /// Returns null if the packet is invalid.
  static int? parseUniverse(Uint8List packet) {
    if (packet.length < packetSize) return null;
    // Universe is at framing layer offset: 38 (root) + 2 (flags) + 4 (vector) + 64 (name) + 1 (priority) + 2 (sync) + 1 (seq) + 1 (options) = 113
    final data = ByteData.view(packet.buffer);
    return data.getUint16(113, Endian.big);
  }

  /// Parse priority from a received E1.31 packet.
  static int? parsePriority(Uint8List packet) {
    if (packet.length < packetSize) return null;
    // Priority is at: 38 (root) + 2 (flags) + 4 (vector) + 64 (name) = 108
    return packet[108];
  }

  /// Parse the source name from a received E1.31 packet.
  static String? parseSourceName(Uint8List packet) {
    if (packet.length < packetSize) return null;
    // Source name starts at: 38 (root) + 2 (flags) + 4 (vector) = 44
    final nameBytes = packet.sublist(44, 44 + 64);
    final nullIndex = nameBytes.indexOf(0);
    final length = nullIndex >= 0 ? nullIndex : 64;
    return String.fromCharCodes(nameBytes.sublist(0, length));
  }

  /// Extract DMX data (512 bytes) from a received E1.31 packet.
  static Uint8List? parseDmxData(Uint8List packet) {
    if (packet.length < packetSize) return null;
    // DMX data starts at: 126 (after DMP header) = offset 126
    // Root(38) + FramingFlags(2) + FramingVector(4) + Name(64) + Priority(1) + Sync(2) + Seq(1) + Options(1) + Universe(2) + DMPFlags(2) + DMPVector(1) + AddrType(1) + FirstAddr(2) + AddrIncr(2) + PropCount(2) + StartCode(1) = 126
    return Uint8List.fromList(packet.sublist(126, 126 + 512));
  }
}
