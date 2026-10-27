import 'package:regun/models/player_usage.dart';
import 'package:regun/models/boss_history.dart';
import 'package:regun/models/economy/armory_catalog.dart';
import 'package:regun/data/loadout.dart';

class PlayerProfile {
  PlayerUsage publicUsage = PlayerUsage();

  /// Atomic settlement journal: totals and pending summary share one save.
  /// Owner and epoch are captured at run start, never from a later sign-in.
  final Map<String, Map<String, dynamic>> runRecords = {};
  bool recordQueueFull = false;

  PlayerProfile({
    this.scrap = 0,
    Set<String>? ownedWeapons,
    Set<String>? legacyWeaponClaims,
    this.earnedScrapTotal = 0,
    this.careerSeconds = 0,
    Map<String, Map<String, int>>? unlockMilestones,
    this.totalKills = 0,
    this.totalBossVictories = 0,
    Map<String, int>? bossWins,
    this.scorpionKills = 0,
    this.eliteKills = 0,
    this.bestSeconds = 0,
    this.bestScore = 0,
    this.continuedBestScore = 0,
    this.continuedBestSeconds = 0,
    this.assistedBestScore = 0,
    this.assistedBestSeconds = 0,
    Map<String, int>? survivorCounters,
    Set<String>? challenges,
    Set<String>? discoveredEnemies,
    Set<String>? fusions,
    Set<String>? cycleWeapons,
    Set<String>? cycleCharacters,
    Set<String>? settledRuns,
    Set<String>? owned,
    this.cosmetic = 'standard',
    this.pinnedGoal,
    this.preferredWeapon = WeaponType.shotgun,
    this.preferredCharacter = CharacterType.rook,
    this.preferredArena = ArenaType.breach,
  }) : ownedWeapons = ownedWeapons ?? {},
       legacyWeaponClaims = legacyWeaponClaims ?? {},
       unlockMilestones = unlockMilestones ?? {},
       survivorCounters = survivorCounters ?? {},
       bossWins = BossHistory.read(bossWins),
       challenges = challenges ?? {},
       discoveredEnemies = discoveredEnemies ?? {},
       fusions = fusions ?? {},
       cycleWeapons = cycleWeapons ?? {},
       cycleCharacters = cycleCharacters ?? {},
       settledRuns = settledRuns ?? {},
       owned = owned ?? {'standard'};
  final Set<String> ownedWeapons, legacyWeaponClaims;
  final Map<String, int> survivorCounters;
  int earnedScrapTotal, careerSeconds;
  final Map<String, Map<String, int>> unlockMilestones;
  final Map<String, int> bossWins;
  int totalBossVictories;
  int scrap, totalKills, scorpionKills, eliteKills, bestSeconds, bestScore;
  int assistedBestScore, assistedBestSeconds;
  int continuedBestScore, continuedBestSeconds;
  final Set<String> challenges,
      discoveredEnemies,
      fusions,
      cycleWeapons,
      cycleCharacters,
      settledRuns,
      owned;
  String cosmetic;
  String? pinnedGoal;
  WeaponType preferredWeapon;
  CharacterType preferredCharacter;
  ArenaType preferredArena;
  bool get tutorialComplete => challenges.contains('training');
  bool weaponUnlocked(WeaponType weapon) =>
      armoryWeapons.containsKey(weapon.name)
      ? ownedWeapons.contains(weapon.name)
      : legacyWeaponUnlocked(weapon);
  bool legacyWeaponUnlocked(WeaponType weapon) => switch (weapon) {
    WeaponType.shotgun => true,
    WeaponType.carbine => challenges.contains('training'),
    WeaponType.revolver => challenges.contains('revolver'),
    WeaponType.burstRifle => challenges.contains('burstRifle'),
    WeaponType.arcCaster => challenges.contains('arcCaster'),
    _ =>
      challenges.contains(weapon.name) ||
          (weapon == WeaponType.longwatchSniper &&
              challenges.contains('breachHammer')) ||
          totalBossVictories >= weapon.victoryRequirement,
  };
  bool characterUnlocked(CharacterType character) =>
      character == CharacterType.rook || challenges.contains(character.name);
  bool arenaUnlocked(ArenaType arena) =>
      arena == ArenaType.breach || challenges.contains('foundry');

