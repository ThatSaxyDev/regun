import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/systems/encounter_director.dart';

void main() {
  test('first bag favours fewer victories, shuffles ties, and still contains all eight', () {
    final wins = {for (final b in BossKind.active) b.name: b.index * 3};
    for (var seed = 0; seed < 100; seed++) {
      final d = EncounterDirector(bossWins: wins), r = Random(seed);
      final bag = List.generate(8, (_) => d.chooseBoss(r));
      expect(bag, BossKind.active);
      expect(d.chooseBoss(r), isNot(bag.last));
    }
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
      for (var i = 0; i < 7; i++) {
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
