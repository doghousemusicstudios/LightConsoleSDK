import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A TCP/Telnet client for controlling Obsidian Onyx via Onyx Manager.
///
/// Onyx Manager exposes a Telnet API on port 2323 that accepts ASCII
/// commands terminated by \r\n and returns multi-line responses with
/// HTTP-style status codes.
///
/// Commands: GQL, GTQ, RQL, PQL, SQL, RAQL, RAQLO, RAQLDF, RAO,
/// CLRCLR, QLList, QLActive, IsQLActive.
///
/// See SHOWUP_CONSOLE_TRANSLATOR.md for full command reference.
class TelnetClient {
  Socket? _socket;
  String? _ip;
  int _port = 2323;
  bool _isConnected = false;
  bool _isConnecting = false;

  final StreamController<TelnetResponse> _responseController =
      StreamController<TelnetResponse>.broadcast();

  /// Accumulator for incoming data across TCP segments.
  final StringBuffer _receiveBuffer = StringBuffer();

  /// TCP keepalive interval for detecting dead connections.
  final Duration keepaliveInterval;

  /// Reconnection state.
  Timer? _reconnectTimer;
  Duration _reconnectDelay = const Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  static const double _backoffMultiplier = 2.0;

  /// Whether auto-reconnect is enabled.
  bool autoReconnect;

  TelnetClient({
    this.keepaliveInterval = const Duration(seconds: 5),
    this.autoReconnect = true,
  });

  bool get isConnected => _isConnected;
  String? get ip => _ip;
  int get port => _port;

  /// Stream of parsed responses from the console.
  Stream<TelnetResponse> get responses => _responseController.stream;

  /// Connect to Onyx Manager's Telnet server.
  Future<void> connect(String ip, {int port = 2323}) async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;
    _ip = ip;
    _port = port;

    try {
      _socket = await Socket.connect(ip, port,
          timeout: const Duration(seconds: 5));
      _isConnected = true;
      _isConnecting = false;
      _reconnectDelay = const Duration(seconds: 1);

      // Enable TCP keepalive so dead connections are detected by the OS.
      _socket!.setOption(SocketOption.tcpNoDelay, true);

      _socket!.listen(
        _onData,
        onError: (_) => _onDisconnect(),
        onDone: _onDisconnect,
      );
    } catch (_) {
      _isConnecting = false;
      _isConnected = false;
      rethrow;
    }
  }

  void _onData(Uint8List data) {
    _receiveBuffer.write(utf8.decode(data, allowMalformed: true));
    _tryParseResponses();
  }

  void _tryParseResponses() {
    final content = _receiveBuffer.toString();
    // Responses end with a line containing just "." or a status line
    // matching the pattern: NNN text\r\n
    // For simplicity, split on double CRLF or ".\r\n" terminator.
    final terminatorIndex = content.indexOf('.\r\n');
    if (terminatorIndex >= 0) {
      final responseText = content.substring(0, terminatorIndex);
      _receiveBuffer.clear();
      final remaining = content.substring(terminatorIndex + 3);
      if (remaining.isNotEmpty) _receiveBuffer.write(remaining);

      _responseController.add(TelnetResponse.parse(responseText));
    }
  }

  void _onDisconnect() {
    _isConnected = false;
    _socket = null;
    if (autoReconnect && _ip != null) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      try {
        await connect(_ip!, port: _port);
      } catch (_) {
        _reconnectDelay = Duration(
          milliseconds:
              (_reconnectDelay.inMilliseconds * _backoffMultiplier).toInt(),
        );
        if (_reconnectDelay > _maxReconnectDelay) {
          _reconnectDelay = _maxReconnectDelay;
        }
        _scheduleReconnect();
      }
    });
  }

  /// Send a raw Telnet command. Appends \r\n automatically.
  ///
  /// Returns false if not connected (diagnostic-honest).
  bool sendCommand(String command) {
    if (!_isConnected || _socket == null) return false;
    _socket!.write('$command\r\n');
    return true;
  }

  /// Fire a cuelist (GQL command).
  bool fireCuelist(int cuelistNumber) =>
      sendCommand('GQL $cuelistNumber');

  /// Go to a specific cue within a cuelist (GTQ command).
  bool goToCue(int cuelistNumber, int cueNumber) =>
      sendCommand('GTQ $cuelistNumber,$cueNumber');

  /// Release a cuelist (RQL command).
  bool releaseCuelist(int cuelistNumber) =>
      sendCommand('RQL $cuelistNumber');

  /// Pause a cuelist (PQL command).
  bool pauseCuelist(int cuelistNumber) =>
      sendCommand('PQL $cuelistNumber');

  /// Set a cuelist fader level 0-255 (SQL command).
  bool setCuelistLevel(int cuelistNumber, int level) =>
      sendCommand('SQL $cuelistNumber,${level.clamp(0, 255)}');

  /// Release all cuelists (RAQL command).
  bool releaseAll() => sendCommand('RAQL');

  /// Release all cuelists and overrides (RAQLO command).
  bool releaseAllWithOverrides() => sendCommand('RAQLO');

  /// Release all cuelists dimmer first (RAQLDF command).
  bool releaseAllDimmerFirst() => sendCommand('RAQLDF');

  /// Release all override cuelists (RAO command).
  bool releaseAllOverrides() => sendCommand('RAO');

  /// Clear the programmer (CLRCLR command).
  bool clearProgrammer() => sendCommand('CLRCLR');

  /// Request the list of all cuelists (QLList command).
  bool requestCuelists() => sendCommand('QLList');

  /// Request the list of active cuelists (QLActive command).
  bool requestActiveCuelists() => sendCommand('QLActive');

  /// Check if a specific cuelist is active (IsQLActive command).
  bool requestIsCuelistActive(int cuelistNumber) =>
      sendCommand('IsQLActive $cuelistNumber');

  /// Disconnect cleanly (BYE command).
  Future<void> disconnect() async {
    autoReconnect = false;
    _reconnectTimer?.cancel();
    if (_isConnected && _socket != null) {
      sendCommand('BYE');
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await _socket?.close();
    _socket = null;
    _isConnected = false;
  }

  void dispose() {
    autoReconnect = false;
    _reconnectTimer?.cancel();
    _socket?.destroy();
    _socket = null;
    _isConnected = false;
    _responseController.close();
    _receiveBuffer.clear();
  }
}