  String characterProgress(CharacterType c) {
    final count = switch (c) {
      CharacterType.scrapper => '$totalKills / 500 kills',
      CharacterType.warden => '$bestSeconds / 480s best',
      CharacterType.flint => '${survivorCounters['reloads'] ?? 0} / 40 reloads',
      CharacterType.fuse =>
        '${survivorCounters['grenadeKills'] ?? 0} / 120 grenade kills',
      CharacterType.moth =>
        '${survivorCounters['burningKills'] ?? 0} / 150 burning enemies',
      CharacterType.coil =>
        '${survivorCounters['chainVictims'] ?? 0} / 200 chain victims',
      CharacterType.suture =>
        '${survivorCounters['healed'] ?? 0} / 40 HP restored',
      CharacterType.harrow =>
        '$eliteKills / 15 elites · $totalBossVictories / 3 bosses',
      _ => c.unlockHint,
    };
    return count;
  }

  Set<String> settle({
    required String runId,
    required Loadout loadout,
    required int kills,
    required int score,
    required int seconds,
    required int earnedScrap,
    required int scorpions,
    required int elites,
    required Set<String> bosses,
    int? bossVictories,
    Map<String, int>? bossWinCounts,
    required Set<String> noHitBosses,
    required Set<String> foundFusions,
    required Set<String> enemies,
    bool assisted = false,
    bool continued = false,
    Map<String, dynamic> survivorProgress = const {},
    int dashes = 0,
    Map<String, dynamic>? trackedRun,
  }) {
    if (loadout.training || settledRuns.contains(runId)) return {};
    settledRuns.add(runId);
    if (trackedRun != null) publicUsage.record(trackedRun);
    for (final key in [
      'reloads',
      'grenadeKills',
      'burningKills',
      'chainVictims',
      'healed',
    ]) {
      final value = survivorProgress[key];
      if (value is int && value >= 0) {
        survivorCounters[key] = ((survivorCounters[key] ?? 0) + value).clamp(
          0,
          1000000000,
        );
      }
    }
    careerSeconds = (careerSeconds + seconds.clamp(0, 1000000000)).clamp(
      0,
      1000000000,
    );
    totalKills += kills;
    totalBossVictories += (bossVictories ?? bosses.length).clamp(0, 1000000);
    final observed = BossHistory.read(
      bossWinCounts ?? {for (final id in bosses) id: 1},
    );
    for (final e in observed.entries) {
      bossWins[e.key] = ((bossWins[e.key] ?? 0) + e.value).clamp(0, 1000000000);
    }
    scorpionKills += scorpions;
    eliteKills += elites;
    scrap += earnedScrap;
    earnedScrapTotal = (earnedScrapTotal + earnedScrap).clamp(0, 1000000000);
    if (continued) {
      if (score > continuedBestScore) continuedBestScore = score;
      if (seconds > continuedBestSeconds) continuedBestSeconds = seconds;
    } else if (assisted) {
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
      for (final weapon in WeaponType.values)
        if (weapon.victoryRequirement > 0 &&
            totalBossVictories >= weapon.victoryRequirement)
          weapon.name,
      if (seconds >= 360 && dashes >= 30) 'vesper',
      if ((survivorCounters['reloads'] ?? 0) >= 40) 'flint',
      if ((survivorCounters['grenadeKills'] ?? 0) >= 120) 'fuse',
      if ((survivorCounters['burningKills'] ?? 0) >= 150) 'moth',
      if ((survivorCounters['chainVictims'] ?? 0) >= 200) 'coil',
      if ((survivorCounters['healed'] ?? 0) >= 40) 'suture',
      if (eliteKills >= 15 && totalBossVictories >= 3) 'harrow',
      if (totalKills >= 500) 'scrapper',
      if ((continued ? seconds : bestSeconds) >= 480) 'warden',
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
      if ([
        'firebreak',
        'stormCircuit',
        'minefield',
        'pinball',
        'breachEngine',
        'hunterSwarm',
      ].every(fusions.contains))
        'engineer',
      if (['rook', 'scrapper', 'warden'].every(cycleCharacters.contains))
        'survivor',
      if (CharacterType.values.every((c) => cycleCharacters.contains(c.name)))
        'tenSurvivors',
      if (fusions.length >= 8) 'eightFusions',
    }.difference(challenges);
    for (final id in unlocked) {
      unlockMilestones.putIfAbsent(
        id,
        () => {'runs': settledRuns.length, 'seconds': careerSeconds},
      );
    }
    challenges.addAll(unlocked);
    owned.addAll(unlocked.where((id) => cosmeticIds.contains(id)));
    return unlocked;
  }

