import 'package:regun/models/live_balance.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/systems/rail_lance_timing.dart';
import 'package:regun/systems/weapon_reaction.dart';

/// A run keeps its numerical revision. Saved payload damage is never multiplied
/// during Continue; revisions 1/2 retain their former values and field geometry.
class WeaponPowerBalance {
  const WeaponPowerBalance._(this.revision, [this.snapshot]);
  final LiveBalance? snapshot;
  factory WeaponPowerBalance.live(LiveBalance snapshot) =>
      WeaponPowerBalance._(3, snapshot);
  static const legacy = WeaponPowerBalance._(1);
  static const current = WeaponPowerBalance._(3);
  final int revision;
  static WeaponPowerBalance read(dynamic value, [dynamic rawSnapshot]) =>
      rawSnapshot != null
      ? (value == 2 || value == 3
            ? WeaponPowerBalance._(
                value == 2 ? 2 : 3,
                LiveBalance.fromJson(rawSnapshot),
              )
            : throw const FormatException('Invalid live balance'))
      : switch (value) {
          null || 1 => legacy,
          2 => const WeaponPowerBalance._(2),
          3 => current,
          _ => throw const FormatException('Invalid weapon power balance'),
        };
  Map<String, num> get upgradeStrengths => Map.unmodifiable({
    for (final e in snapshot?.values.entries ?? <MapEntry<String, num>>[])
      if (e.key.startsWith('powerups.')) e.key.split('.')[1]: e.value,
  });
  Map<String, num> get rankCurves => Map.unmodifiable({
    for (final e in snapshot?.values.entries ?? <MapEntry<String, num>>[])
      if (e.key.startsWith('ranks.')) e.key: e.value,
  });
  bool get upgraded => revision >= 2;
  double get railChargeMultiplier =>
      revision >= 3 ? RailLanceTiming.fullChargeMultiplier : 1;
  double get railBulletRadius => revision >= 3 ? 7 : 5;
  WeaponReaction get railReaction => revision >= 3
      ? const WeaponReaction(90, .24, stagger: .23)
      : WeaponReaction.of(WeaponType.railLance);
  double damage(WeaponType weapon) => upgraded
      ? n(
          'weapons.${weapon.name}.damage',
          weapon == WeaponType.railLance && revision == 2 ? 9 : weapon.damage,
        )
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
  double get sporeDps => upgraded ? n('effects.sporelobber.sporeDps', 2.4) : .8;
  double get sporeRadius =>
      upgraded ? n('effects.sporelobber.sporeRadius', 150) : 100;
  double get sporeLifetime =>
      upgraded ? n('effects.sporelobber.sporeLifetime', 3) : 2.5;
  double get sporeTick => n('effects.sporelobber.sporeTick', .25);
  int get sporeTargets =>
      upgraded ? n('effects.sporelobber.sporeTargets', 12).toInt() : 8;
  int get sporeCapacity => n('effects.sporelobber.sporeCapacity', 4).toInt();
  double get sporeStride =>
      upgraded ? n('effects.sporelobber.sporeStride', .75) : 1;
  double get eliteSporeStride =>
      upgraded ? n('effects.sporelobber.eliteSporeStride', .85) : 1;
  double get mortarRadius =>
      upgraded ? n('effects.scrapmortar.mortarRadius', 185) : 145;
  double get rivetDamage =>
      upgraded ? n('effects.rivetdriver.rivetDamage', 2.5) : 1.75;
  double get rivetRadius =>
      upgraded ? n('effects.rivetdriver.rivetRadius', 155) : 125;
  double get anchorRadius =>
      upgraded ? n('effects.anchorengine.anchorRadius', 190) : 165;
  // The entire profile is pinned in the run's LiveBalance snapshot.
  int get revolverRicochets => n('weapons.revolver.ricochets', 1).toInt();
  int ricochets(WeaponType weapon) =>
      weapon == WeaponType.revolver ? revolverRicochets : 0;
  double get rocketTurnRate => n('effects.houndrack.rocketTurnRate', 4.5);
  double get rocketAcquireAngle =>
      n('effects.houndrack.rocketAcquireAngle', 45);
  double get rocketAcceleration =>
      n('effects.houndrack.rocketAcceleration', .25);
  double get rocketSplashDamage =>
      n('effects.houndrack.rocketSplashDamage', .8);
  double get rocketSplashRadius =>
      n('effects.houndrack.rocketSplashRadius', 65);
  int get rocketLimit => n('effects.houndrack.rocketLimit', 12).toInt();
  double get orbArcDamage => n('effects.stormorb.orbArcDamage', 1.2);
  double get orbArcRadius => n('effects.stormorb.orbArcRadius', 130);
  double get orbTick => n('effects.stormorb.orbTick', .2);
  int get orbTargets => n('effects.stormorb.orbTargets', 3).toInt();
  int get orbLimit => n('effects.stormorb.orbLimit', 3).toInt();
  double get orbWindup => n('effects.stormorb.orbWindup', .18);
  double get ringRadius => n('effects.ringcaster.ringRadius', 160);
  double get ringStart => n('effects.ringcaster.ringStart', 28);
  double get orbLifetime => n('effects.stormorb.orbLifetime', 2.4);
  double get ringExpand => n('effects.ringcaster.ringExpand', .7);
  double get ringRetract => n('effects.ringcaster.ringRetract', .55);
  double get ringHold => n('effects.ringcaster.ringHold', .2);
  double get ringReturnScale => n('effects.ringcaster.ringReturnScale', 1.5);
  int get ringTargets => n('effects.ringcaster.ringTargets', 8).toInt();
  double get ringThickness => n('effects.ringcaster.ringThickness', 28);
  double n(String key, num fallback) =>
      snapshot?.number(key, fallback) ?? fallback.toDouble();
  int capacity(WeaponType w) =>
      n('weapons.${w.name}.capacity', w.capacity).toInt();
  double cadence(WeaponType w) => n('weapons.${w.name}.cadence', w.cadence);
  int reloadMs(WeaponType w) =>
      n('weapons.${w.name}.reloadMs', w.reloadMs).toInt();
  int range(WeaponType w) => n('weapons.${w.name}.range', w.range).toInt();
  double speed(WeaponType w) => n('weapons.${w.name}.speed', w.speed);
  int health(CharacterType c) =>
      n('survivors.${c.name}.health', c.health).toInt();
  double movement(CharacterType c) => n('survivors.${c.name}.speed', c.speed);
  double survivorDamage(CharacterType c) =>
      n('survivors.${c.name}.damage', c.damage);
  double shellScale() => reloadMs(WeaponType.shotgun) / 3200;
  double shellInterval() => ShotgunReload.shellIntervalMs * shellScale();
  int shellDuration(int missing) =>
      (ShotgunReload.durationFor(missing) * shellScale()).round();
}
