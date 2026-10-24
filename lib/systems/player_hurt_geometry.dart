/// Player damage footprint, independent of navigation/cover clearance.
abstract final class PlayerHurtGeometry {
  static const radius = 26.0;
  static const previousRadius = 30.0;

  /// Older attacks authored a total center-to-center contact distance.
  /// Preserve their weapon/body portion while changing the player portion.
  static double reach(double previousReach) =>
      previousReach - previousRadius + radius;
}
