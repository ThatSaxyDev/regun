import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/presentation/weapon_feel.dart';
import 'package:regun/systems/weapon_ballistics.dart';
import 'package:regun/systems/xp_progression.dart';
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/multiplayer/identity_key.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/multiplayer_combat.json').readAsStringSync(),
  ) as Map;
  test('Flutter and authoritative TypeScript share the current weapon, survivor, XP and boss contracts', () {
    for (final w in WeaponType.values) {
      final s = fixture['weapons'][w.name] as Map, b = WeaponBallistics.of(w);
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
      expect([
        b.closeDistance,
        b.farDistance,
        b.closeMultiplier,
        b.farMultiplier,
      ], s['bands']);
    }
    for (final c in CharacterType.values) {
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