/// A parsed response from the Onyx Telnet API.
class TelnetResponse {
  /// HTTP-style status code (e.g., 200, 404).
  final int? statusCode;

  /// Response text lines.
  final List<String> lines;

  /// Raw response text.
  final String raw;

  const TelnetResponse({
    this.statusCode,
    this.lines = const [],
    this.raw = '',
  });

  /// Whether the response indicates success (2xx status).
  bool get isSuccess =>
      statusCode != null && statusCode! >= 200 && statusCode! < 300;

  /// Parse cuelists from a QLList response.
  /// Format: "00001 - House Lights"
  List<OnyxCuelist> parseCuelists() {
    final result = <OnyxCuelist>[];
    final pattern = RegExp(r'^(\d+)\s*-\s*(.+)$');
    for (final line in lines) {
      final match = pattern.firstMatch(line.trim());
      if (match != null) {
        result.add(OnyxCuelist(
          number: int.tryParse(match.group(1)!) ?? 0,
          name: match.group(2)!.trim(),
        ));
      }
    }
    return result;
  }

  /// Parse a raw Telnet response string.
  factory TelnetResponse.parse(String text) {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.isNotEmpty).toList();
    int? statusCode;

    // Try to extract status code from first or last line
    final statusPattern = RegExp(r'^(\d{3})[- ]');
    for (final line in lines) {
      final match = statusPattern.firstMatch(line);
      if (match != null) {
        statusCode = int.tryParse(match.group(1)!);
        break;
      }
    }

    // Filter out status lines for the content
    final contentLines = lines
        .where((l) => !statusPattern.hasMatch(l))
        .toList();

    return TelnetResponse(
      statusCode: statusCode,
      lines: contentLines,
      raw: text,
    );
  }
}

/// An Onyx cuelist parsed from a QLList response.
class OnyxCuelist {
  final int number;
  final String name;

  const OnyxCuelist({required this.number, required this.name});

  @override
  String toString() => 'OnyxCuelist($number: $name)';
}
