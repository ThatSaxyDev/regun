import 'package:regun/data/loadout.dart';

/// A run keeps its numerical revision. Saved payload damage is never multiplied
/// during Continue; revision 1 retains the former values and field geometry.
class WeaponPowerBalance {
  const WeaponPowerBalance._(this.revision);
  static const legacy = WeaponPowerBalance._(1);
  static const current = WeaponPowerBalance._(2);
  final int revision;
  static WeaponPowerBalance read(dynamic value) => switch (value) {
    null || 1 => legacy,
    2 => current,
    _ => throw const FormatException('Invalid weapon power balance'),
  };
  bool get upgraded => revision == 2;
  double damage(WeaponType weapon) => upgraded
      ? weapon.damage
      : switch (weapon) {
          WeaponType.shotgun => 1.2,
          WeaponType.carbine => 0.762,
          WeaponType.revolver => 3,
          WeaponType.arcCaster => 3,
          WeaponType.burstRifle => 1.05,
          WeaponType.railLance => 7,
          WeaponType.reaperDisc => 1.5,
          WeaponType.prismCutter => 0.48,
          WeaponType.twinVerdict => 2.5,
          WeaponType.flakRegent => 2.4,
          WeaponType.faultlineDriver => 6,
          WeaponType.sporeLobber => .5,
          WeaponType.scrapMortar => 4.5,
          WeaponType.anchorEngine => 8,
          WeaponType.cinderHose => .38,
          WeaponType.mourningBell => 4.5,
          _ => weapon.damage,
        };
  double get sporeDps => upgraded ? 2.4 : .8;
  double get sporeRadius => upgraded ? 150 : 100;
  double get sporeLifetime => upgraded ? 3 : 2.5;
  double get sporeTick => .25;
  int get sporeTargets => upgraded ? 12 : 8;
  int get sporeCapacity => 4;
  double get sporeStride => upgraded ? .75 : 1;
  double get eliteSporeStride => upgraded ? .85 : 1;
  double get mortarRadius => upgraded ? 185 : 145;
  double get rivetDamage => upgraded ? 2.5 : 1.75;
  double get rivetRadius => upgraded ? 155 : 125;
  double get anchorRadius => upgraded ? 190 : 165;
}
