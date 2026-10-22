import 'dart:math' as math;

/// Real crowd control, advanced only by active game time. A shared per-target
/// immunity window prevents pellets or different owners refreshing a freeze.
class FreezeState {
  double remaining = 0, recovery = 0, immunity = 0;
  bool get frozen => remaining > 1e-8;
  bool get held => frozen || recovery > 1e-8;
  bool apply() {
    if (held || immunity > 1e-8) return false;
    remaining = .6;
    return true;
  }

  void advance(double dt) {
    if (!dt.isFinite || dt < 0) throw ArgumentError.value(dt);
    var left = dt;
    if (frozen) {
      final step = math.min(left, remaining);
      remaining = math.max(0, remaining - step);
      left -= step;
      if (!frozen) {
        remaining = 0;
        recovery = .2;
        immunity = 1.2;
      }
    }
    recovery = math.max(0, recovery - left);
    immunity = math.max(0, immunity - left);
  }

  Map<String, double> toJson() => {
    'remaining': remaining,
    'recovery': recovery,
    'immunity': immunity,
  };
  void restore(Map<String, dynamic> map) {
    double read(String key, double cap) {
      final n = map[key];
      if (n is! num || !n.isFinite || n < 0 || n > cap + 1e-7) {
        throw const FormatException('Invalid freeze status');
      }
      return n.toDouble().clamp(0, cap);
    }

    remaining = read('remaining', .6);
    recovery = read('recovery', .2);
    immunity = read('immunity', 1.2);
    if (remaining > 0 && (recovery > 0 || immunity > 0)) {
      throw const FormatException('Overlapping freeze phases');
    }
  }
}
