import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/models/player_profile.dart';

void main() {
  test('normal results unlock content and award currency exactly once', () {
    final profile = PlayerProfile();
    Set<String> settle() => profile.settle(
        runId: 'run1',
        loadout: const Loadout(),
        kills: 550,
        score: 12000,
        seconds: 650,
        earnedScrap: 100,
        scorpions: 400,
        elites: 20,
        bosses: {'shadow', 'demon', 'queen'},
        noHitBosses: {'shadow'},
        foundFusions: {'firebreak'},
        enemies: {'scorpion', 'mummy'});
    final unlocked = settle();
    expect(
        unlocked,
        containsAll([
          'scrapper',
          'warden',
          'revolver',
          'arcCaster',
          'foundry',
          'recipes',
          'shotgunMaster',
          'shadowPalette'
        ]));
    expect(profile.scrap, 100);
    expect(settle(), isEmpty);
    expect(profile.scrap, 100);
    final reloaded = PlayerProfile.fromJson(profile.toJson());
    expect(reloaded.settledRuns, contains('run1'));
    expect(reloaded.weaponUnlocked(WeaponType.arcCaster), isTrue);
    expect(reloaded.owned, contains('shadowPalette'));
  });

  test('training never awards progression or currency', () {
    final profile = PlayerProfile();
    profile.settle(
        runId: 'practice',
        loadout: const Loadout(training: true),
        kills: 999,
        score: 999,
        seconds: 999,
        earnedScrap: 999,
        scorpions: 999,
        elites: 999,
        bosses: {'queen'},
        noHitBosses: {},
        foundFusions: {},
        enemies: {});
    expect(profile.scrap, 0);
    expect(profile.challenges, isEmpty);
    expect(profile.bestScore, 0);
  });
}
