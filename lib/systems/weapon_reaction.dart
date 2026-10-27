import 'package:regun/data/loadout.dart';

/// Gameplay force, independent of damage/proc flags, drawing and upgrade scaling.
/// Distances are world units before enemy mass; holds have a shared recovery gate.
class WeaponReaction {
  const WeaponReaction(
    this.distance,
    this.duration, {
    this.stagger = 0,
    this.slow = .8,
  });
  final double distance, duration, stagger, slow;
  WeaponReaction scaled(double scale, {bool hold = false}) => WeaponReaction(
    distance * scale,
    duration,
    stagger: hold ? stagger : 0,
    slow: slow,
  );
  static WeaponReaction of(WeaponType type) => switch (type) {
    WeaponType.shotgun => const WeaponReaction(58, .18, stagger: .09),
    WeaponType.carbine => const WeaponReaction(6, .07, slow: .4),
    WeaponType.revolver => const WeaponReaction(36, .16, stagger: .055),
    WeaponType.arcCaster => const WeaponReaction(24, .14, stagger: .045),
    WeaponType.burstRifle => const WeaponReaction(10, .09, slow: .5),
    WeaponType.railLance => const WeaponReaction(76, .22, stagger: .13),
    WeaponType.rivetDriver => const WeaponReaction(14, .11, stagger: .025),
    WeaponType.cinderHose => const WeaponReaction(4, .07, slow: .35),
    WeaponType.reaperDisc => const WeaponReaction(34, .16, stagger: .045),
    WeaponType.scrapMortar => const WeaponReaction(90, .25, stagger: .15),
    WeaponType.beltRepeater => const WeaponReaction(12, .09, slow: .5),
    WeaponType.frostShotgun => const WeaponReaction(32, .17, stagger: .06),
    WeaponType.prismCutter => const WeaponReaction(4, .07, slow: .35),
    WeaponType.sporeLobber => const WeaponReaction(12, .11, slow: .55),
    WeaponType.longwatchSniper => const WeaponReaction(68, .21, stagger: .11),
    WeaponType.twinVerdict => const WeaponReaction(30, .15, stagger: .06),
    WeaponType.flakRegent => const WeaponReaction(48, .19, stagger: .085),
    WeaponType.anchorEngine => const WeaponReaction(96, .26, stagger: .16),
    WeaponType.faultlineDriver => const WeaponReaction(82, .25, stagger: .15),
    WeaponType.cycloneBreacher => const WeaponReaction(64, .21, stagger: .10),
    WeaponType.houndrack => const WeaponReaction(
      28,
      .14,
      stagger: .04,
      slow: .5,
    ),
    WeaponType.stormOrb => const WeaponReaction(30, .16, stagger: .04),
    WeaponType.ringCaster => const WeaponReaction(42, .18, stagger: .06),
    WeaponType.mourningBell => const WeaponReaction(
      112,
      .29,
      stagger: .20,
      slow: .95,
    ),
  };
  static const grenade = WeaponReaction(140, .32, stagger: .18);
  static const mine = WeaponReaction(66, .22, stagger: .10);
  static const rivetBlast = WeaponReaction(54, .20, stagger: .08);
  static const bellEcho = WeaponReaction(34, .16, slow: .7);
  static const flakFragment = WeaponReaction(10, .09, slow: .45);
  static const arcJump = WeaponReaction(10, .10, slow: .45);
  static const shrapnel = WeaponReaction(7, .08, slow: .4);
  static const verdictFork = WeaponReaction(26, .15, slow: .65);
}
