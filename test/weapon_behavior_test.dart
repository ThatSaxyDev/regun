import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/data/weapon_behavior.dart';
import 'package:regun/data/weapon_power_balance.dart';
import 'package:regun/models/live_balance.dart';
import 'package:regun/systems/burst_fire_clock.dart';
import 'package:regun/systems/freeze_state.dart';
import 'package:regun/systems/sniper_sway.dart';
import 'package:regun/systems/weapon_ballistics.dart';
import 'package:regun/systems/frontier_components.dart';

void main() {
  test('all declared behavior controls have matching catalogue bounds and immutable legacy defaults', () {
    final specs =
        jsonDecode(
              File('lib/data/weapon_behaviors.json').readAsStringSync(),
            )['fields']
            as List;
    expect(specs.length, 93);
    for (final spec in specs) {
      final w = WeaponType.values.byName(spec['weapon']);
      final id = 'effects.${w.name.toLowerCase()}.${spec['key']}';
      final field = LiveBalance.fields.singleWhere((f) => f['id'] == id);
      expect(field['value'], spec['value']);
      expect(field['minimum'], spec['minimum']);
      expect(field['maximum'], spec['maximum']);
      expect(
        WeaponPowerBalance.legacy.behavior(w, spec['key']),
        spec['legacyDefault'],
      );
      final changed = {
        ...LiveBalance.bundled.values,
        id: spec['minimum'] as num,
      };
      // Some minimums depend on another field; component sheets must still expose exact inputs.
      expect(
        frontierComponents(w.name, changed)[weaponBehaviorLabels[id]],
        spec['minimum'],
      );
    }
  });
  test('all retained catalogues retain hashes and legacy behavior without new keys', () {
    for (final document in LiveBalance.catalog['previousCatalogs']) {
      final values = LiveBalance.validate(<String, num>{
        for (final f in document['fields']) f['id']: f['value'],
      }, documentCatalogId: document['catalogId']);
      final hash = LiveBalance.digest(
        values,
        documentCatalogId: document['catalogId'],
      );
      final raw = {
        'schema': 1,
        'revision': 12,
        'catalogId': document['catalogId'],
        'hash': hash,
        'values': values,
      };
      final pinned = LiveBalance.fromJson(raw);
      expect(pinned.hash, hash);
      expect(pinned.toJson(), raw);
      final power = WeaponPowerBalance.live(pinned);
      expect(power.behavior(WeaponType.houndrack, 'launchRatio'), .3);
      expect(power.behavior(WeaponType.ringCaster, 'deliveryShare'), .65);
      expect(power.burstRecoveryCap, .6);
    }
  });
  test(
    'configured ballistics are pinned and relationships reject unsafe bands',
    () {
      final power = WeaponPowerBalance.live(
        LiveBalance.create(1, {
          ...LiveBalance.bundled.values,
          'effects.shotgun.closeDamage': 1.7,
          'effects.shotgun.farDamage': .5,
        }),
      );
      expect(
        WeaponBallistics.of(WeaponType.shotgun, power: power).multiplier(0),
        1.7,
      );
      expect(
        WeaponBallistics.of(WeaponType.shotgun, power: power).multiplier(1000),
        .5,
      );
      expect(WeaponBallistics.of(WeaponType.shotgun).multiplier(0), 1.2);
      expect(
        () => LiveBalance.create(2, {
          ...LiveBalance.bundled.values,
          'effects.shotgun.farDistance': 100,
        }),
        throwsFormatException,
      );
    },
  );
  test('variable bursts preserve exact spacing, cancellation, capacity and long recovery', () {
    final clock = BurstFireClock();
    final releases = <double>[];
    clock.advance(
      .61,
      rounds: 5,
      spacingSeconds: .15,
      maximumInterval: 5,
      held: true,
      interval: 2,
      ready: () => true,
      release: (t) {
        releases.add(t);
        return true;
      },
    );
    expect(releases.length, 5);
    for (var i = 0; i < 5; i++) {
      expect(releases[i], closeTo(i * .15, 1e-9));
    }
    expect(clock.recovery, closeTo(1.39, 1e-9));
    final restored = BurstFireClock()
      ..reset(recovery: clock.recovery, maximumRecovery: 5);
    expect(restored.pending, 0);
    expect(() => BurstFireClock().reset(recovery: 1.39), throwsFormatException);
    clock.advance(
      .1,
      rounds: 5,
      held: false,
      interval: 2,
      ready: () => true,
      release: (_) => throw StateError('released while cancelled'),
    );
    expect(clock.pending, 0);
  });
  test('tuned freeze and sniper state restore without resetting durations', () {
    final freeze = FreezeState()..apply(duration: 2);
    final restored = FreezeState()
      ..restore(
        freeze.toJson(),
        durationCap: 2,
        recoveryCap: .75,
        immunityCap: 4,
      );
    expect(restored.remaining, 2);
    expect(() => FreezeState().restore(freeze.toJson()), throwsFormatException);
    final sway = SniperSway(buildTime: 12, maximumDegrees: 2, recoveryRate: 1)
      ..advance(10, aiming: true);
    final continued = SniperSway(
      buildTime: 12,
      maximumDegrees: 2,
      recoveryRate: 1,
    )..restore(sway.checkpoint());
    expect(continued.fatigue, 10);
    continued.advance(1, aiming: false);
    expect(continued.fatigue, 9);
    expect(
      () => SniperSway().restore(sway.checkpoint()),
      throwsFormatException,
    );
  });
}
