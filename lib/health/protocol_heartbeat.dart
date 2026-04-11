import 'dart:async';
import 'dart:io';

import '../models/console_profile.dart';
import '../output/osc_client.dart';
import '../output/telnet_client.dart';
import 'console_health_monitor.dart';

/// Monitors console health using validated protocol-level strategies.
///
/// Each console family uses a different approach, discovered via live
/// testing against real console software (2026-04-11):
///
/// - **Eos:** TCP SLIP push stream on 3037 — listen for /eos/out/ data
/// - **MA3:** HTTP GET on port 8080 — check for HTTP 200
/// - **MagicQ:** TCP connect on port 4914 — connection accepted = alive
/// - **Onyx:** Telnet QLActive on port 2323 — TCP + command response
///
/// The heartbeat emits [ConsoleHealthEvent]s compatible with
/// [ConsoleHealthMonitor.fromStream()].
class ProtocolHeartbeat {
  final HeartbeatConfig _config;
  final OscClient? _oscClient;
  final TelnetClient? _telnetClient;
  final String _consoleIp;

  /// How often to check (derived from FailoverConfig.timeoutSeconds).
  final Duration interval;

  /// Number of consecutive failures before declaring offline.
  final int missedThreshold;

  Timer? _timer;
  int _missedCount = 0;
  bool _isOnline = false;
  bool _wasOnline = false;

  /// For tcpPushStream: subscription to the OSC incoming stream.
  StreamSubscription<OscMessage>? _pushStreamSub;
  DateTime? _lastPushReceived;

  /// For tcpConnect: dedicated socket for heartbeat (not the control socket).
  Socket? _heartbeatSocket;

  final StreamController<ConsoleHealthEvent> _eventController =
      StreamController<ConsoleHealthEvent>.broadcast();

  ProtocolHeartbeat({
    required HeartbeatConfig config,
    required String consoleIp,
    OscClient? oscClient,
    TelnetClient? telnetClient,
    this.interval = const Duration(seconds: 5),
    this.missedThreshold = 3,
  })  : _config = config,
        _consoleIp = consoleIp,
        _oscClient = oscClient,
        _telnetClient = telnetClient;

  /// Create from a FailoverConfig, wiring timeoutSeconds to interval/threshold.
  factory ProtocolHeartbeat.fromFailoverConfig({
    required HeartbeatConfig heartbeatConfig,
    required String consoleIp,
    required int timeoutSeconds,
    OscClient? oscClient,
    TelnetClient? telnetClient,
  }) {
    // Distribute timeout across interval * threshold.
    // E.g., 15s timeout → 5s interval, 3 misses.
    final intervalSec = (timeoutSeconds / 3).ceil().clamp(1, 30);
    final threshold = (timeoutSeconds / intervalSec).ceil().clamp(2, 10);

    return ProtocolHeartbeat(
      config: heartbeatConfig,
      consoleIp: consoleIp,
      oscClient: oscClient,
      telnetClient: telnetClient,
      interval: Duration(seconds: intervalSec),
      missedThreshold: threshold,
    );
  }

  /// Stream of health events for [ConsoleHealthMonitor.fromStream()].
  Stream<ConsoleHealthEvent> get events => _eventController.stream;

  /// Whether the console is currently responding.
  bool get isOnline => _isOnline;

  /// The active heartbeat strategy.
  HeartbeatStrategy get strategy => _config.strategy;

  /// Start the heartbeat.
  void start() {
    if (_config.strategy == HeartbeatStrategy.none) return;

    // For push-based streams, set up the listener immediately.
    if (_config.strategy == HeartbeatStrategy.tcpPushStream &&
        _oscClient != null) {
      _startPushStreamMonitor();
    }

    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _check());
  }

  /// Stop the heartbeat.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _pushStreamSub?.cancel();
    _pushStreamSub = null;
    _heartbeatSocket?.destroy();
    _heartbeatSocket = null;
  }

  void _startPushStreamMonitor() {
    final prefix = _config.streamPrefix;
    _pushStreamSub = _oscClient!.incoming
        .where((msg) => prefix == null || msg.address.startsWith(prefix))
        .listen((_) {
      _lastPushReceived = DateTime.now();
    });
  }

  Future<void> _check() async {
    final alive = await _probe();

    if (alive) {
      _missedCount = 0;
      if (!_isOnline) {
        _isOnline = true;
        _eventController.add(ConsoleHealthEvent(
          type: _wasOnline
              ? ConsoleHealthEventType.reconnected
              : ConsoleHealthEventType.online,
          timestamp: DateTime.now(),
        ));
        _wasOnline = true;
      }
    } else {
      _missedCount++;
      if (_missedCount >= missedThreshold && _isOnline) {
        _isOnline = false;
        _eventController.add(ConsoleHealthEvent(
          type: ConsoleHealthEventType.offline,
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  Future<bool> _probe() async {
    try {
      switch (_config.strategy) {
        case HeartbeatStrategy.tcpPushStream:
          return _probePushStream();
        case HeartbeatStrategy.httpGet:
          return await _probeHttp();
        case HeartbeatStrategy.tcpConnect:
          return await _probeTcpConnect();
        case HeartbeatStrategy.telnetPoll:
          return _probeTelnet();
        case HeartbeatStrategy.none:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Eos: check if push stream data was received recently.
  bool _probePushStream() {
    if (_lastPushReceived == null) {
      // Haven't received anything yet — check if OSC client is connected.
      return _oscClient?.isConnected ?? false;
    }
    final elapsed = DateTime.now().difference(_lastPushReceived!);
    // Eos pushes at ~10Hz. If no data for 2x the heartbeat interval,
    // consider it dead.
    return elapsed < interval * 2;
  }

  /// MA3: HTTP GET to the web remote.
  Future<bool> _probeHttp() async {
    final port = _config.port ?? 8080;
    final path = _config.httpPath;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(
          Uri.parse('http://$_consoleIp:$port$path'));
      final response = await request.close();
      await response.drain<void>();
      client.close(force: true);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// MQ: TCP connect to heartbeat port — connection accepted = alive.
  Future<bool> _probeTcpConnect() async {
    final port = _config.port;
    if (port == null) return false;
    try {
      final socket = await Socket.connect(_consoleIp, port,
          timeout: const Duration(seconds: 3));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Onyx: Telnet connection state is the primary signal.
  ///
  /// TCP is connection-oriented — if the socket is connected,
  /// the console process is alive. Unlike UDP (where "connected"
  /// just means our local socket is open), a TCP socket's connected
  /// state means the remote accepted our handshake.
  ///
  /// We also send QLActive as a keep-alive to detect stale connections
  /// where the remote died without sending FIN, but the return value
  /// only confirms the write buffer accepted the data — it does not
  /// confirm the console processed it. TCP keepalive on the socket
  /// handles the stale-connection case at the OS level.
  bool _probeTelnet() {
    if (_telnetClient == null) return false;
    if (!_telnetClient.isConnected) return false;
    // Send QLActive as keep-alive. If the socket is dead, this will
    // trigger onDone/onError on the next event loop, updating
    // isConnected to false for the next probe cycle.
    _telnetClient.requestActiveCuelists();
    return true; // TCP connected = alive. Dead socket detected next cycle.
  }

  void dispose() {
    stop();
    _eventController.close();
  }
}
