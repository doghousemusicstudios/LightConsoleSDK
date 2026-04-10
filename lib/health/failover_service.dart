import 'dart:async';

import '../models/coexistence_config.dart';
import '../models/universe_role.dart';
import 'console_health_monitor.dart';

/// Automatically takes over console-owned universes when the console
/// goes offline, and hands them back when the console returns.
///
/// This ensures the show doesn't stop if the console crashes or
/// loses network connectivity.
class FailoverService {
  final ConsoleHealthMonitor _healthMonitor;
  final FailoverConfig _config;

  /// Callback: invoked when failover activates.
  /// [overriddenUniverses] — universes that ShowUp is now controlling.
  void Function(List<int> overriddenUniverses)? onFailoverActivated;

  /// Callback: invoked when failover deactivates (console is back).
  /// [restoredUniverses] — universes returned to console control.
  void Function(List<int> restoredUniverses)? onFailoverDeactivated;

  /// Callback: request to change universe roles.
  /// The host app should update its CoexistenceConfig and DmxEngine.
  void Function(Map<int, UniverseRole> newRoles)? onUniverseRolesChanged;

  StreamSubscription<ConsoleHealthEvent>? _healthSub;
  bool _isFailoverActive = false;
  final List<int> _overriddenUniverses = [];

  /// The original universe roles before failover.
  Map<int, UniverseConfig>? _originalRoles;

  FailoverService({
    required ConsoleHealthMonitor healthMonitor,
    FailoverConfig? config,
  })  : _healthMonitor = healthMonitor,
        _config = config ?? const FailoverConfig();

  /// Whether failover is currently active.
  bool get isFailoverActive => _isFailoverActive;

  /// Universes currently overridden by failover.
  List<int> get overriddenUniverses =>
      List.unmodifiable(_overriddenUniverses);

  /// Start watching for console offline events.
  ///
  /// [universeRoles] — the current universe role assignments.
  void start(Map<int, UniverseConfig> universeRoles) {
    if (!_config.enabled) return;
    _originalRoles = Map.from(universeRoles);

    _healthSub = _healthMonitor.events.listen((event) {
      switch (event.type) {
        case ConsoleHealthEventType.offline:
          _activateFailover();
        case ConsoleHealthEventType.reconnected:
        case ConsoleHealthEventType.online:
          if (_isFailoverActive) {
            _deactivateFailover();
          }
      }
    });
  }

  void _activateFailover() {
    if (_isFailoverActive || _originalRoles == null) return;
    _isFailoverActive = true;

    // Find console-owned universes and take them over
    final newRoles = <int, UniverseRole>{};
    _overriddenUniverses.clear();

    for (final entry in _originalRoles!.entries) {
      if (entry.value.role == UniverseRole.consoleOwned) {
        newRoles[entry.key] = UniverseRole.showupOwned;
        _overriddenUniverses.add(entry.key);
      }
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
  }

  void dispose() => stop();
}
