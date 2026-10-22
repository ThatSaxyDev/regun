import 'package:regun/data/loadout.dart';

/// Damage depends on distance travelled from the muzzle, not current player
/// position. Fixed world-space bands keep range upgrades from extending the
/// close-range bonus. Each hit samples the curve once, including after bounces.
class WeaponBallistics {
  const WeaponBallistics(
    this.closeDistance,
    this.farDistance,
    this.closeMultiplier,
    this.farMultiplier,
  );

  final double closeDistance, farDistance, closeMultiplier, farMultiplier;

  static WeaponBallistics of(WeaponType weapon) => switch (weapon) {
    WeaponType.shotgun => const WeaponBallistics(120, 380, 1.20, .90),
    WeaponType.carbine => const WeaponBallistics(100, 600, 1.10, .95),
    WeaponType.revolver => const WeaponBallistics(110, 750, 1.12, .98),
    WeaponType.burstRifle => const WeaponBallistics(100, 700, 1, 1),
    WeaponType.arcCaster => const WeaponBallistics(100, 520, 1.08, .98),
    _ => const WeaponBallistics(100, 600, 1, 1),
  };

  double multiplier(double distance) {
    final t = ((distance - closeDistance) / (farDistance - closeDistance))
        .clamp(0.0, 1.0);
    final smooth = t * t * (3 - 2 * t);
    return closeMultiplier + (farMultiplier - closeMultiplier) * smooth;
  }
}
