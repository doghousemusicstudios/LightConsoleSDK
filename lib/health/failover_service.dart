import 'dart:async';

import '../models/coexistence_config.dart';
import '../models/universe_role.dart';
import 'console_health_monitor.dart';

/// Automatically takes over console-owned universes when the console
/// goes offline, and hands them back when the console returns.
///
/// Implements the safety behavior documented in RISKS_AND_MITIGATIONS.md:
/// - Respects [FailoverConfig.requireConfirmation] before acting
/// - Reports [FailoverConfig.fallbackMode] to the host for look selection
/// - Reports [FailoverConfig.fadeInMs] / [fadeBackMs] for transition timing
/// - Will not double-activate on repeated offline events
class FailoverService {
  final ConsoleHealthMonitor _healthMonitor;
  final FailoverConfig _config;

  /// Callback: invoked when failover activates (after confirmation if required).
  /// [overriddenUniverses] — universes that ShowUp is now controlling.
  void Function(List<int> overriddenUniverses)? onFailoverActivated;

  /// Callback: invoked when failover deactivates (console is back).
  /// [restoredUniverses] — universes returned to console control.
  void Function(List<int> restoredUniverses)? onFailoverDeactivated;

  /// Callback: request to change universe roles.
  /// The host app should update its CoexistenceConfig and DmxEngine.
  void Function(Map<int, UniverseRole> newRoles)? onUniverseRolesChanged;

  /// Callback: invoked when failover wants to activate but
  /// [FailoverConfig.requireConfirmation] is true. The host app should
  /// show a confirmation dialog. Call [confirmFailover] to proceed,
  /// or [cancelFailover] to reject.
  void Function(List<int> pendingUniverses)? onConfirmationRequired;

  StreamSubscription<ConsoleHealthEvent>? _healthSub;
  bool _isFailoverActive = false;
  bool _isPendingConfirmation = false;
  final List<int> _overriddenUniverses = [];
  List<int> _pendingUniverses = [];

  /// The original universe roles before failover.
  Map<int, UniverseConfig>? _originalRoles;

  FailoverService({
    required ConsoleHealthMonitor healthMonitor,
    FailoverConfig? config,
  })  : _healthMonitor = healthMonitor,
        _config = config ?? const FailoverConfig();

  /// The active failover configuration.
  FailoverConfig get config => _config;

  /// Whether failover is currently active (universes are overridden).
  bool get isFailoverActive => _isFailoverActive;

  /// Whether failover is waiting for operator confirmation.
  bool get isPendingConfirmation => _isPendingConfirmation;

  /// Universes currently overridden by failover.
  List<int> get overriddenUniverses =>
      List.unmodifiable(_overriddenUniverses);

  /// The fallback mode that will be (or was) applied on failover.
  /// Host app uses this to select the appropriate look.
  FailoverMode get fallbackMode => _config.fallbackMode;

  /// Fade-in duration (ms) when taking over. Host app applies this
  /// to its transition engine for a smooth takeover.
  int get fadeInMs => _config.fadeInMs;

  /// Fade-back duration (ms) when returning control. Host app applies
  /// this for a smooth handback.
  int get fadeBackMs => _config.fadeBackMs;

  /// Start watching for console offline events.
  ///
  /// [universeRoles] — the current universe role assignments.
  void start(Map<int, UniverseConfig> universeRoles) {
    if (!_config.enabled) return;
    _originalRoles = Map.from(universeRoles);

    _healthSub = _healthMonitor.events.listen((event) {
      switch (event.type) {
        case ConsoleHealthEventType.offline:
          _handleOffline();
        case ConsoleHealthEventType.reconnected:
        case ConsoleHealthEventType.online:
          if (_isFailoverActive) {
            _deactivateFailover();
          } else if (_isPendingConfirmation) {
            // Console came back while we were waiting for confirmation.
            // Cancel the pending failover.
            _isPendingConfirmation = false;
            _pendingUniverses = [];
          }
      }
    });
  }

  void _handleOffline() {
    if (_isFailoverActive || _isPendingConfirmation || _originalRoles == null) {
      return;
    }

    // Identify console-owned universes that would be taken over.
    final universes = <int>[];
    for (final entry in _originalRoles!.entries) {
      if (entry.value.role == UniverseRole.consoleOwned) {
        universes.add(entry.key);
      }
    }

    if (universes.isEmpty) return;

    if (_config.requireConfirmation) {
      // Don't activate yet — ask the operator to confirm.
      _isPendingConfirmation = true;
      _pendingUniverses = universes;
      onConfirmationRequired?.call(List.from(universes));
    } else {
      // No confirmation needed — activate immediately.
      _activateFailover(universes);
    }
  }

  /// Called by the host app when the operator confirms failover.
  /// Only meaningful when [isPendingConfirmation] is true.
  void confirmFailover() {
    if (!_isPendingConfirmation) return;
    _isPendingConfirmation = false;
    _activateFailover(_pendingUniverses);
    _pendingUniverses = [];
  }

  /// Called by the host app when the operator rejects failover.
  void cancelFailover() {
    _isPendingConfirmation = false;
    _pendingUniverses = [];
  }

  void _activateFailover(List<int> universes) {
    if (_isFailoverActive) return;
    _isFailoverActive = true;

    final newRoles = <int, UniverseRole>{};
    _overriddenUniverses.clear();

    for (final universe in universes) {
      newRoles[universe] = UniverseRole.showupOwned;
      _overriddenUniverses.add(universe);
    }

    if (_overriddenUniverses.isNotEmpty) {
      onUniverseRolesChanged?.call(newRoles);
      onFailoverActivated?.call(List.from(_overriddenUniverses));
    }
  }

  void _deactivateFailover() {
    if (!_isFailoverActive || _originalRoles == null) return;

    // Restore original roles
    final restoredRoles = <int, UniverseRole>{};
    for (final universe in _overriddenUniverses) {
      final original = _originalRoles![universe];
      if (original != null) {
        restoredRoles[universe] = original.role;
      }
    }

    final restored = List<int>.from(_overriddenUniverses);
    _overriddenUniverses.clear();
    _isFailoverActive = false;

    if (restored.isNotEmpty) {
      onUniverseRolesChanged?.call(restoredRoles);
      onFailoverDeactivated?.call(restored);
    }
  }

  /// Stop watching.
  void stop() {
    _healthSub?.cancel();
    if (_isFailoverActive) {
      _deactivateFailover();
    }
    _isPendingConfirmation = false;
    _pendingUniverses = [];
  }

  void dispose() => stop();
}
