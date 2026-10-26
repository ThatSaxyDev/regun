import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/data/weapon_power_balance.dart';
import 'package:regun/models/live_balance.dart';
import 'package:regun/notifiers/game_notifier.dart';

void main() {
  test('audit every offered family in every native kit at rank milestones', () async {
    final power = WeaponPowerBalance.live(LiveBalance.bundled);
    final rows = <Map<String, Object?>>[];
    final ids = PowerUp.values
        .where(
          (p) => p != PowerUp.salvage && p != PowerUp.sprintDistanceIncrease,
        )
        .toList();
    expect(ids.length, 43);
    for (final p in ids) {
      var supported = 0, empty = 0, capped = 0;
      final contexts = <Map<String, Object?>>[];
      for (final weapon in WeaponType.values) {
        for (final survivor in CharacterType.values) {
          final state = GameState(
            upgradeStrengths: power.upgradeStrengths,
            rankCurves: power.rankCurves,
          );
          final eligible = weaponSupportsPowerUp(weapon, p);
          if (eligible) {
            supported++;
          } else {
            empty++;
          }
          final transitions = <Map<String, Object?>>[];
          for (final rank in [0, 1, 3, 7]) {
            if (rank >= state.rankLimit(p)) continue;
            final before = state.rankValues(p, rank, weapon, survivor, power);
            final after = state.rankValues(
              p,
              rank + 1,
              weapon,
              survivor,
              power,
            );
            expect(
              [...before.values, ...after.values].every((v) => v.isFinite),
              isTrue,
            );
            final changed = <String, Object?>{
              for (final key in {...before.keys, ...after.keys})
                if ((before[key] ?? 0) != (after[key] ?? 0))
                  key: [before[key], after[key]],
            };
            if (eligible && changed.isEmpty) capped++;
            transitions.add({'from': rank, 'to': rank + 1, 'changed': changed});
          }
          contexts.add({
            'weapon': weapon.name,
            'survivor': survivor.name,
            'weaponCompatible': eligible,
            'transitions': transitions,
          });
        }
      }
      rows.add({
        'id': p.name,
        'compatibleKits': supported,
        'incompatibleKits': empty,
        'unchangedCompatibleSteps': capped,
        'contexts': contexts,
      });
    }
    final report = {
      'schema': 1,
      'balance': LiveBalance.bundled.toJson(),
      'scope': 'Bundled pinned components; not full DPS, live production values, observed proc frequency or player acceptance.',
      'families': rows,
    };
    final directory = Directory('build/upgrade-feel-audit');
    await directory.create(recursive: true);
    await File('${directory.path}/resolved-components.json')
        .writeAsString(jsonEncode(report));
    final summary = rows
        .map(
          (r) => {
            for (final key in [
              'id',
              'compatibleKits',
              'incompatibleKits',
              'unchangedCompatibleSteps',
            ])
              key: r[key],
          },
        )
        .toList();
    await Directory('docs/validation/upgrade-feel-2026-10-25')
        .create(recursive: true);
    await File(
      'docs/validation/upgrade-feel-2026-10-25/component-summary.json',
    ).writeAsString('${const JsonEncoder.withIndent('  ').convert(summary)}\n');
    // Both finite capacity transitions are included even though ordinary scalar
    // milestones stop at VII -> VIII.
    for (final p in [PowerUp.dashCapacity, PowerUp.grenadeCapacity]) {
      expect(rows.firstWhere((r) => r['id'] == p.name)['compatibleKits'], 240);
    }
  });
}
