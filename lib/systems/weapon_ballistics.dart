import 'package:regun/data/loadout.dart';
import 'package:regun/data/weapon_power_balance.dart';

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

  static WeaponBallistics of(WeaponType weapon, {WeaponPowerBalance? power}) {
    if (power != null &&
        {
          WeaponType.shotgun,
          WeaponType.carbine,
          WeaponType.revolver,
          WeaponType.arcCaster,
          WeaponType.cycloneBreacher,
        }.contains(weapon)) {
      return WeaponBallistics(
        power.behavior(weapon, 'closeDistance'),
        power.behavior(weapon, 'farDistance'),
        power.behavior(weapon, 'closeDamage'),
        power.behavior(weapon, 'farDamage'),
      );
    }
    return switch (weapon) {
      WeaponType.shotgun => const WeaponBallistics(120, 380, 1.20, .90),
      WeaponType.carbine => const WeaponBallistics(100, 600, 1.10, .95),
      WeaponType.revolver => const WeaponBallistics(110, 750, 1.12, .98),
      WeaponType.houndrack => const WeaponBallistics(0, 900, 1, 1),
      WeaponType.burstRifle => const WeaponBallistics(100, 700, 1, 1),
      WeaponType.arcCaster => const WeaponBallistics(100, 520, 1.08, .98),
      WeaponType.cycloneBreacher => const WeaponBallistics(210, 300, 1, .60),
      _ => const WeaponBallistics(100, 600, 1, 1),
    };
  }

  double multiplier(double distance) {
    final t = ((distance - closeDistance) / (farDistance - closeDistance))
        .clamp(0.0, 1.0);
    final smooth = t * t * (3 - 2 * t);
    return closeMultiplier + (farMultiplier - closeMultiplier) * smooth;
  }
}
