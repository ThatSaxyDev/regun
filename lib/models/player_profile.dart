import 'package:regun/data/loadout.dart';

class PlayerProfile {
  PlayerProfile(
      {this.scrap = 0,
      this.totalKills = 0,
      this.scorpionKills = 0,
      this.eliteKills = 0,
      this.bestSeconds = 0,
      this.bestScore = 0,
      this.assistedBestScore = 0,
      this.assistedBestSeconds = 0,
      Set<String>? challenges,
      Set<String>? discoveredEnemies,
      Set<String>? fusions,
      Set<String>? cycleWeapons,
      Set<String>? cycleCharacters,
      Set<String>? settledRuns,
      Set<String>? owned,
      this.cosmetic = 'standard'})
      : challenges = challenges ?? {},
        discoveredEnemies = discoveredEnemies ?? {},
        fusions = fusions ?? {},
        cycleWeapons = cycleWeapons ?? {},
        cycleCharacters = cycleCharacters ?? {},
        settledRuns = settledRuns ?? {},
        owned = owned ?? {'standard'};
  int scrap, totalKills, scorpionKills, eliteKills, bestSeconds, bestScore;
  int assistedBestScore, assistedBestSeconds;
  final Set<String> challenges,
      discoveredEnemies,
      fusions,
      cycleWeapons,
      cycleCharacters,
      settledRuns,
      owned;
  String cosmetic;
  bool get tutorialComplete => challenges.contains('training');
  bool weaponUnlocked(WeaponType weapon) => switch (weapon) {
        WeaponType.shotgun => true,
        WeaponType.carbine => challenges.contains('training'),
        WeaponType.revolver => challenges.contains('revolver'),
        WeaponType.arcCaster => challenges.contains('arcCaster'),
      };
  bool characterUnlocked(CharacterType character) =>
      character == CharacterType.rook || challenges.contains(character.name);
  bool arenaUnlocked(ArenaType arena) =>
      arena == ArenaType.breach || challenges.contains('foundry');

  Set<String> settle(
      {required String runId,
      required Loadout loadout,
      required int kills,
      required int score,
      required int seconds,
      required int earnedScrap,
      required int scorpions,
      required int elites,
      required Set<String> bosses,
      required Set<String> noHitBosses,
      required Set<String> foundFusions,
      required Set<String> enemies,
      bool assisted = false}) {
    if (loadout.training || settledRuns.contains(runId)) return {};
    settledRuns.add(runId);
    totalKills += kills;
    scorpionKills += scorpions;
    eliteKills += elites;
    scrap += earnedScrap;
    if (assisted) {
      if (score > assistedBestScore) assistedBestScore = score;
      if (seconds > assistedBestSeconds) assistedBestSeconds = seconds;
    } else {
      if (score > bestScore) bestScore = score;
      if (seconds > bestSeconds) bestSeconds = seconds;
    }
    fusions.addAll(foundFusions);
    discoveredEnemies.addAll(enemies);
    if (bosses.contains('queen')) {
      cycleWeapons.add(loadout.weapon.name);
      cycleCharacters.add(loadout.character.name);
    }
    final unlocked = <String>{
      if (totalKills >= 500) 'scrapper',
      if (bestSeconds >= 480) 'warden',
      if (bosses.contains('shadow')) 'revolver',
      if (bosses.contains('demon')) 'arcCaster',
      if (bosses.contains('queen')) ...['foundry', 'queenTrophy'],
      if (fusions.isNotEmpty) 'recipes',
      if (bestSeconds >= 900) 'veteran',
      if (bestSeconds >= 1200) 'endless',
      if (scorpionKills >= 1000) 'scorpionCharm',
      if (eliteKills >= 100) 'eliteHunter',
      if (noHitBosses.contains('shadow')) 'shadowPalette',
      if (noHitBosses.contains('demon')) 'emberPalette',
      if (cycleWeapons.contains('shotgun')) 'shotgunMaster',
      if (cycleWeapons.contains('carbine')) 'carbineMaster',
      if (cycleWeapons.contains('revolver')) 'revolverMaster',
      if (cycleWeapons.contains('arcCaster')) 'arcMaster',
      if (fusions.length >= 6) 'engineer',
      if (cycleCharacters.length >= 3) 'survivor',
    }.difference(challenges);
    challenges.addAll(unlocked);
    owned.addAll(unlocked.where((id) => cosmeticIds.contains(id)));
    return unlocked;
  }

  Map<String, dynamic> toJson() => {
        'schema': 1,
        'assistedBestScore': assistedBestScore,
        'assistedBestSeconds': assistedBestSeconds,
        'scrap': scrap,
        'totalKills': totalKills,
        'scorpionKills': scorpionKills,
        'eliteKills': eliteKills,
        'bestSeconds': bestSeconds,
        'bestScore': bestScore,
        'challenges': challenges.toList(),
        'enemies': discoveredEnemies.toList(),
        'fusions': fusions.toList(),
        'cycleWeapons': cycleWeapons.toList(),
        'cycleCharacters': cycleCharacters.toList(),
        'settledRuns': settledRuns.toList(),
        'owned': owned.toList(),
        'cosmetic': cosmetic
      };
  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    int number(String key) =>
        ((json[key] as num?)?.toInt() ?? 0).clamp(0, 1000000000);
    Set<String> strings(String key) =>
        (json[key] as List? ?? []).whereType<String>().toSet();
    return PlayerProfile(
        scrap: number('scrap'),
        totalKills: number('totalKills'),
        scorpionKills: number('scorpionKills'),
        eliteKills: number('eliteKills'),
        bestSeconds: number('bestSeconds'),
        bestScore: number('bestScore'),
        assistedBestScore: number('assistedBestScore'),
        assistedBestSeconds: number('assistedBestSeconds'),
        challenges: strings('challenges'),
        discoveredEnemies: strings('enemies'),
        fusions: strings('fusions'),
        cycleWeapons: strings('cycleWeapons'),
        cycleCharacters: strings('cycleCharacters'),
        settledRuns: strings('settledRuns'),
        owned: strings('owned')..add('standard'),
        cosmetic: json['cosmetic'] as String? ?? 'standard');
  }
}

const cosmeticIds = [
  'standard',
  'shadowPalette',
  'emberPalette',
  'engineer',
  'queenTrophy',
  'veteran',
  'endless',
  'scorpionCharm',
  'eliteHunter',
  'survivor'
];
const shopCosmetics = {'copper': 100, 'moss': 100, 'ivory': 150};
