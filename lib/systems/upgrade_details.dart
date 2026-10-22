import 'dart:math' as math;

import 'package:regun/data/loadout.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/systems/grenades.dart';

/// Concrete offer deltas. Counts deliberately use purchased rather than scalar rank.
String upgradeDetails(
  PowerUp p,
  GameState s,
  WeaponType weapon, {
  int balance = 2,
  CharacterType character = CharacterType.rook,
}) {
  final r = s.rank(p), next = math.min(p.maxRank, r + 1);
  double e(int n) => GameState.scaledRank(
    n,
    lateGain: p == PowerUp.fastReload || p == PowerUp.quickstep ? .2 : .3,
  );
  String f(num n) => n == n.roundToDouble()
      ? n.toInt().toString()
      : n.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  String delta(String label, num Function(int) value, {String unit = ''}) =>
      '$label ${f(value(r))}$unit to ${f(value(next))}$unit';
  String pct(String label, double Function(int) value) =>
      delta(label, (n) => value(n) * 100, unit: '%');
  switch (p) {
    case PowerUp.heavyLoad:
      return delta(
        'Primary',
        (n) => 1 + math.min(3, n) * .35 + math.max(0, n - 3) * .10,
        unit: 'x',
      );
    case PowerUp.quickTrigger:
      return delta(
        'Firing interval',
        (n) => weapon.cadence * math.pow(.85, e(n)),
        unit: 's',
      );
    case PowerUp.maxBulletsIncrease:
      final extra = weapon == WeaponType.carbine
          ? (next <= 3 ? 6 : 2)
          : (next <= 3 ? 2 : 1);
      return 'Magazine ${s.maxBullets} to ${weapon == WeaponType.prismCutter ? math.min(24, s.maxBullets + extra) : s.maxBullets + extra}. Refill now.';
    case PowerUp.fastReload:
      double full(int rank) {
        final value = weapon == WeaponType.shotgun
            ? (rank == 0
                      ? 3200
                      : math.max(
                          850,
                          2500 -
                              math.min(3, rank) * 500 -
                              math.max(0, rank - 3) * 30,
                        ))
                  .toDouble()
            : weapon.reloadMs * math.pow(.8, e(rank));
        return (character == CharacterType.flint
                ? math.max(weapon == WeaponType.shotgun ? 850 : 0, value * .88)
                : value) /
            1000;
      }
      return delta('Full reload', full, unit: 's');
    case PowerUp.numberOfBulletsPerShotIncrease:
      int count(int n) =>
          weapon == WeaponType.shotgun || weapon == WeaponType.frostShotgun
          ? 3 + math.min(3, n) * 2
          : weapon == WeaponType.cycloneBreacher
          ? 5 + math.min(2, n) * 2
          : weapon == WeaponType.railLance || weapon == WeaponType.beltRepeater
          ? math.min(3, 1 + n)
          : 1 + math.min(3, n);
      return count(next) == count(r)
          ? 'Tighter projectile spread. Count stays ${count(r)}.'
          : delta('Projectiles', count);
    case PowerUp.bulletsPhaseThrough:
      return delta('Extra penetrations', (n) => n);
    case PowerUp.bulletRangeIncrease:
      return 'Range ${math.min(weapon.rangeCeiling ?? 100000, s.bulletRange)} to ${math.min(weapon.rangeCeiling ?? 100000, s.bulletRange + (next <= 3 ? 60 : 24))}';
    case PowerUp.rapidFire:
      return 'Speed ${f(s.bulletSpeed)} to ${f(math.min(weapon.velocityCeiling, math.min(s.baseProjectileSpeed + 800, s.bulletSpeed + (next <= 3 ? 200 : 40))))}';
    case PowerUp.walkingSpeedIncrease:
      return 'Walking ${f(s.movementSpeed)} to ${f(s.movementSpeed + (next <= 3 ? 50 : 12))}';
    case PowerUp.healthIncrease:
      return 'Max HP ${s.maxHealth} to ${s.maxHealth + 1}. Recover one.';
    case PowerUp.fieldMedic:
      return '${pct('Heal chance', (n) => e(n) * .05)} per kill.${balance >= 2 ? ' ${character == CharacterType.suture ? 12 : 6}s cooldown.' : ''}';
    case PowerUp.scrapArmour:
      return '${delta('Guard recharge', (n) => 20 - 3 * e(n), unit: 's')}. Guard now.';
    case PowerUp.quickstep:
      return delta(
        'Dash cooldown',
        (n) => (1.6 - .25 * e(n)).clamp(.6, 1.6),
        unit: 's',
      );
    case PowerUp.sprintInvincibility:
      return delta(
        'Recovery protection',
        (n) => n == 0 ? 0 : 70 + (n - 1) * 15,
        unit: 'ms',
      );
    case PowerUp.scavenger:
      return delta(
        'XP attraction',
        (n) => 180 + 60 * e(n) + (character == CharacterType.scrapper ? 80 : 0),
      );
    case PowerUp.luckyFind:
      return delta('Special offer weight', (n) => 1 + .35 * e(n), unit: 'x');
    case PowerUp.hotShot:
      return '${delta('Burn / tick', (n) => n == 0 ? 0 : .25 + .20 * e(n))}. 3s burn.';
    case PowerUp.accelerant:
      return '${delta('Spread radius', (n) => balance >= 2 ? 130 + 35 * e(n) : 100 + 30 * e(n))}. One spread generation.';
    case PowerUp.staticCharge:
      return pct('Chain chance', (n) => .12 * e(n));
    case PowerUp.conductiveCore:
      return '${delta('Extra jumps', (n) => n)}. +55 jump range.';
    case PowerUp.sprintMine:
      return '${delta('Mine damage', (n) => (3.5 + e(n)) * (character == CharacterType.scrapper ? 1.4 : 1))}. One after each dash.';
    case PowerUp.fragmentation:
      return delta('Blast shards', (n) => n == 0 ? 0 : 4 + 2 * n);
    case PowerUp.ricochet:
      return delta('Extra bounces', (n) => n);
    case PowerUp.bankShot:
      return delta(
        'Bounce damage',
        (n) => balance >= 2 && n > 0
            ? math.min(1.4, 1 + .08 * e(n))
            : math.min(1.4, .7 + .15 * e(n)),
        unit: 'x',
      );
    case PowerUp.lastShell:
      return delta(
        'Final release',
        (n) => 1 + (s.fused('breachEngine') ? .9 : .6) * e(n),
        unit: 'x',
      );
    case PowerUp.breachLoader:
      return delta(
        'After reload',
        (n) => 1 + (s.fused('breachEngine') ? .8 : .5) * e(n),
        unit: 'x',
      );
    case PowerUp.orbitDrone:
      return '${delta('Drone shot', (n) => (balance >= 2 ? .8 : .6) + .35 * e(n))}. ${f(math.max(.3, 1 - .15 * e(next)))}s interval.';
    case PowerUp.targetingLink:
      return delta('Marked drone damage', (n) => 1 + .3 * e(n), unit: 'x');
    case PowerUp.shrapnel:
      return '${pct('Kill proc', (n) => .18 * e(n))}. ${3 + next} shards.';
    case PowerUp.executioner:
      return '${delta('Wounded primary', (n) => 1 + .3 * e(n), unit: 'x')}. Below 35% HP.';
    case PowerUp.grenadeDamage:
      return delta(
        'Grenade damage',
        (n) =>
            GrenadeSpec.damage(e(n)) +
            (character == CharacterType.fuse ? 1.6 : 0),
      );
    case PowerUp.grenadeRadius:
      return delta('Grenade radius', (n) => GrenadeSpec.radius(e(n)));
    case PowerUp.grenadeRecharge:
      return delta(
        'Charge recharge',
        (n) =>
            (GrenadeSpec.recharge(e(n)) -
                    (character == CharacterType.fuse ? 2 : 0))
                .clamp(10, 18),
        unit: 's',
      );
    case PowerUp.braceLoader:
      return pct('Reload walking bonus', (n) => .04 * e(n));
    case PowerUp.sureFoot:
      return pct('Weight penalty recovered', (n) => math.min(.40, .08 * e(n)));
    case PowerUp.scouringHeat:
      return pct('Elite/boss burn bonus', (n) => .10 * e(n));
    case PowerUp.faradayReserve:
      return '${pct('Extra chain retention', (n) => .02 * e(n))}. 92% retention cap.';
    case PowerUp.blastHarness:
      return pct('Grenade/mine push bonus', (n) => .10 * e(n));
    case PowerUp.exposedSeam:
      return pct('Frozen primary bonus', (n) => .06 * e(n));
    case PowerUp.measuredShot:
      return '${pct('Prepared release bonus', (n) => .08 * e(n))}. Wait 0.8s; shared bonus cap 60%.';
    case PowerUp.closeQuarters:
      return '${pct('Close primary bonus', (n) => .06 * e(n))}. Inside 160 range; shared bonus cap 60%.';
    case PowerUp.sprintDistanceIncrease:
      return 'Dash duration +15ms.';
    case PowerUp.salvage:
      return 'Gain 5 scrap and recover one HP.';
  }
}
