import 'package:regun/models/economy/armory_catalog.dart';
import 'package:regun/data/loadout.dart';

class ChallengeDefinition {
  const ChallengeDefinition(this.id, this.title, this.requirement, this.reward);
  final String id, title, requirement, reward;
}

final challenges = [
  for (final c in CharacterType.values.where((c) => c.expansion))
    ChallengeDefinition(c.name, c.role, c.unlockHint, c.title),
  const ChallengeDefinition(
    'tenSurvivors',
    'Ten Against the Breach',
    'Complete a cycle with all ten survivors',
    'Roster mastery',
  ),
  const ChallengeDefinition(
    'eightFusions',
    'Complete Circuit',
    'Discover all eight fusions',
    'Fusion mastery',
  ),
  const ChallengeDefinition(
    'training',
    'First Steps',
    'Complete training',
    'Carbine',
  ),
  const ChallengeDefinition(
    'scrapper',
    'Clean Sweep',
    'Defeat 500 enemies',
    'Scrapper',
  ),
  const ChallengeDefinition(
    'warden',
    'Hold the Line',
    'Survive 8 minutes',
    'Warden',
  ),
  const ChallengeDefinition(
    'revolver',
    'Out of the Dark',
    'Defeat Shadow',
    'Revolver',
  ),
  const ChallengeDefinition(
    'arcCaster',
    'Cool the Furnace',
    'Defeat Demon',
    'Arc Caster',
  ),
  for (final weapon in WeaponType.values.where((w) => w.usesArsenalRuntime))
    ChallengeDefinition(
      weapon.name,
      weapon.title,
      'Defeat ${weapon.victoryRequirement} bosses across normal runs',
      armoryWeapons.containsKey(weapon.name)
          ? '${weapon.title} blueprint'
          : weapon.title,
    ),
  const ChallengeDefinition(
    'burstRifle',
    'Controlled Fire',
    'Defeat 3 bosses across normal runs',
    'Burst Rifle',
  ),
  const ChallengeDefinition(
    'foundry',
    'First Cycle',
    'Defeat Scorpion Queen',
    'The Foundry',
  ),
  const ChallengeDefinition(
    'recipes',
    'Fusion Made',
    'Create a fusion',
    'Recipe archive',
  ),
  const ChallengeDefinition(
    'queenTrophy',
    'Royal Pardon',
    'Defeat Scorpion Queen',
    'Queen emblem',
  ),
  const ChallengeDefinition(
    'veteran',
    'Still Standing',
    'Survive 15 minutes',
    'Veteran title',
  ),
  const ChallengeDefinition(
    'endless',
    'Beyond the Breach',
    'Survive 20 minutes',
    'Endless trail',
  ),
  const ChallengeDefinition(
    'scorpionCharm',
    'Pest Control',
    'Defeat 1,000 scorpions',
    'Scorpion charm',
  ),
  const ChallengeDefinition(
    'eliteHunter',
    'Elite Hunter',
    'Defeat 100 elites',
    'Hunter emblem',
  ),
  const ChallengeDefinition(
    'shadowPalette',
    'Untouched Shadow',
    'Defeat Shadow without being hit',
    'Shadow palette',
  ),
  const ChallengeDefinition(
    'emberPalette',
    'Untouched Flame',
    'Defeat Demon without being hit',
    'Ember palette',
  ),
  const ChallengeDefinition(
    'shotgunMaster',
    'Pump Action',
    'Complete a cycle with Shotgun',
    'Shotgun badge',
  ),
  const ChallengeDefinition(
    'carbineMaster',
    'Steady Hands',
    'Complete a cycle with Carbine',
    'Carbine badge',
  ),
  const ChallengeDefinition(
    'revolverMaster',
    'Six Chambers',
    'Complete a cycle with Revolver',
    'Revolver badge',
  ),
  const ChallengeDefinition(
    'arcMaster',
    'Live Wire',
    'Complete a cycle with Arc Caster',
    'Arc badge',
  ),
  const ChallengeDefinition(
    'engineer',
    'Full Circuit',
    'Discover all six fusions',
    'Engineer palette',
  ),
  const ChallengeDefinition(
    'survivor',
    'Everyone Out',
    'Complete a cycle with every character',
    'Survivor emblem',
  ),
];
