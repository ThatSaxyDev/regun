import 'dart:math' as math;

/// A small ballistic heading error, shared by the sight, muzzle and release.
/// No random spread at release: what the sight shows is what the rifle fires.
class SniperSway {
  double fatigue = 0, phase = 0;
  bool active = false;
  static const plateauSeconds = 6.0;
  double get amplitude =>
      (.18 + .67 * (fatigue / plateauSeconds).clamp(0.0, 1.0)) * math.pi / 180;
  double get angle => active
      ? amplitude *
            (.7 * math.sin(phase + .8) + .3 * math.sin(phase * 1.63 + 1.4))
      : 0;
  void advance(double dt, {required bool aiming}) {
    if (!dt.isFinite || dt <= 0) return;
    active = aiming;
    if (aiming) {
      fatigue = (fatigue + dt).clamp(0.0, plateauSeconds);
      // Both frequencies remain continuous across the bounded phase period.
      phase = (phase + dt * 2.2) % (math.pi * 200);
    } else {
      fatigue = (fatigue - dt * 2).clamp(0.0, plateauSeconds);
      if (fatigue == 0) phase = 0;
    }
  }

  void release() => active = false;
  void reset() {
    fatigue = phase = 0;
    active = false;
  }

  Map<String, dynamic> checkpoint() => {'fatigue': fatigue, 'phase': phase};
  static void validate(Map value) {
    for (final key in ['fatigue', 'phase']) {
      final n = value[key];
      if (n is! num ||
          !n.isFinite ||
          n < 0 ||
          n > (key == 'fatigue' ? plateauSeconds : math.pi * 200)) {
        throw const FormatException('Invalid sniper fatigue');
      }
    }
  }

  void restore(Map value) {
    validate(value);
    fatigue = (value['fatigue'] as num).toDouble();
    phase = (value['phase'] as num).toDouble();
    active = false;
  }
}
