import 'dart:math' as math;

/// Fixed Rail Lance charge reward and sustained cycle.
class RailLanceTiming {
  static const chargeSeconds = .65;
  static const fullChargeMultiplier = 1.25;
  static double cycle(double cadence, double triggerScale) =>
      .45 + math.max(.35, (cadence - .45) * triggerScale);
  static double recovery(double cadence, double triggerScale) =>
      cycle(cadence, triggerScale) - chargeSeconds;
}
