import 'dart:math' as math;

/// A burst is three actual round releases, never three simultaneous pellets.
/// Callbacks receive their offset inside this update so flight/recoil can start
/// at the release time even when a frame crosses more than one subshot.
class BurstFireClock {
  static const spacing = .10;
  double _untilBurst = 0, _untilShot = 0;
  int _pending = 0;
  double get recovery => _untilBurst;
  int get pending => _pending;

  void cancelIntent() {
    _pending = 0;
    _untilShot = 0;
  }

  void reset({double recovery = 0}) {
    if (!recovery.isFinite || recovery < 0 || recovery > .6) {
      throw const FormatException('Invalid burst recovery');
    }
    cancelIntent();
    _untilBurst = recovery;
  }

  void _elapse(double dt) {
    _untilBurst = math.max(0, _untilBurst - dt);
    _untilShot = math.max(0, _untilShot - dt);
  }

  void advance(
    double dt, {
    required bool held,
    required double interval,
    required bool Function() ready,
    required bool Function(double offset) release,
  }) {
    if (!dt.isFinite || dt < 0) throw ArgumentError.value(dt, 'dt');
    if (!interval.isFinite) throw ArgumentError.value(interval, 'interval');
    if (!held || !ready()) {
      cancelIntent();
      _elapse(dt);
      return;
    }
    final period = interval.clamp(.30, .60);
    var offset = 0.0;
    // Bounded work after pathological stalls; no unbounded offline catch-up.
    for (var events = 0; events < 32; events++) {
      final wait = _pending > 0 ? _untilShot : _untilBurst;
      if (wait > dt - offset + 1e-9) {
        _elapse(dt - offset);
        return;
      }
      _elapse(wait);
      offset += wait;
      if (!ready()) {
        cancelIntent();
        _elapse(math.max(0, dt - offset));
        return;
      }
      if (!release(offset)) {
        // Saturation defers this round; it doesn't consume it or its sound.
        if (_pending > 0) {
          _untilShot = .05;
        } else {
          _untilBurst = .05;
        }
        _elapse(math.max(0, dt - offset));
        return;
      }
      if (_pending == 0) {
        _pending = 2;
        _untilBurst = period;
      } else {
        _pending--;
      }
      _untilShot = spacing;
    }
    cancelIntent();
    _untilBurst = math.max(_untilBurst, .05);
  }
}
