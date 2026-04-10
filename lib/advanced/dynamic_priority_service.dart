import 'dart:async';

import '../transport/sacn_transport.dart';

/// Dynamically adjusts sACN priority per-universe based on what's happening.
///
/// In layered coexistence mode, this service ensures smooth handoffs:
///   - When ShowUp fires a console cue trigger, it lowers its own priority
///     so the console's response takes precedence.
///   - Between console cues, ShowUp raises its priority to fill with
///     reactive effects.
///   - Mood energy levels influence the base priority.
///
/// Priority is faded over [fadeDuration] to prevent visible flicker.
class DynamicPriorityService {
  final SacnTransport _transport;

  /// Duration to fade between priority levels.
  final Duration fadeDuration;

  /// Priority when a console cue is actively running (very low = console wins).
  final int consoleCueActivePriority;

  /// Priority when a ShowUp moment is actively running (medium-high = ShowUp leads).
  final int showupMomentActivePriority;

  /// Priority when idle (balanced).
  final int idlePriority;

  Timer? _fadeTimer;
  final Map<int, int> _currentPriorities = {};
  final Map<int, int> _targetPriorities = {};
  final Set<int> _managedUniverses = {};

  DynamicPriorityService({
    required SacnTransport transport,
    this.fadeDuration = const Duration(milliseconds: 500),
    this.consoleCueActivePriority = 20,
    this.showupMomentActivePriority = 80,
    this.idlePriority = 50,
  }) : _transport = transport;

  /// Register universes for dynamic priority management.
  void manageUniverses(List<int> universes) {
    _managedUniverses.addAll(universes);
    for (final u in universes) {
      _currentPriorities[u] = idlePriority;
      _targetPriorities[u] = idlePriority;
      _transport.setPriority(u, idlePriority);
    }
  }

  /// Called when a console cue trigger fires.
  /// Lowers ShowUp priority so the console's response takes precedence.
  void onConsoleCueFired() {
    _setTargetPriority(consoleCueActivePriority);
    _startFade();

    // After fade duration + a settle period, fade back to idle
    Future.delayed(fadeDuration + const Duration(seconds: 3), () {
      _setTargetPriority(idlePriority);
      _startFade();
    });
  }

  /// Called when a ShowUp moment is activated (user tap in Perform).
  /// Raises ShowUp priority to lead the look.
  void onShowUpMomentActivated() {
    _setTargetPriority(showupMomentActivePriority);
    _startFade();
  }

  /// Called when mood energy changes.
  /// High-energy moods raise priority, low-energy moods lower it.
  ///
  /// [energyLevel] — 0.0 (very calm) to 1.0 (very energetic).
  void onMoodEnergyChanged(double energyLevel) {
    // Map energy to priority range: 30 (low energy) to 80 (high energy)
    final priority = (30 + (energyLevel * 50)).round().clamp(0, 200);
    _setTargetPriority(priority);
    _startFade();
  }

  /// Manually set priority for all managed universes.
  void setManualPriority(int priority) {
    _setTargetPriority(priority);
    _startFade();
  }

  void _setTargetPriority(int priority) {
    for (final u in _managedUniverses) {
      _targetPriorities[u] = priority;
    }
  }

  void _startFade() {
    _fadeTimer?.cancel();

    // Fade in 10 steps over the fade duration
    const steps = 10;
    final stepDuration = fadeDuration ~/ steps;
    var step = 0;

    _fadeTimer = Timer.periodic(stepDuration, (timer) {
      step++;
      final t = step / steps; // 0.0 → 1.0

      for (final u in _managedUniverses) {
        final current = _currentPriorities[u] ?? idlePriority;
        final target = _targetPriorities[u] ?? idlePriority;
        final interpolated = (current + (target - current) * t).round();

        _currentPriorities[u] = interpolated;
        _transport.setPriority(u, interpolated);
      }

      if (step >= steps) {
        timer.cancel();
        // Snap to final values
        for (final u in _managedUniverses) {
          final target = _targetPriorities[u] ?? idlePriority;
          _currentPriorities[u] = target;
          _transport.setPriority(u, target);
        }
      }
    });
  }

  void dispose() {
    _fadeTimer?.cancel();
  }
}