  Map<String, dynamic> toJson() => {
    'schema': 3,
    'runRecords': runRecords,
    'publicUsage': publicUsage.toJson(),
    'recordQueueFull': recordQueueFull,
    'weaponAccessVersion': 2,
    'ownedWeapons': ownedWeapons.toList(),
    'legacyWeaponClaims': legacyWeaponClaims.toList(),
    'careerSeconds': careerSeconds,
    'unlockMilestones': unlockMilestones,
    'survivorCounters': survivorCounters,
    'totalBossVictories': totalBossVictories,
    'bossWins': bossWins,
    'continuedBestScore': continuedBestScore,
    'continuedBestSeconds': continuedBestSeconds,
    'assistedBestScore': assistedBestScore,
    'assistedBestSeconds': assistedBestSeconds,
    'scrap': scrap,
    'earnedScrapTotal': earnedScrapTotal,
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
    'cosmetic': cosmetic,
    'pinnedGoal': pinnedGoal,
    'preferredWeapon': preferredWeapon.name,
    'preferredCharacter': preferredCharacter.name,
    'preferredArena': preferredArena.name,
  };
  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    int number(String key) =>
        ((json[key] as num?)?.toInt() ?? 0).clamp(0, 1000000000);
    Set<String> strings(String key) =>
        (json[key] as List? ?? []).whereType<String>().toSet();
    final profile = PlayerProfile(
      preferredWeapon:
          WeaponType.values
              .where((v) => v.name == json['preferredWeapon'])
              .firstOrNull ??
          WeaponType.shotgun,
      preferredCharacter:
          CharacterType.values
              .where((v) => v.name == json['preferredCharacter'])
              .firstOrNull ??
          CharacterType.rook,
      preferredArena:
          ArenaType.values
              .where((v) => v.name == json['preferredArena'])
              .firstOrNull ??
          ArenaType.breach,
      survivorCounters: {
        for (final e in (json['survivorCounters'] as Map? ?? {}).entries)
          if (e.key is String && e.value is int && e.value >= 0)
            e.key as String: (e.value as int).clamp(0, 1000000000),
      },
      scrap: number('scrap'),
      earnedScrapTotal: number('earnedScrapTotal'),
      careerSeconds: number('careerSeconds'),
      unlockMilestones: {
        for (final e in (json['unlockMilestones'] as Map? ?? {}).entries.take(
          100,
        ))
          if (e.key is String &&
              e.value is Map &&
              e.value['runs'] is int &&
              e.value['seconds'] is int)
            e.key as String: {
              'runs': (e.value['runs'] as int).clamp(0, 1000000000),
              'seconds': (e.value['seconds'] as int).clamp(0, 1000000000),
            },
      },
      totalKills: number('totalKills'),
      totalBossVictories: number('totalBossVictories'),
      bossWins: BossHistory.read(json['bossWins']),
      ownedWeapons: json['weaponAccessVersion'] == 2
          ? strings('ownedWeapons').where(armoryWeapons.containsKey).toSet()
          : <String>{},
      legacyWeaponClaims: <String>{},
      scorpionKills: number('scorpionKills'),
      eliteKills: number('eliteKills'),
      bestSeconds: number('bestSeconds'),
      bestScore: number('bestScore'),
      continuedBestScore: number('continuedBestScore'),
      continuedBestSeconds: number('continuedBestSeconds'),
      assistedBestScore: number('assistedBestScore'),
      assistedBestSeconds: number('assistedBestSeconds'),
      challenges: strings('challenges'),
      discoveredEnemies: strings('enemies'),
      fusions: strings('fusions'),
      cycleWeapons: strings('cycleWeapons'),
      cycleCharacters: strings('cycleCharacters'),
      settledRuns: strings('settledRuns'),
      owned: strings('owned')..add('standard'),
      cosmetic: json['cosmetic'] as String? ?? 'standard',
      pinnedGoal: json['pinnedGoal'] is String
          ? json['pinnedGoal'] as String
          : null,
    );
    final records = json['runRecords'];
    if (records is Map && records.length <= 100) {
      for (final entry in records.entries) {
        if (entry.key is String && entry.value is Map) {
          final record = Map<String, dynamic>.from(entry.value as Map);
          if (record['owner'] is String &&
              record['summary'] is Map &&
              record['summary']['runId'] == entry.key) {
            profile.runRecords[entry.key as String] = record;
          }
        }
      }
    }
    profile.publicUsage = PlayerUsage.read(json['publicUsage']);
    final oldUsage = json['publicUsage'];
    if (oldUsage == null || oldUsage is Map && oldUsage['coverage'] != 2) {
      for (final entry in profile.runRecords.entries) {
        if (profile.settledRuns.contains(entry.key) &&
            entry.value['summary'] is Map &&
            (oldUsage == null || entry.value['summary']['complete'] == false)) {
          profile.publicUsage.record(
            Map<String, dynamic>.from(entry.value['summary'] as Map),
          );
        }
      }
    }
    profile.recordQueueFull = json['recordQueueFull'] == true;
    return profile;
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
  'survivor',
];
const shopCosmetics = {
  'copper': 100,
  'moss': 100,
  'ivory': 150,
  'rust': 175,
  'slate': 175,
  'dusk': 225,
};
