import 'package:regun/data/loadout.dart';

/// Multiplies the survivor/upgrade baseline once; dash and saved stats are untouched.
class WeaponMobility {
  static const multipliers = <String, double>{
    'shotgun': 1,
    'carbine': 1,
    'revolver': 1,
    'arcCaster': .99,
    'burstRifle': 1,
    'railLance': .96,
    'rivetDriver': .98,
    'cinderHose': .96,
    'reaperDisc': .98,
    'scrapMortar': .95,
    'beltRepeater': .94,
    'frostShotgun': .99,
    'prismCutter': .97,
    'sporeLobber': .97,
    'longwatchSniper': .97,
    'twinVerdict': .99,
    'flakRegent': .94,
    'anchorEngine': .93,
    'faultlineDriver': .94,
    'cycloneBreacher': .94,
    'mourningBell': .95,
    'houndrack': .96,
    'stormOrb': .97,
    'ringCaster': .97,
  };
  static double of(WeaponType weapon) => multipliers[weapon.name] ?? 1;
  static double speed(WeaponType weapon, double baseline) =>
      baseline * of(weapon);
  static String label(WeaponType weapon) {
    final penalty = ((1 - of(weapon)) * 100).round();
    return penalty == 0 ? '' : 'Mobility −$penalty%';
  }
}
