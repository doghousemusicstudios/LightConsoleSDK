import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// HTTP/JSON client for controlling Avolites Titan consoles via the WebAPI.
///
/// Titan exposes a REST-style HTTP API on port 4430 with endpoints for:
/// - Script execution: `/titan/script/{provider}/{method}?params`
/// - Property get/set: `/titan/get/{property}`, `/titan/set/{property}`
/// - Handle state: `/titan/handles/{group}/{page}`
///
/// Unlike OSC (fire-and-forget), every Titan HTTP command returns a JSON
/// response confirming execution. This makes diagnostics more reliable
/// than the OSC path for other consoles.
///
/// Used by the Bitfocus Companion Avolites module and the official
/// Titan Remote app (iOS/Android).
class HttpConsoleClient {
  String? _ip;
  int _port = 4430;
  bool _isConnected = false;
  HttpClient? _client;

  /// Timeout for individual HTTP requests.
  final Duration requestTimeout;

  HttpConsoleClient({
    this.requestTimeout = const Duration(seconds: 3),
  });

  bool get isConnected => _isConnected;
  String? get ip => _ip;
  int get port => _port;

  /// Connect to the Titan WebAPI.
  ///
  /// This doesn't establish a persistent connection (HTTP is stateless),
  /// but validates the console is reachable by requesting the version.
  Future<bool> connect(String ip, {int port = 4430}) async {
    _ip = ip;
    _port = port;
    _client = HttpClient();
    _client!.connectionTimeout = requestTimeout;

    // Validate connectivity with a version query
    try {
      final result = await getProperty('System', 'SoftwareVersion');
      _isConnected = result != null;
      return _isConnected;
    } catch (_) {
      _isConnected = false;
      return false;
    }
  }

  /// Get a console property.
  ///
  /// Returns the JSON-decoded response body, or null on failure.
  /// Example: `getProperty('System', 'SoftwareVersion')`
  Future<dynamic> getProperty(String provider, String property) async {
    return _get('/titan/get/$provider/$property');
  }

  /// Execute a script method on the console.
  ///
  /// [provider] — script provider (Playbacks, Fixtures, Masters, etc.)
  /// [method] — method name (FirePlaybackAtLevel, KillPlayback, etc.)
  /// [params] — query parameters as key-value pairs
  ///
  /// Returns the JSON-decoded response, or null on failure.
  Future<dynamic> executeScript(
    String provider,
    String method, {
    Map<String, String> params = const {},
  }) async {
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final path = '/titan/script/$provider/$method${query.isNotEmpty ? '?$query' : ''}';
    return _get(path);
  }

  /// Get handle information for a group (Playbacks, Fixtures, etc.).
  ///
  /// Returns a list of handle objects with titanId, type, legend,
  /// active status, and location.
  Future<List<dynamic>?> getHandles(String group, {int? page}) async {
    final path = page != null
        ? '/titan/handles/$group/$page'
        : '/titan/handles/$group';
    final result = await _get(path);
    if (result is List) return result;
    return null;
  }

  // ── Playback commands ──

  /// Fire a playback at a level (0.0-1.0).
  ///
  /// [userNumber] — the playback's user number (visible in Titan UI).
  /// [level] — intensity 0.0 (off) to 1.0 (full).
  Future<bool> firePlayback(int userNumber, {double level = 1.0}) async {
    final result = await executeScript('Playbacks', 'FirePlaybackAtLevel', params: {
      'userNumber': userNumber.toString(),
      'level': level.toString(),
    });
    return result != null;
  }

  /// Kill (release) a playback.
  Future<bool> killPlayback(int userNumber) async {
    final result = await executeScript('Playbacks', 'KillPlayback', params: {
      'userNumber': userNumber.toString(),
    });
    return result != null;
  }

  /// Kill all active playbacks.
  Future<bool> killAllPlaybacks() async {
    final result = await executeScript('Playbacks', 'KillAllPlaybacks');
    return result != null;
  }

  // ── State queries ──

  /// Get the show name.
  Future<String?> getShowName() async {
    final result = await getProperty('Show', 'ShowName');
    return result?.toString();
  }

  /// Get the software version.
  Future<String?> getSoftwareVersion() async {
    final result = await getProperty('System', 'SoftwareVersion');
    return result?.toString();
  }

  /// Get all playback handles with their active state.
  ///
  /// Returns a list of maps with keys: titanId, type, legend, active.
  Future<List<dynamic>?> getPlaybackState() async {
    return getHandles('Playbacks');
  }

  // ── Health check ──

  /// Ping the console. Returns true if the WebAPI responds.
  Future<bool> ping() async {
    try {
      final result = await getSoftwareVersion();
      return result != null;
    } catch (_) {
      return false;
    }
  }

  // ── Internal HTTP ──

  Future<dynamic> _get(String path) async {
    if (_ip == null || _client == null) return null;
    try {
      final uri = Uri.parse('http://$_ip:$_port$path');
      final request = await _client!.getUrl(uri);
      final response = await request.close().timeout(requestTimeout);
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      try {
        return jsonDecode(body);
      } catch (_) {
        return body; // Return raw string if not valid JSON
      }
    } catch (_) {
      return null;
    }
  }

  /// Disconnect and release resources.
  void disconnect() {
    _client?.close(force: true);
    _client = null;
    _isConnected = false;
  }

  void dispose() => disconnect();
}
