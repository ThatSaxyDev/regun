import 'package:regun/systems/weapon_reaction.dart';
import 'package:regun/systems/weapon_mobility.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/presentation/weapon_feel.dart';
import 'package:regun/presentation/weapon_art_spec.dart';
import 'package:regun/systems/burst_fire_clock.dart';
import 'package:regun/systems/weapon_ballistics.dart';
import 'package:regun/systems/xp_progression.dart';
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/multiplayer/identity_key.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/multiplayer_combat.json').readAsStringSync(),
  ) as Map;
  test('Flutter and authoritative TypeScript share the current weapon, survivor, XP and boss contracts', () {
    for (final w in WeaponType.values.where((w) => !w.usesArsenalRuntime)) {
      final s = fixture['weapons'][w.name] as Map, b = WeaponBallistics.of(w);
      final reaction = WeaponReaction.of(w);
      expect([
        reaction.distance,
        reaction.duration,
        reaction.stagger,
        reaction.slow,
      ], fixture['weaponReactions'][w.name]);
      expect(
        [w.capacity, w.cadence, w.damage, w.range, w.speed, w.reloadMs / 1000],
        [
          s['capacity'],
          s['cadence'],
          s['damage'],
          s['range'],
          s['speed'],
          s['reload'],
        ],
      );
      expect(WeaponFeel.of(w).muzzle + 8, closeTo(s['muzzle'] as num, 1e-6));
      if (w == WeaponType.burstRifle) {
        final art = WeaponArtSpec.of(w);
        expect(
          art.muzzleSocket.dy - art.gripSocket.dy,
          closeTo(s['muzzleSide'] as num, 1e-6),
        );
        expect(s['burst'], [3, BurstFireClock.spacing, .3]);
      }
      expect([
        b.closeDistance,
        b.farDistance,
        b.closeMultiplier,
        b.farMultiplier,
      ], s['bands']);
    }
    expect([
      ShotgunReload.firstShellMs / 1000,
      ShotgunReload.shellIntervalMs / 1000,
    ], fixture['shotgunReload']);
    for (final c in CharacterType.values.where((c) => c.availableOnline)) {
      expect([c.health, c.speed, c.damage], fixture['survivors'][c.name]);
    }
    for (final b in BossKind.values) {
      expect([
        b.baseHealth,
        b.spriteSize,
        b.bodyRadius,
      ], fixture['bosses'][b.name]);
    }
    expect([
      for (var level = 1; level <= 8; level++) XPProgression.cost(level),
    ], fixture['xp']);
  });
  test('weapon walking multipliers match the authoritative fixture for all 21 guns', () {
    expect(WeaponMobility.multipliers, fixture['weaponMobility']);
    expect(
      WeaponMobility.multipliers.keys.toSet(),
      WeaponType.values.map((w) => w.name).toSet(),
    );
    for (final c in CharacterType.values.where((c) => c.availableOnline)) {
      for (final w in WeaponType.values) {
        expect(
          WeaponMobility.speed(w, c.speed),
          closeTo(c.speed * WeaponMobility.of(w), 1e-8),
        );
        expect(WeaponMobility.of(w), inInclusiveRange(.93, 1));
      }
    }
  });
  test('identity foreign keys normalize once; enemy owners are preserved and upgraded capacity is bounded', () {
    final canonical = 'c200${'01' * 30}';
    expect(
      identityKeyFromCanonical(identityKeyFromCanonical(canonical)),
      canonical,
    );
    expect(
      OnlineRound('1', {'owner': canonical}).owner,
      identityKeyFromCanonical(canonical),
    );
    expect(OnlineRound('2', {'owner': 'e:9:12'}).owner, 'e:9:12');
    expect(
      OnlineGun('a', {
        'weapon': 'carbine',
        'ranks': {'maxBulletsIncrease': 8},
      }).capacity,
      52,
    );
    expect(
      OnlineGun('a', {
        'weapon': 'shotgun',
        'ranks': {'maxBulletsIncrease': 8},
      }).capacity,
      16,
    );
  });
}
