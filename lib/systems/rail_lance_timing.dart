import 'dart:math' as math;

/// More aiming commitment, with the existing sustained cycle and damage intact.
class RailLanceTiming {
  static const chargeSeconds = .65;
  static double cycle(double cadence, double triggerScale) =>
      .45 + math.max(.35, (cadence - .45) * triggerScale);
  static double recovery(double cadence, double triggerScale) =>
      cycle(cadence, triggerScale) - chargeSeconds;
}
