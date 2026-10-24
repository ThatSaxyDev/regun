import 'package:regun/models/economy/armory_catalog.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/models/player_profile.dart';

class CareerGoal {
  const CareerGoal(this.id, this.title, this.detail, this.progress);
  final String id, title, detail;
  final double progress;
}

/// Projects earned milestones and permanent weapon saving goals.
class CareerProgress {
  CareerProgress(this.profile, {ArmoryCatalog? armory})
    : armory = armory ?? ArmoryCatalog.bundled;
  final ArmoryCatalog armory;
  final PlayerProfile profile;
  List<CareerGoal> get goals => [
    if (!profile.tutorialComplete)
      const CareerGoal(
        'training',
        'Carbine',
        'Complete or skip the Training introduction.',
        0,
      ),
    for (final weapon in WeaponType.values)
      if (!profile.weaponUnlocked(weapon))
        CareerGoal(
          weapon.name,
          weapon.title,
          armoryWeapons.containsKey(weapon.name)
              ? '${profile.totalBossVictories} / ${weapon.victoryRequirement} bosses · ${profile.scrap} / ${armory.prices[weapon.name]!} Scrap'
              : weapon.victoryRequirement > 0
              ? '${profile.totalBossVictories} / ${weapon.victoryRequirement} boss victories'
              : weapon == WeaponType.revolver
              ? 'Defeat Shadow'
              : 'Defeat Demon',
          armoryWeapons.containsKey(weapon.name)
              ? ((profile.totalBossVictories / weapon.victoryRequirement).clamp(
                          0,
                          1,
                        ) +
                        (profile.scrap / armory.prices[weapon.name]!).clamp(
                          0,
                          1,
                        )) /
                    2
              : weapon.victoryRequirement > 0
              ? (profile.totalBossVictories / weapon.victoryRequirement).clamp(
                  0,
                  1,
                )
              : 0,
        ),
    for (final survivor in CharacterType.values)
      if (!profile.characterUnlocked(survivor))
        CareerGoal(
          survivor.name,
          survivor.title,
          profile.characterProgress(survivor),
          _survivorProgress(survivor),
        ),
  ];
  double _survivorProgress(CharacterType c) {
    int count(String id) => profile.survivorCounters[id] ?? 0;
    final value = switch (c) {
      CharacterType.scrapper => profile.totalKills / 500,
      CharacterType.warden => profile.bestSeconds / 480,
      CharacterType.flint => count('reloads') / 40,
      CharacterType.fuse => count('grenadeKills') / 120,
      CharacterType.moth => count('burningKills') / 150,
      CharacterType.coil => count('chainVictims') / 200,
      CharacterType.suture => count('healed') / 40,
      CharacterType.harrow =>
        ((profile.eliteKills / 15).clamp(0, 1) +
                (profile.totalBossVictories / 3).clamp(0, 1)) /
            2,
      _ => 0.0,
    };
    return value.clamp(0, 1);
  }

  CareerGoal? get next {
    final remaining = goals;
    if (remaining.isEmpty) return null;
    for (final goal in remaining) {
      if (goal.id == profile.pinnedGoal) return goal;
    }
    // Prefer the most advanced goal while keeping equal goals in authored order.
    var result = remaining.first;
    for (final goal in remaining.skip(1)) {
      if (goal.progress > result.progress) result = goal;
    }
    return result;
  }
}
