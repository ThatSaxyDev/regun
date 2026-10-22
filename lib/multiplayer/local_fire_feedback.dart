/// Cosmetic first-trigger feedback only. No bullets, ammunition, hits or damage
/// are predicted. Suppress the matching authoritative cue to avoid double sound.
class LocalFireFeedback {
  bool _held = false;
  int? _shots, _pendingShot;
  double _pendingAt = 0;

  void reset() {
    _held = false;
    _shots = _pendingShot = null;
  }

  bool update({
    required double now,
    required bool held,
    required bool enabled,
    required int shots,
    required int ammo,
    required bool reloading,
    required double cooldown,
  }) {
    final previous = _shots;
    final rising = held && !_held;
    _held = held;
    _shots = shots;
    var cue = false;
    if (previous != null && shots > previous) {
      final suppress = _pendingShot != null && shots == _pendingShot;
      cue = !suppress;
      _pendingShot = null;
    }
    if (!enabled || reloading || ammo <= 0) {
      _pendingShot = null;
      return cue;
    }
    if (_pendingShot != null && now - _pendingAt > 1) _pendingShot = null;
    if (rising &&
        cooldown <= .001 &&
        _pendingShot == null &&
        !cue &&
        (previous == null || shots == previous)) {
      _pendingShot = shots + 1;
      _pendingAt = now;
      cue = true;
    }
    return cue;
  }
}
