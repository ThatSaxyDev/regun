import 'dart:math' as math;

/// A small ballistic heading error, shared by the sight, muzzle and release.
/// No random spread at release: what the sight shows is what the rifle fires.
class SniperSway {
  SniperSway({
    this.minimumDegrees = .18,
    this.maximumDegrees = .85,
    this.buildTime = 6,
    this.recoveryRate = 2,
  });
  final double minimumDegrees, maximumDegrees, buildTime, recoveryRate;
  double fatigue = 0, phase = 0;
  bool active = false;
  static const plateauSeconds = 6.0;
  double get amplitude =>
      (minimumDegrees +
          (maximumDegrees - minimumDegrees) *
              (fatigue / buildTime).clamp(0.0, 1.0)) *
      math.pi /
      180;
  double get angle => active
      ? amplitude *
            (.7 * math.sin(phase + .8) + .3 * math.sin(phase * 1.63 + 1.4))
      : 0;
  void advance(double dt, {required bool aiming}) {
    if (!dt.isFinite || dt <= 0) return;
    active = aiming;
    if (aiming) {
      fatigue = (fatigue + dt).clamp(0.0, buildTime);
      // Both frequencies remain continuous across the bounded phase period.
      phase = (phase + dt * 2.2) % (math.pi * 200);
    } else {
      fatigue = (fatigue - dt * recoveryRate).clamp(0.0, buildTime);
      if (fatigue == 0) phase = 0;
    }
  }

  void release() => active = false;
  void reset() {
    fatigue = phase = 0;
    active = false;
  }

  Map<String, dynamic> checkpoint() => {'fatigue': fatigue, 'phase': phase};
  static void validate(Map value, {double limit = plateauSeconds}) {
    for (final key in ['fatigue', 'phase']) {
      final n = value[key];
      if (n is! num ||
          !n.isFinite ||
          n < 0 ||
          n > (key == 'fatigue' ? limit : math.pi * 200)) {
        throw const FormatException('Invalid sniper fatigue');
      }
    }
  }

  void restore(Map value) {
    validate(value, limit: buildTime);
    fatigue = (value['fatigue'] as num).toDouble();
    phase = (value['phase'] as num).toDouble();
    active = false;
  }
}
