import 'rail_lance_timing.dart';

import 'dart:math' as m;

import 'rank_curve.dart';

/// Effective per-family components. Full weapon DPS is deliberately not implied.
class RankEffects {
  static Map<String, num> values(
    String id,
    int n,
    Map<String, num> v, {
    String weapon = 'shotgun',
    String survivor = 'rook',
    Set<String> fusions = const {},
    double railChargeMultiplier = RailLanceTiming.fullChargeMultiplier,
  }) {
    final strength = (v['powerups.$id.strength'] ?? 1).toDouble();
    double total(double early, double late) =>
        RankCurve.total(n, id, early, late, v) * strength;
    final e = total(1, {'fastReload', 'quickstep'}.contains(id) ? .2 : .3);
    final count = (n * strength).round().clamp(0, 8);
    double base(String key, double fallback) =>
        (v['weapons.$weapon.$key'] ?? fallback).toDouble();
    final mag = base('capacity', 5),
        cadence = base('cadence', .35),
        reload = base('reloadMs', 3200);
    switch (id) {
      case 'heavyLoad':
        final multiplier = 1 + total(.35, .1);
        return {
          'Damage multiplier': multiplier,
          if (weapon == 'railLance') ...{
            'Quick shot damage': base('damage', 11.25) * multiplier,
            'Full charge damage':
                base('damage', 11.25) * multiplier * railChargeMultiplier,
          },
        };
      case 'quickTrigger':
        var interval = cadence * m.pow(.85, e);
        if (weapon == 'railLance') {
          interval = RailLanceTiming.cycle(cadence, m.pow(.85, e).toDouble());
        }
        if (weapon == 'beltRepeater') {
          interval = m.max(.030, cadence * m.pow(.85, e));
        }
        if (weapon == 'prismCutter') interval = cadence;
        if (weapon == 'cinderHose') interval = m.max(.075, interval);
        if (!{
          'shotgun',
          'carbine',
          'revolver',
          'arcCaster',
          'railLance',
          'beltRepeater',
          'cinderHose',
          'prismCutter',
        }.contains(weapon)) {
          interval = m.max(
            {
                  'frostShotgun': .45,
                  'reaperDisc': .35,
                  'scrapMortar': .4,
                  'longwatchSniper': .65,
                  'anchorEngine': .4,
                  'faultlineDriver': .4,
                  'sporeLobber': .40,
                }[weapon] ??
                .14,
            interval,
          );
        }
        return {
          'Release interval (s)': interval,
          if (weapon == 'railLance') ...{
            'Aim charge (s)': RailLanceTiming.chargeSeconds,
            'Recovery (s)': interval - RailLanceTiming.chargeSeconds,
          },
          if (weapon == 'beltRepeater')
            'Fully spun interval (s)': m.max(
              .030,
              cadence * (.040 / .085) * m.pow(.85, e),
            ),
        };
      case 'maxBulletsIncrease':
        return {
          'Magazine': m.min(
            weapon == 'prismCutter'
                ? 24
                : weapon == 'beltRepeater'
                ? 128
                : 100,
            mag +
                total(
                  weapon == 'carbine' ? 6 : 2,
                  weapon == 'carbine' ? 2 : 1,
                ).round(),
          ),
        };
      case 'fastReload':
        var time = weapon == 'shotgun'
            ? (n == 0
                  ? reload
                  : m.min(reload, m.max(850, 2500 - total(500, 30).round())))
            : reload * m.pow(.8, e);
        if (survivor == 'flint') {
          time = m.max(
            weapon == 'shotgun' ? m.min(850, reload) : 0,
            time * .88,
          );
        }
        return {'Full reload (s)': time / 1000};
      case 'numberOfBulletsPerShotIncrease':
        final cap =
            {'railLance', 'beltRepeater', 'cycloneBreacher'}.contains(weapon)
            ? 2
            : 3;
        final pellets = {'shotgun', 'frostShotgun'}.contains(weapon)
            ? 3 + 2 * m.min(3, count)
            : weapon == 'cycloneBreacher'
            ? 5 + 2 * m.min(2, count)
            : 1 + m.min(cap, count);
        return {
          'Projectiles': pellets,
          'Spread multiplier': 1 - m.max(0, n - cap) * .04,
        };
      case 'bulletsPhaseThrough':
        return {'Extra penetrations': count};
      case 'bulletRangeIncrease':
        final ceiling =
            {
              'cinderHose': 320,
              'reaperDisc': 650,
              'scrapMortar': 760,
              'frostShotgun': 480,
              'prismCutter': 560,
              'sporeLobber': 600,
              'anchorEngine': 760,
            }[weapon] ??
            100000;
        return {
          'Range': m.min(ceiling, base('range', 420) + total(60, 24).round()),
        };
      case 'rapidFire':
        return {
          'Projectile speed': m.min(
            weapon == 'reaperDisc'
                ? 1200
                : weapon == 'sporeLobber'
                ? 1000
                : 2000,
            base('speed', 700) + m.min(800, total(200, 40).round()),
          ),
        };
      case 'walkingSpeedIncrease':
        return {
          'Walking speed':
              (v['survivors.$survivor.speed'] ?? 300) + total(50, 12),
        };
      case 'healthIncrease':
        return {
          'Maximum HP':
              (v['survivors.$survivor.health'] ?? 6) + n * strength.round(),
        };
      case 'fieldMedic':
        return {'Heal chance (%)': m.min(.225, e * .05) * 100};
      case 'scrapArmour':
        return {'Guard recharge (s)': m.max(6.5, 20 - 3 * e)};
      case 'quickstep':
        return {'Dash recharge (s)': (1.6 - .25 * e).clamp(.6, 1.6)};
      case 'dashCapacity':
        return {
          'Dash charges':
              1 + m.min(n, (v['powerups.dashCapacity.capacity'] ?? 3) - 1),
        };
      case 'grenadeCapacity':
        return {
          'Grenade capacity':
              2 + m.min(n, (v['powerups.grenadeCapacity.capacity'] ?? 4) - 2),
        };
      case 'sprintInvincibility':
        return {
          'Extra protection (ms)': n == 0 ? 0 : (70 + (n - 1) * 15) * strength,
        };
      case 'scavenger':
        return {
          'XP attraction': 180 + 60 * e + (survivor == 'scrapper' ? 80 : 0),
        };
      case 'luckyFind':
        return {'Special offer weight': 1 + .35 * e};
      case 'hotShot':
        return {'Burn per tick': n == 0 ? 0 : .25 + .2 * e};
      case 'accelerant':
        return {'Spread radius': 130 + 35 * e};
      case 'staticCharge':
        return {
          'Chain chance (%)': weapon == 'arcCaster'
              ? 100
              : m.min(1, .12 * e) * 100,
        };
      case 'conductiveCore':
        return {'Extra jumps': count, 'Jump range': count * 55};
      case 'sprintMine':
        return {'Mine damage': (3.5 + e) * (survivor == 'scrapper' ? 1.4 : 1)};
      case 'fragmentation':
        return {'Blast shards': n == 0 ? 0 : 4 + 2 * count};
      case 'ricochet':
        return {'Extra bounces': count};
      case 'bankShot':
        return {'Bounce multiplier': n == 0 ? .7 : m.min(1.4, 1 + .08 * e)};
      case 'lastShell':
        return {
          'Final release multiplier':
              1 + (fusions.contains('breachEngine') ? .9 : .6) * e,
        };
      case 'breachLoader':
        return {
          'First release multiplier':
              1 + (fusions.contains('breachEngine') ? .8 : .5) * e,
        };
      case 'orbitDrone':
        return {
          'Drone damage': .8 + .35 * e,
          'Drone interval (s)': m.max(.3, 1 - .15 * e),
        };
      case 'targetingLink':
        return {'Marked drone multiplier': 1 + .3 * e};
      case 'shrapnel':
        return {'Kill proc (%)': m.min(1, .18 * e) * 100, 'Shards': 3 + count};
      case 'executioner':
        return {'Wounded damage multiplier': 1 + .3 * e};
      case 'grenadeDamage':
        return {
          'Grenade damage': 8 * (1 + .2 * e) + (survivor == 'fuse' ? 1.6 : 0),
        };
      case 'grenadeRadius':
        return {'Blast radius': 205 * (1 + .08 * e)};
      case 'grenadeRecharge':
        return {
          'Charge recharge (s)': (18 - 1.5 * e - (survivor == 'fuse' ? 2 : 0))
              .clamp(10, 18),
        };
      case 'braceLoader':
        return {'Reload walking bonus (%)': 4 * e};
      case 'sureFoot':
        return {'Weight penalty recovered (%)': m.min(.4, .08 * e) * 100};
      case 'scouringHeat':
        return {'Elite/boss burn bonus (%)': 10 * e};
      case 'faradayReserve':
        return {
          'Chain retention (%)':
              m.min(.92, (weapon == 'arcCaster' ? .85 : .65) + .02 * e) * 100,
          if (survivor == 'coil')
            'Secondary retention (%)': m.min(.92, .50 + .02 * e) * 100,
        };
      case 'blastHarness':
        return {'Ordinary push bonus (%)': 10 * e};
      case 'exposedSeam':
        return {'Frozen primary bonus (%)': 6 * e};
      case 'measuredShot':
        return {'Prepared release bonus (%)': m.min(.6, .08 * e) * 100};
      case 'closeQuarters':
        return {'Close primary bonus (%)': m.min(.6, .06 * e) * 100};
      case 'salvage':
        return {'Scrap': 5, 'HP recovered': 1};
      default:
        return {};
    }
  }

  static bool improves(Map<String, num> a, Map<String, num> b) =>
      b.keys.any((k) => ((b[k] ?? 0) - (a[k] ?? 0)).abs() > 1e-8);
}
