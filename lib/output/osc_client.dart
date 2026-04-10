import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// A self-contained OSC 1.0 (Open Sound Control) client over UDP.
///
/// Handles encoding and decoding of OSC messages with type tags
/// for int32 (i), float32 (f), string (s), and blob (b).
/// All values are 4-byte aligned per the OSC spec.
class OscClient {
  RawDatagramSocket? _socket;
  String? _ip;
  int _port = 0;
  bool _isConnected = false;

  final StreamController<OscMessage> _incomingController =
      StreamController<OscMessage>.broadcast();

  bool get isConnected => _isConnected;
  String? get ip => _ip;
  int get port => _port;

  /// Stream of incoming OSC messages.
  Stream<OscMessage> get incoming => _incomingController.stream;

  /// Connect to a target OSC server.
  Future<void> connect(String ip, int port) async {
    _ip = ip;
    _port = port;

    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) {
          final msg = decodeOscMessage(datagram.data);
          if (msg != null) {
            _incomingController.add(msg);
          }
        }
      }
    });

    _isConnected = true;
  }

  /// Send an OSC message.
  void send(String address, [List<dynamic>? args]) {
    if (!_isConnected || _socket == null) return;
    final msg = OscMessage(address: address, args: args ?? []);
    final encoded = encodeOscMessage(msg);
    _socket!.send(encoded, InternetAddress(_ip!), _port);
  }

  /// Subscribe to incoming messages matching an address prefix.
  Stream<OscMessage> subscribe(String addressPrefix) {
    return _incomingController.stream
        .where((msg) => msg.address.startsWith(addressPrefix));
  }

  /// Query a value by sending the address with no arguments.
  void query(String address) => send(address);

  /// Disconnect from the target.
  void disconnect() {
    _socket?.close();
    _socket = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _incomingController.close();
  }

  // ── Encoding ──

  /// Encode an OSC message to binary.
  static Uint8List encodeOscMessage(OscMessage msg) {
    final buffer = BytesBuilder();

    // Address
    _writeOscString(buffer, msg.address);

    // Type tag string
    final typeTags = StringBuffer(',');
    for (final arg in msg.args) {
      if (arg is int) {
        typeTags.write('i');
      } else if (arg is double) {
        typeTags.write('f');
      } else if (arg is String) {
        typeTags.write('s');
      } else if (arg is Uint8List) {
        typeTags.write('b');
      }
    }
    _writeOscString(buffer, typeTags.toString());

    // Arguments
    for (final arg in msg.args) {
      if (arg is int) {
        _writeInt32(buffer, arg);
      } else if (arg is double) {
        _writeFloat32(buffer, arg);
      } else if (arg is String) {
        _writeOscString(buffer, arg);
      } else if (arg is Uint8List) {
        _writeBlob(buffer, arg);
      }
    }

    return buffer.toBytes();
  }

  /// Decode an OSC message from binary.
  static OscMessage? decodeOscMessage(Uint8List data) {
    try {
      var offset = 0;

      // Address
      final addrResult = _readOscString(data, offset);
      final address = addrResult.$1;
      offset = addrResult.$2;

      // Type tag string
      final typeResult = _readOscString(data, offset);
      final typeTags = typeResult.$1;
      offset = typeResult.$2;

      // Arguments
      final args = <dynamic>[];
      for (var i = 1; i < typeTags.length; i++) {
        // skip leading ','
        switch (typeTags[i]) {
          case 'i':
            args.add(_readInt32(data, offset));
            offset += 4;
          case 'f':
            args.add(_readFloat32(data, offset));
            offset += 4;
          case 's':
            final strResult = _readOscString(data, offset);
            args.add(strResult.$1);
            offset = strResult.$2;
          case 'b':
            final blobResult = _readBlob(data, offset);
            args.add(blobResult.$1);
            offset = blobResult.$2;
        }
      }

      return OscMessage(address: address, args: args);
    } catch (_) {
      return null;
    }
  }

  // ── Private encoding helpers ──

  static void _writeOscString(BytesBuilder buffer, String s) {
    final bytes = s.codeUnits;
    buffer.add(bytes);
    // Null terminator + padding to 4-byte boundary
    final padded = _padTo4(bytes.length + 1);
    buffer.add(Uint8List(padded - bytes.length));
  }

  static void _writeInt32(BytesBuilder buffer, int value) {
    final data = ByteData(4);
    data.setInt32(0, value, Endian.big);
    buffer.add(data.buffer.asUint8List());
  }

  static void _writeFloat32(BytesBuilder buffer, double value) {
    final data = ByteData(4);
    data.setFloat32(0, value, Endian.big);
    buffer.add(data.buffer.asUint8List());
  }

  static void _writeBlob(BytesBuilder buffer, Uint8List blob) {
    _writeInt32(buffer, blob.length);
    buffer.add(blob);
    final remainder = blob.length % 4;
    if (remainder != 0) {
      buffer.add(Uint8List(4 - remainder));
    }
  }

  // ── Private decoding helpers ──

  static (String, int) _readOscString(Uint8List data, int offset) {
    final end = data.indexOf(0, offset);
    final str = String.fromCharCodes(data.sublist(offset, end));
    final nextOffset = _padTo4(end + 1);
    return (str, nextOffset);
  }

  static int _readInt32(Uint8List data, int offset) {
    return ByteData.view(data.buffer).getInt32(offset, Endian.big);
  }

  static double _readFloat32(Uint8List data, int offset) {
    return ByteData.view(data.buffer).getFloat32(offset, Endian.big);
  }

  static (Uint8List, int) _readBlob(Uint8List data, int offset) {
    final length = _readInt32(data, offset);
    offset += 4;
    final blob = Uint8List.fromList(data.sublist(offset, offset + length));
    offset += _padTo4(length);
    return (blob, offset);
  }

  static int _padTo4(int n) => (n + 3) & ~3;
}

/// A single OSC message.
class OscMessage {
  /// OSC address pattern (e.g., '/eos/cue/1/3.5/fire').
  final String address;

  /// Arguments: int, double, String, or Uint8List.
  final List<dynamic> args;

  const OscMessage({required this.address, this.args = const []});

  @override
  String toString() => 'OSC($address, $args)';
}
