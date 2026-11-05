import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/systems/encounter_director.dart';

void main() {
  test('Solo favours the least-beaten opener while every boss can open', () {
    final wins = {for (final b in BossKind.active) b.name: 4, 'lodestar': 0};
    final openings = <BossKind, int>{};
    final r = Random(42);
    for (var run = 0; run < 5000; run++) {
      final d = EncounterDirector(bossWins: wins);
      final bag = List.generate(BossKind.active.length, (_) => d.chooseBoss(r));
      openings.update(bag.first, (count) => count + 1, ifAbsent: () => 1);
      expect(bag, unorderedEquals(BossKind.active));
      expect(d.chooseBoss(r), isNot(bag.last));
    }
    expect(openings.keys, unorderedEquals(BossKind.active));
    final expectedShare = 3 / (2 * BossKind.active.length + 1);
    expect(openings[BossKind.lodestar]! / 5000, closeTo(expectedShare, .02));
  });
  test('tied histories keep the opening shuffle', () {
    final openings = {
      for (var seed = 0; seed < 200; seed++)
        EncounterDirector(bossWins: {}).chooseBoss(Random(seed)),
    };
    expect(openings, BossKind.active.toSet());
  });
  test(
    'a run pins its opening history and Continue preserves the remaining order',
    () {
      final source = {
        for (final b in BossKind.active) b.name: 10,
        'queen': 0,
        'marshal': 0,
      };
      final d = EncounterDirector(bossWins: source);
      source['shadow'] = 0;
      final before = EncounterDirector()..restore(d.toJson());
      expect(before.chooseBoss(Random(42)), d.chooseBoss(Random(42)));
      final saved = d.toJson(), copy = EncounterDirector()..restore(saved);
      for (var i = 1; i < BossKind.active.length; i++) {
        expect(copy.chooseBoss(Random(91)), d.chooseBoss(Random(7)));
      }
      final legacy = EncounterDirector()..restore(EncounterDirector().toJson());
      expect(legacy.toJson().containsKey('openingBossWins'), isFalse);
    },
  );
  test('wins count repeated bosses once per settled run, survive serialization, and exclude Training', () {
    final p = PlayerProfile();
    void settle(String id, {bool training = false}) => p.settle(
      runId: id,
      loadout: Loadout(training: training),
      kills: 30,
      score: 300,
      seconds: 300,
      earnedScrap: 10,
      scorpions: 0,
      elites: 0,
      bosses: {'shadow', 'queen'},
      bossVictories: 4,
      bossWinCounts: {'shadow': 3, 'queen': 1},
      noHitBosses: {},
      foundFusions: {},
      enemies: {},
    );
    settle('a');
    settle('a');
    settle('training', training: true);
    expect(p.bossWins, {'shadow': 3, 'queen': 1});
    expect(p.totalBossVictories, 4);
    final restored = PlayerProfile.fromJson(p.toJson());
    expect(restored.bossWins, p.bossWins);
    expect(
      PlayerProfile.fromJson({...p.toJson()}..remove('bossWins')).bossWins,
      isEmpty,
    );
    final malformed = PlayerProfile.fromJson({
      ...p.toJson(),
      'bossWins': {'fake': 999, 'queen': -1, 'shadow': 1.5},
    });
    expect(malformed.bossWins, isEmpty);
  });
}
