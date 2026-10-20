import 'package:regun/data/loadout.dart';
import 'package:regun/systems/run_random.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/utils/soloud_play.dart';

final gameNotifierProvider =
    NotifierProvider<GameNotifier, GameState>(GameNotifier.new);

class GameNotifier extends Notifier<GameState> {
  double _reloadElapsedMs = 0;
  double _reloadDurationMs = 0;
  int _reloadSoundsLeft = 0;
  int _reloadCue = 0;
  double _nextReloadSoundMs = 700;
  double _invincibilityMs = 0;
  double _hurtCooldownMs = 0;
  double _activeSeconds = 0;
  double _guardElapsed = 0;
  final reloadProgress = ValueNotifier<double>(0);
  final _offerRandom = RunRandom(1);
  WeaponType weapon = WeaponType.shotgun;
  CharacterType character = CharacterType.rook;

  @override
  GameState build() {
    ref.onDispose(reloadProgress.dispose);
    return GameState();
  }

  void resetRun({Loadout loadout = const Loadout(), int seed = 1}) {
    cancelPendingActions();
    weapon = loadout.weapon;
    character = loadout.character;
    _offerRandom.state = seed;
    state = GameState(
        maxBullets: weapon.capacity,
        noOfBullets: weapon.capacity,
        maxHealth: character.health,
        health: character.health,
        movementSpeed: character.speed,
        bulletRange: weapon.range,
        bulletSpeed: weapon.speed,
        baseProjectileSpeed: weapon.speed,
        guard: character == CharacterType.warden);
  }

  void cancelPendingActions() {
    _reloadDurationMs = 0;
    _reloadElapsedMs = 0;
    _reloadSoundsLeft = 0;
    _nextReloadSoundMs = 700;
    _invincibilityMs = 0;
    _hurtCooldownMs = 0;
    _activeSeconds = 0;
    _guardElapsed = 0;
    reloadProgress.value = 0;
  }

  Map<String, dynamic> checkpoint() => {
        'weaponBalance': 2,
        'state': state.toJson(),
        'offerRandom': _offerRandom.state,
        'guardElapsed': _guardElapsed,
        'reloadCue': _reloadCue,
        'activeSeconds': _activeSeconds,
        'reloadElapsedMs': _reloadElapsedMs,
        'reloadDurationMs': _reloadDurationMs,
        'reloadSoundsLeft': _reloadSoundsLeft,
        'nextReloadSoundMs': _nextReloadSoundMs,
      };

  void restoreCheckpoint(Map<String, dynamic> snapshot) {
    var restored =
        GameState.fromJson(Map<String, dynamic>.from(snapshot['state'] as Map));
    if (restored.health <= 0 ||
        restored.health > 10000 ||
        restored.maxBullets < 1 ||
        restored.maxBullets > 100 ||
        restored.noOfBullets < 0 ||
        restored.noOfBullets > restored.maxBullets ||
        restored.noOfCoinsToUpgrade < 1 ||
        !restored.noOfCoinsToUpgrade.isFinite ||
        restored.xP < 0) {
      throw const FormatException('Invalid run state');
    }
    if (weapon == WeaponType.arcCaster && snapshot['weaponBalance'] != 2) {
      restored = restored.copyWith(
          maxBullets: min(100, restored.maxBullets + 2),
          noOfBullets: restored.reloading
              ? restored.noOfBullets
              : min(100, restored.noOfBullets + 2),
          bulletRange: restored.bulletRange + 80,
          bulletSpeed: restored.bulletSpeed + 400,
          baseProjectileSpeed: restored.baseProjectileSpeed + 400);
    }
    cancelPendingActions();
    _activeSeconds = (snapshot['activeSeconds'] as num).toDouble();
    _reloadElapsedMs = (snapshot['reloadElapsedMs'] as num).toDouble();
    _reloadDurationMs = (snapshot['reloadDurationMs'] as num).toDouble();
    _reloadSoundsLeft = snapshot['reloadSoundsLeft'] as int;
    _nextReloadSoundMs = (snapshot['nextReloadSoundMs'] as num).toDouble();
    if (![
      _activeSeconds,
      _reloadElapsedMs,
      _reloadDurationMs,
      _nextReloadSoundMs
    ].every((value) => value.isFinite && value >= 0)) {
      throw const FormatException('Invalid run clocks');
    }
    _offerRandom.state = snapshot['offerRandom'] as int? ?? 1;
    _guardElapsed = (snapshot['guardElapsed'] as num?)?.toDouble() ?? 0;
    _reloadCue = snapshot['reloadCue'] as int? ?? 0;
    reloadProgress.value = _reloadDurationMs > 0
        ? (_reloadElapsedMs / _reloadDurationMs).clamp(0, 1)
        : 0;
    _hurtCooldownMs = 1000; // Clear, fair resume window; no offline simulation.
    state = restored.copyWith(
        gameplayState: GameplayState.paused, triggerSprintInvincibility: false);
  }

  /// Original shotgun timing: first shell 900 ms, each additional shell 700 ms.
  static int reloadDurationFor(int missingShells) =>
      missingShells <= 0 ? 0 : 900 + 700 * (missingShells - 1);

  void reloadBullets() {
    if (state.gameplayState != GameplayState.playing ||
        state.reloading ||
        state.noOfBullets >= state.maxBullets) {
      return;
    }
    final missing = state.maxBullets - state.noOfBullets;
    _reloadElapsedMs = 0;
    _reloadCue = 0;
    final normal = weapon == WeaponType.shotgun
        ? reloadDurationFor(missing)
        : weapon.reloadMs;
    _reloadDurationMs = weapon == WeaponType.shotgun
        ? (state.fastReload ? min(state.fastReloadTime, normal) : normal)
            .toDouble()
        : (normal *
                pow(
                    0.8,
                    max(
                        state.rank(PowerUp.fastReload),
                        state.fastReload
                            ? (2500 - state.fastReloadTime) ~/ 500
                            : 0)))
            .toDouble();
    _reloadSoundsLeft =
        weapon == WeaponType.shotgun && !state.fastReload ? missing - 1 : 0;
    reloadProgress.value = 0;
    _nextReloadSoundMs = 700;
    state = state.copyWith(reloading: true);
    ref.read(soloudPlayProvider).play(weapon == WeaponType.shotgun
        ? 'reload_shotgun_shell.wav'
        : 'reload_${weapon.name}_0.wav');
  }

  void fastReloadBullets() => reloadBullets();

  /// Called only by the game simulation: engine pause also freezes these clocks.
  void advanceTime(double dt) {
    if (state.gameplayState != GameplayState.playing || dt <= 0) return;
    _activeSeconds += dt;
    if (_activeSeconds.floor() != state.survivalSeconds) {
      state = state.copyWith(
          survivalSeconds: _activeSeconds.floor(),
          score: state.score +
              (_activeSeconds.floor() - state.survivalSeconds) * 2);
    }
    if (!state.guard &&
        (state.rank(PowerUp.scrapArmour) > 0 ||
            character == CharacterType.warden)) {
      _guardElapsed += dt;
      if (_guardElapsed >= 20 - state.rank(PowerUp.scrapArmour) * 3) {
        _guardElapsed = 0;
        state = state.copyWith(guard: true);
      }
    }
    final milliseconds = dt * 1000;
    _hurtCooldownMs = max(0, _hurtCooldownMs - milliseconds);
    if (_invincibilityMs > 0) {
      _invincibilityMs = max(0, _invincibilityMs - milliseconds);
      if (_invincibilityMs == 0) removeSprintInvincibilityTrigger();
    }
    if (!state.reloading || _reloadDurationMs <= 0) return;
    _reloadElapsedMs += milliseconds;
    reloadProgress.value = (_reloadElapsedMs / _reloadDurationMs).clamp(0, 1);
    if (weapon != WeaponType.shotgun) {
      while (_reloadCue < 2 &&
          reloadProgress.value >= (_reloadCue == 0 ? 0.42 : 0.82)) {
        _reloadCue++;
        ref
            .read(soloudPlayProvider)
            .play('reload_${weapon.name}_$_reloadCue.wav');
      }
    }
    while (_reloadSoundsLeft > 0 && _reloadElapsedMs >= _nextReloadSoundMs) {
      ref.read(soloudPlayProvider).play('reload_shotgun_shell.wav');
      _reloadSoundsLeft--;
      _nextReloadSoundMs += 700;
    }
    if (weapon == WeaponType.shotgun &&
        _reloadCue == 0 &&
        _reloadElapsedMs >= _reloadDurationMs - 180) {
      _reloadCue = 1;
      ref.read(soloudPlayProvider).play('reload_shotgun_pump.wav');
    }
    if (_reloadElapsedMs + 0.000001 >= _reloadDurationMs) {
      _reloadDurationMs = 0;
      _reloadSoundsLeft = 0;
      state = state.copyWith(noOfBullets: state.maxBullets, reloading: false);
    }
  }

  void decreaseBullets() {
    if (state.noOfBullets <= 0 ||
        state.reloading ||
        state.gameplayState != GameplayState.playing) {
      return;
    }
    state = state.copyWith(noOfBullets: state.noOfBullets - 1);
  }

  void addBullets() {
    _reloadDurationMs = 0;
    _reloadSoundsLeft = 0;
    state = state.copyWith(noOfBullets: 5, maxBullets: 5, reloading: false);
  }

  /// One damage path for contact, melee and projectiles; simultaneous overlaps
  /// cannot consume all health in a single frame.
  bool reduceHealth(
      {int amount = 1,
      String cause = 'The horde',
      bool trainingRespawn = false}) {
    if (state.gameplayState != GameplayState.playing ||
        state.health <= 0 ||
        state.triggerSprintInvincibility ||
        _hurtCooldownMs > 0) {
      return false;
    }
    _hurtCooldownMs = 500;
    if (state.guard) {
      _guardElapsed = 0;
      state = state.copyWith(guard: false);
      return true;
    }
    final health = max(0, state.health - amount);
    state = state.copyWith(
      health: health,
      causeOfDeath: health == 0 ? cause : state.causeOfDeath,
      gameplayState: health == 0 && !trainingRespawn
          ? GameplayState.gameOver
          : GameplayState.playing,
    );
    return true;
  }

  void updateScore() {
    if (state.gameplayState == GameplayState.playing) {
      state = state.copyWith(score: state.score + 1);
    }
  }

  void resetScore() => state = state.copyWith(
      score: 0,
      xP: 0,
      currentLevel: 1,
      noOfCoinsToUpgrade: 7,
      powerUpChoices: const []);

  void addCycleBonus() => state = state.copyWith(score: state.score + 250);

  void recordKill({int score = 10, bool boss = false}) {
    if (state.gameplayState != GameplayState.playing) return;
    state = state.copyWith(
      score: state.score + score,
      kills: state.kills + 1,
      bosses: state.bosses + (boss ? 1 : 0),
    );
  }

  void increaseXP([int amount = 1]) {
    if (state.gameplayState != GameplayState.playing || amount <= 0) return;
    state = state.copyWith(xP: state.xP + amount);
    if (state.xP >= state.noOfCoinsToUpgrade.floor()) upgradeLevel();
  }

  void resetXP() => state = state.copyWith(xP: 0);

  List<PowerUp> _rollOffers() {
    final pool = eligiblePowerUps(state);
    final choices = <PowerUp>[];
    while (choices.length < 3 && pool.isNotEmpty) {
      double weight(PowerUp p) =>
          (p.group == UpgradeGroup.special
              ? 1 + state.rank(PowerUp.luckyFind) * 0.35
              : 1) *
          (state.rank(p) > 0 ? 1.5 : 1);
      final total = pool.fold<double>(0, (sum, p) => sum + weight(p));
      var pick = _offerRandom.nextDouble() * total;
      var index = pool.length - 1;
      for (var i = 0; i < pool.length; i++) {
        pick -= weight(pool[i]);
        if (pick <= 0) {
          index = i;
          break;
        }
      }
      choices.add(pool.removeAt(index));
    }
    return choices;
  }

  void upgradeLevel() {
    if (state.gameplayState != GameplayState.playing) return;
    final choices = _rollOffers();
    state = state.copyWith(
      xP: max(0, state.xP - state.noOfCoinsToUpgrade.floor()),
      currentLevel: state.currentLevel + 1,
      offerId: state.offerId + 1,
      noOfCoinsToUpgrade: state.noOfCoinsToUpgrade * 1.2,
      gameplayState: GameplayState.powerup,
      powerUpChoices: List.unmodifiable(choices.take(3)),
    );
  }

  void applyPowerUp(PowerUp powerUp, {int? offerId}) {
    if ((offerId != null && offerId != state.offerId) ||
        state.gameplayState != GameplayState.powerup ||
        !state.powerUpChoices.contains(powerUp)) {
      return;
    }
    if (powerUp != PowerUp.salvage) {
      state = state.copyWith(
          ranks: Map.unmodifiable(
              {...state.ranks, powerUp: state.rank(powerUp) + 1}));
    }
    switch (powerUp) {
      case PowerUp.maxBulletsIncrease:
        maxBulletsIncrease();
      case PowerUp.healthIncrease:
        healthIncrease();
      case PowerUp.walkingSpeedIncrease:
        walkingSpeedIncrease();
      case PowerUp.sprintDistanceIncrease:
        sprintDistanceIncrease();
      case PowerUp.bulletRangeIncrease:
        bulletRangeIncrease();
      case PowerUp.numberOfBulletsPerShotIncrease:
        numberOfBulletsPerShotIncrease();
      case PowerUp.fastReload:
        fastReload();
      case PowerUp.sprintInvincibility:
        sprintInvincibility();
      case PowerUp.bulletsPhaseThrough:
        triggerBulletsPhaseThrough();
      case PowerUp.rapidFire:
        rapidFire();
      case PowerUp.sprintMine:
        sprintMine();
      case PowerUp.heavyLoad:
        state = state.copyWith(shotDamage: state.shotDamage + 0.35);
      case PowerUp.lastShell:
        state = state.copyWith(lastShellRank: state.lastShellRank + 1);
      case PowerUp.breachLoader:
        state = state.copyWith(breachRank: state.breachRank + 1);
      case PowerUp.scrapArmour:
        state = state.copyWith(guard: true);
      case PowerUp.salvage:
        state = state.copyWith(
            scrap: state.scrap + 5,
            health: min(state.maxHealth, state.health + 1));
      default:
        break;
    }
    state = state.copyWith(
        gameplayState: GameplayState.playing,
        powerUpChoices: const [],
        evolutionChoices: const []);
    if (state.pendingCores > 0) {
      openBossCore();
    } else if (state.xP >= state.noOfCoinsToUpgrade.floor()) {
      upgradeLevel();
    }
  }

  void reroll({required int offerId}) {
    if (state.gameplayState != GameplayState.powerup ||
        state.offerId != offerId ||
        state.rerolls <= 0 ||
        state.evolutionChoices.isNotEmpty) {
      return;
    }
    final pool = _rollOffers();
    state = state.copyWith(
        rerolls: state.rerolls - 1,
        offerId: state.offerId + 1,
        powerUpChoices: List.unmodifiable(pool.take(3)));
  }

  void ban(PowerUp powerUp, {required int offerId}) {
    if (state.gameplayState != GameplayState.powerup ||
        state.offerId != offerId ||
        state.bans <= 0 ||
        !state.powerUpChoices.contains(powerUp) ||
        powerUp == PowerUp.salvage) {
      return;
    }
    state = state.copyWith(
        bans: state.bans - 1,
        banned: Set.unmodifiable({...state.banned, powerUp}));
    final pool = _rollOffers();
    state = state.copyWith(
        offerId: state.offerId + 1,
        powerUpChoices: List.unmodifiable(pool.take(3)));
  }

  void awardBossCore() {
    state = state.copyWith(pendingCores: state.pendingCores + 1);
    if (state.gameplayState == GameplayState.playing) openBossCore();
  }

  void openBossCore() {
    final recipes = fusionRecipes
        .where((r) => r.available(state))
        .map((r) => r.id)
        .toList();
    final pool = _rollOffers();
    state = state.copyWith(
        pendingCores: max(0, state.pendingCores - 1),
        gameplayState: GameplayState.powerup,
        offerId: state.offerId + 1,
        evolutionChoices: List.unmodifiable(recipes),
        powerUpChoices: List.unmodifiable(pool.take(3)));
  }

  void fuse(String id, {required int offerId}) {
    if (state.gameplayState != GameplayState.powerup ||
        state.offerId != offerId ||
        !state.evolutionChoices.contains(id)) {
      return;
    }
    state = state.copyWith(
        evolutions: Set.unmodifiable({...state.evolutions, id}),
        evolutionChoices: const [],
        powerUpChoices: const [],
        gameplayState: GameplayState.playing);
    if (state.pendingCores > 0) {
      openBossCore();
    } else if (state.xP >= state.noOfCoinsToUpgrade.floor()) {
      upgradeLevel();
    }
  }

  void prepareTrainingFusion(FusionRecipe recipe) {
    final ranks = {...state.ranks, recipe.first: 3, recipe.second: 2};
    state = state.copyWith(
        ranks: Map.unmodifiable(ranks),
        lastShellRank: ranks[PowerUp.lastShell] ?? 0,
        breachRank: ranks[PowerUp.breachLoader] ?? 0,
        evolutions: const {},
        pendingCores: 1,
        gameplayState: GameplayState.playing);
    openBossCore();
  }

  void heal([int amount = 1]) => state =
      state.copyWith(health: min(state.maxHealth, state.health + amount));

  void refillPractice() {
    _reloadDurationMs = 0;
    _reloadSoundsLeft = 0;
    _reloadElapsedMs = 0;
    reloadProgress.value = 0;
    _hurtCooldownMs = 1000;
    state = state.copyWith(
        health: state.maxHealth,
        noOfBullets: state.maxBullets,
        reloading: false);
  }

  void grantResumeGrace() => _hurtCooldownMs = 1000;

  void recoverTrainingPlayer() {
    refillPractice();
    _hurtCooldownMs = 2000;
    state = state.copyWith(causeOfDeath: '');
  }

  void pauseGame() {
    if (state.gameplayState == GameplayState.playing) {
      state = state.copyWith(gameplayState: GameplayState.paused);
    }
  }

  void playGame() {
    if (state.gameplayState == GameplayState.paused) {
      state = state.copyWith(
          gameplayState: state.powerUpChoices.isNotEmpty
              ? GameplayState.powerup
              : GameplayState.playing);
    }
  }

  void powerupState() => upgradeLevel();
  void gameOver() =>
      state = state.copyWith(health: 0, gameplayState: GameplayState.gameOver);

  void maxBulletsIncrease() {
    _reloadDurationMs = 0;
    _reloadSoundsLeft = 0;
    final capacity = state.maxBullets + (weapon == WeaponType.carbine ? 6 : 2);
    state = state.copyWith(
        maxBullets: capacity, noOfBullets: capacity, reloading: false);
  }

  void healthIncrease() => state =
      state.copyWith(health: state.health + 1, maxHealth: state.maxHealth + 1);
  void resetHealth() => state = state.copyWith(health: state.maxHealth);
  void walkingSpeedIncrease() =>
      state = state.copyWith(movementSpeed: state.movementSpeed + 50);
  void resetWalkingSpeed() => state = state.copyWith(movementSpeed: 300);
  void sprintDistanceIncrease() =>
      state = state.copyWith(sprintTimeDistance: state.sprintTimeDistance + 15);
  void resetSprintTimeDistance() =>
      state = state.copyWith(sprintTimeDistance: 150);
  void bulletRangeIncrease() =>
      state = state.copyWith(bulletRange: state.bulletRange + 60);
  void resetBulletRange() => state = state.copyWith(bulletRange: 420);
  void numberOfBulletsPerShotIncrease() => state =
      state.copyWith(bulletNumberRange: min(4, state.bulletNumberRange + 1));
  void resetBulletNumberRange() => state = state.copyWith(bulletNumberRange: 1);
  void fastReload() => state = state.copyWith(
      fastReload: true, fastReloadTime: max(1000, state.fastReloadTime - 500));
  void resetFastReload() =>
      state = state.copyWith(fastReload: false, fastReloadTime: 2500);
  void sprintInvincibility() =>
      state = state.copyWith(sprintInvincibility: true);
  void resetSprintInvincibility() =>
      state = state.copyWith(sprintInvincibility: false);
  void triggerSprintInvincibility() {
    if (state.gameplayState != GameplayState.playing) {
      return;
    }
    _invincibilityMs = state.sprintInvincibility
        ? state.sprintTimeDistance.toDouble()
        : min(80, state.sprintTimeDistance).toDouble();
    state = state.copyWith(triggerSprintInvincibility: true);
  }

  void removeSprintInvincibilityTrigger() =>
      state = state.copyWith(triggerSprintInvincibility: false);
  void triggerBulletsPhaseThrough() =>
      state = state.copyWith(bulletsPhaseThrough: true);
  void resetBulletsPhaseThrough() =>
      state = state.copyWith(bulletsPhaseThrough: false);
  void rapidFire() => state = state.copyWith(
      bulletSpeed:
          min(state.baseProjectileSpeed + 600, state.bulletSpeed + 200));
  void resetFireRate() => state = state.copyWith(bulletSpeed: 700);
  void sprintMine() => state = state.copyWith(triggerSprintMine: true);
  void removeSprintMine() => state = state.copyWith(triggerSprintMine: false);
  void decreaseSprintMineCount() => state =
      state.copyWith(sprintMineCount: max(0, state.sprintMineCount - 1));
  void increaseSprintMineCount() => state =
      state.copyWith(sprintMineCount: min(3, state.sprintMineCount + 1));
  void resetSprintMineCount() => state = state.copyWith(sprintMineCount: 3);
}

class GameState {
  final int maxHealth;
  final bool guard;
  final int rerolls;
  final int bans;
  final int scrap;
  final int pendingCores;
  final String causeOfDeath;
  final Map<PowerUp, int> ranks;
  final Set<PowerUp> banned;
  final Set<String> evolutions;
  final List<String> evolutionChoices;
  int rank(PowerUp value) => ranks[value] ?? 0;
  bool fused(String id) => evolutions.contains(id);
  final int offerId;
  final int score;
  final int kills;
  final int bosses;
  final int survivalSeconds;
  final double shotDamage;
  final double baseProjectileSpeed;
  final int lastShellRank;
  final int breachRank;

  final List<PowerUp> powerUpChoices;
  final GameplayState gameplayState;
  final int maxBullets;
  final int noOfBullets;
  final bool reloading;
  final int health;
  final int xP;
  final int currentLevel;
  final double noOfCoinsToUpgrade;
  final double movementSpeed;
  final int sprintTimeDistance;
  final int bulletRange;
  final int bulletNumberRange;
  final bool fastReload;
  final int fastReloadTime;
  final bool sprintInvincibility;
  final bool triggerSprintInvincibility;
  final bool bulletsPhaseThrough;
  final double bulletSpeed;
  final bool triggerSprintMine;
  final int sprintMineCount;
  final bool triggerEnemySpawn;

  GameState({
    this.maxHealth = 6,
    this.guard = false,
    this.rerolls = 2,
    this.bans = 1,
    this.scrap = 0,
    this.pendingCores = 0,
    this.causeOfDeath = '',
    this.ranks = const {},
    this.banned = const {},
    this.evolutions = const {},
    this.evolutionChoices = const [],
    this.offerId = 0,
    this.score = 0,
    this.kills = 0,
    this.bosses = 0,
    this.survivalSeconds = 0,
    this.shotDamage = 1,
    this.baseProjectileSpeed = 700,
    this.lastShellRank = 0,
    this.breachRank = 0,
    this.powerUpChoices = const [],
    this.gameplayState = GameplayState.playing,
    this.maxBullets = 5,
    this.noOfBullets = 5,
    this.reloading = false,
    this.health = 6,
    this.xP = 0,
    this.currentLevel = 1,
    this.noOfCoinsToUpgrade = 7,
    this.movementSpeed = 300.0,
    this.sprintTimeDistance = 150,
    this.bulletRange = 420,
    this.bulletNumberRange = 1,
    this.fastReload = false,
    this.fastReloadTime = 2500,
    this.sprintInvincibility = false,
    this.triggerSprintInvincibility = false,
    this.bulletsPhaseThrough = false,
    this.bulletSpeed = 700,
    this.triggerSprintMine = false,
    this.sprintMineCount = 3,
    this.triggerEnemySpawn = false,
  });

  Map<String, dynamic> toJson() => {
        'maxHealth': maxHealth,
        'guard': guard,
        'rerolls': rerolls,
        'bans': bans,
        'scrap': scrap,
        'pendingCores': pendingCores,
        'causeOfDeath': causeOfDeath,
        'ranks': ranks.map((key, value) => MapEntry(key.name, value)),
        'banned': banned.map((value) => value.name).toList(),
        'evolutions': evolutions.toList(),
        'evolutionChoices': evolutionChoices.toList(),
        'offerId': offerId,
        'score': score,
        'kills': kills,
        'bosses': bosses,
        'survivalSeconds': survivalSeconds,
        'shotDamage': shotDamage,
        'baseProjectileSpeed': baseProjectileSpeed,
        'lastShellRank': lastShellRank,
        'breachRank': breachRank,
        'powerUpChoices': powerUpChoices.map((value) => value.name).toList(),
        'gameplayState': gameplayState.name,
        'maxBullets': maxBullets,
        'noOfBullets': noOfBullets,
        'reloading': reloading,
        'health': health,
        'xP': xP,
        'currentLevel': currentLevel,
        'noOfCoinsToUpgrade': noOfCoinsToUpgrade,
        'movementSpeed': movementSpeed,
        'sprintTimeDistance': sprintTimeDistance,
        'bulletRange': bulletRange,
        'bulletNumberRange': bulletNumberRange,
        'fastReload': fastReload,
        'fastReloadTime': fastReloadTime,
        'sprintInvincibility': sprintInvincibility,
        'triggerSprintInvincibility': triggerSprintInvincibility,
        'bulletsPhaseThrough': bulletsPhaseThrough,
        'bulletSpeed': bulletSpeed,
        'triggerSprintMine': triggerSprintMine,
        'sprintMineCount': sprintMineCount,
        'triggerEnemySpawn': triggerEnemySpawn,
      };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        maxHealth: json['maxHealth'] as int? ?? 3,
        guard: json['guard'] as bool? ?? false,
        rerolls: json['rerolls'] as int? ?? 2,
        bans: json['bans'] as int? ?? 1,
        scrap: json['scrap'] as int? ?? 0,
        pendingCores: json['pendingCores'] as int? ?? 0,
        causeOfDeath: json['causeOfDeath'] as String? ?? '',
        ranks: Map.unmodifiable((json['ranks'] as Map? ?? {}).map(
            (key, value) =>
                MapEntry(PowerUp.values.byName(key as String), value as int))),
        banned: Set.unmodifiable((json['banned'] as List? ?? [])
            .map((name) => PowerUp.values.byName(name as String))),
        evolutions: Set.unmodifiable(
            (json['evolutions'] as List? ?? []).cast<String>()),
        evolutionChoices: List.unmodifiable(
            (json['evolutionChoices'] as List? ?? []).cast<String>()),
        offerId: json['offerId'] as int,
        score: json['score'] as int,
        kills: json['kills'] as int,
        bosses: json['bosses'] as int,
        survivalSeconds: json['survivalSeconds'] as int,
        shotDamage: (json['shotDamage'] as num).toDouble(),
        baseProjectileSpeed:
            (json['baseProjectileSpeed'] as num?)?.toDouble() ?? 700,
        lastShellRank: json['lastShellRank'] as int,
        breachRank: json['breachRank'] as int,
        powerUpChoices: List.unmodifiable((json['powerUpChoices'] as List)
            .map((name) => PowerUp.values.byName(name as String))),
        gameplayState:
            GameplayState.values.byName(json['gameplayState'] as String),
        maxBullets: json['maxBullets'] as int,
        noOfBullets: json['noOfBullets'] as int,
        reloading: json['reloading'] as bool,
        health: json['health'] as int,
        xP: json['xP'] as int,
        currentLevel: json['currentLevel'] as int,
        noOfCoinsToUpgrade: (json['noOfCoinsToUpgrade'] as num).toDouble(),
        movementSpeed: (json['movementSpeed'] as num).toDouble(),
        sprintTimeDistance: json['sprintTimeDistance'] as int,
        bulletRange: json['bulletRange'] as int,
        bulletNumberRange: json['bulletNumberRange'] as int,
        fastReload: json['fastReload'] as bool,
        fastReloadTime: json['fastReloadTime'] as int,
        sprintInvincibility: json['sprintInvincibility'] as bool,
        triggerSprintInvincibility: json['triggerSprintInvincibility'] as bool,
        bulletsPhaseThrough: json['bulletsPhaseThrough'] as bool,
        bulletSpeed: (json['bulletSpeed'] as num).toDouble(),
        triggerSprintMine: json['triggerSprintMine'] as bool,
        sprintMineCount: json['sprintMineCount'] as int,
        triggerEnemySpawn: json['triggerEnemySpawn'] as bool,
      );

  GameState copyWith({
    int? maxHealth,
    bool? guard,
    int? rerolls,
    int? bans,
    int? scrap,
    int? pendingCores,
    String? causeOfDeath,
    Map<PowerUp, int>? ranks,
    Set<PowerUp>? banned,
    Set<String>? evolutions,
    List<String>? evolutionChoices,
    int? offerId,
    int? score,
    int? kills,
    int? bosses,
    int? survivalSeconds,
    double? shotDamage,
    double? baseProjectileSpeed,
    int? lastShellRank,
    int? breachRank,
    List<PowerUp>? powerUpChoices,
    GameplayState? gameplayState,
    int? maxBullets,
    int? noOfBullets,
    bool? reloading,
    int? health,
    int? xP,
    int? currentLevel,
    double? noOfCoinsToUpgrade,
    double? movementSpeed,
    int? sprintTimeDistance,
    int? bulletRange,
    int? bulletNumberRange,
    bool? fastReload,
    int? fastReloadTime,
    bool? sprintInvincibility,
    bool? triggerSprintInvincibility,
    bool? bulletsPhaseThrough,
    double? bulletSpeed,
    bool? triggerSprintMine,
    int? sprintMineCount,
    bool? triggerEnemySpawn,
  }) {
    return GameState(
      maxHealth: maxHealth ?? this.maxHealth,
      guard: guard ?? this.guard,
      rerolls: rerolls ?? this.rerolls,
      bans: bans ?? this.bans,
      scrap: scrap ?? this.scrap,
      pendingCores: pendingCores ?? this.pendingCores,
      causeOfDeath: causeOfDeath ?? this.causeOfDeath,
      ranks: ranks ?? this.ranks,
      banned: banned ?? this.banned,
      evolutions: evolutions ?? this.evolutions,
      evolutionChoices: evolutionChoices ?? this.evolutionChoices,
      offerId: offerId ?? this.offerId,
      score: score ?? this.score,
      kills: kills ?? this.kills,
      bosses: bosses ?? this.bosses,
      survivalSeconds: survivalSeconds ?? this.survivalSeconds,
      shotDamage: shotDamage ?? this.shotDamage,
      baseProjectileSpeed: baseProjectileSpeed ?? this.baseProjectileSpeed,
      lastShellRank: lastShellRank ?? this.lastShellRank,
      breachRank: breachRank ?? this.breachRank,
      powerUpChoices: powerUpChoices ?? this.powerUpChoices,
      gameplayState: gameplayState ?? this.gameplayState,
      maxBullets: maxBullets ?? this.maxBullets,
      noOfBullets: noOfBullets ?? this.noOfBullets,
      reloading: reloading ?? this.reloading,
      health: health ?? this.health,
      xP: xP ?? this.xP,
      currentLevel: currentLevel ?? this.currentLevel,
      noOfCoinsToUpgrade: noOfCoinsToUpgrade ?? this.noOfCoinsToUpgrade,
      movementSpeed: movementSpeed ?? this.movementSpeed,
      sprintTimeDistance: sprintTimeDistance ?? this.sprintTimeDistance,
      bulletRange: bulletRange ?? this.bulletRange,
      bulletNumberRange: bulletNumberRange ?? this.bulletNumberRange,
      fastReload: fastReload ?? this.fastReload,
      fastReloadTime: fastReloadTime ?? this.fastReloadTime,
      sprintInvincibility: sprintInvincibility ?? this.sprintInvincibility,
      triggerSprintInvincibility:
          triggerSprintInvincibility ?? this.triggerSprintInvincibility,
      bulletsPhaseThrough: bulletsPhaseThrough ?? this.bulletsPhaseThrough,
      bulletSpeed: bulletSpeed ?? this.bulletSpeed,
      triggerSprintMine: triggerSprintMine ?? this.triggerSprintMine,
      sprintMineCount: sprintMineCount ?? this.sprintMineCount,
      triggerEnemySpawn: triggerEnemySpawn ?? this.triggerEnemySpawn,
    );
  }
}

enum GameplayState {
  playing,
  paused,
  gameOver,
  powerup,
}

enum UpgradeGroup { core, utility, special, legacy, fallback }

enum PowerUp {
  heavyLoad('Heavy Load', '+35% base projectile damage.', UpgradeGroup.core),
  quickTrigger('Quick Trigger', 'Fire 15% faster.', UpgradeGroup.core),
  maxBulletsIncrease('Extended Tube', 'Larger magazine; refill immediately.',
      UpgradeGroup.core),
  fastReload('Sleight of Hand', 'Reload faster.', UpgradeGroup.core),
  numberOfBulletsPerShotIncrease(
      'Scattershot', 'More projectiles; wider spread.', UpgradeGroup.core),
  bulletsPhaseThrough(
      'Piercing Rounds', 'Hit additional enemies.', UpgradeGroup.core),
  bulletRangeIncrease(
      'Long Barrel', 'Increase effective range.', UpgradeGroup.core),
  rapidFire('High Velocity', 'Faster projectiles.', UpgradeGroup.core),
  walkingSpeedIncrease('Fleet Foot', 'Move faster.', UpgradeGroup.utility),
  healthIncrease(
      'Vitality', 'Add a heart and recover one.', UpgradeGroup.utility),
  fieldMedic('Field Medic', 'Kills: 5% chance per rank to restore a heart.',
      UpgradeGroup.utility),
  scrapArmour(
      'Scrap Armour', 'Absorb a hit; guard recharges.', UpgradeGroup.utility),
  quickstep('Quickstep', 'Dash recharges faster.', UpgradeGroup.utility),
  sprintInvincibility(
      'Afterimage', 'Longer dash protection.', UpgradeGroup.utility),
  scavenger('Scavenger', 'Attract XP from farther away.', UpgradeGroup.utility),
  luckyFind('Lucky Find', 'Special upgrades appear more often.',
      UpgradeGroup.utility),
  hotShot('Hot Shot', 'Hits ignite enemies.', UpgradeGroup.special),
  accelerant('Accelerant', 'Burning kills ignite nearby enemies.',
      UpgradeGroup.special),
  staticCharge('Static Charge', 'Primary hits can arc to another enemy.',
      UpgradeGroup.special),
  conductiveCore('Conductive Core',
      'Lightning chains farther and hits more targets.', UpgradeGroup.special),
  sprintMine('Dash Mine', 'Leave a mine after a dash.', UpgradeGroup.special),
  fragmentation('Fragmentation', 'Explosions emit a small shard burst.',
      UpgradeGroup.special),
  ricochet(
      'Ricochet', 'Projectiles bounce to a new enemy.', UpgradeGroup.special),
  bankShot('Bank Shot', 'Bounced shots hit harder.', UpgradeGroup.special),
  lastShell(
      'Last Shell', 'Final shot: +60% damage per rank.', UpgradeGroup.special),
  breachLoader('Breach Loader',
      'First shot after reload: +50% damage per rank.', UpgradeGroup.special),
  orbitDrone('Orbit Drone', 'A companion fires at nearby enemies.',
      UpgradeGroup.special),
  targetingLink('Targeting Link', 'Shots mark targets for drone focus.',
      UpgradeGroup.special),
  shrapnel('Shrapnel', 'Kills can release a close-range shard cone.',
      UpgradeGroup.special),
  executioner('Executioner', 'Deal more damage to wounded enemies.',
      UpgradeGroup.special),
  sprintDistanceIncrease('Long Dash', 'Dash farther.', UpgradeGroup.legacy),
  salvage('Scrap Cache', 'Gain 5 scrap and recover a heart.',
      UpgradeGroup.fallback);

  const PowerUp(this.title, this.description, this.group);
  final String title, description;
  final UpgradeGroup group;
  int get maxRank => switch (this) {
        PowerUp.sprintInvincibility => 1,
        PowerUp.salvage => 0,
        _ => 3,
      };
}

final List<PowerUp> powerUps = List.unmodifiable(PowerUp.values.where(
    (p) => p.group != UpgradeGroup.legacy && p.group != UpgradeGroup.fallback));

List<PowerUp> eligiblePowerUps(GameState state) {
  final specialSlots =
      state.ranks.keys.where((p) => p.group == UpgradeGroup.special).length;
  final eligible = powerUps.where((p) {
    if (state.banned.contains(p) || state.rank(p) >= p.maxRank) return false;
    if (p.group == UpgradeGroup.special &&
        state.rank(p) == 0 &&
        specialSlots >= 6) {
      return false;
    }
    return switch (p) {
      PowerUp.sprintInvincibility => !state.sprintInvincibility,
      PowerUp.bulletsPhaseThrough =>
        !state.bulletsPhaseThrough || state.rank(p) > 0,
      PowerUp.numberOfBulletsPerShotIncrease => state.bulletNumberRange < 4,
      PowerUp.rapidFire => state.bulletSpeed < state.baseProjectileSpeed + 600,
      PowerUp.fastReload => !state.fastReload || state.fastReloadTime > 1000,
      PowerUp.heavyLoad => state.shotDamage < 2.05,
      _ => true,
    };
  }).toList();
  if (eligible.length < 3) eligible.add(PowerUp.salvage);
  return eligible;
}

class FusionRecipe {
  const FusionRecipe(
      this.id, this.title, this.first, this.second, this.description);
  final String id, title, description;
  final PowerUp first, second;
  bool available(GameState state) =>
      state.evolutions.length < 2 &&
      !state.fused(id) &&
      state.rank(first) >= 3 &&
      state.rank(second) >= 2;
}

const fusionRecipes = [
  FusionRecipe('firebreak', 'Firebreak', PowerUp.hotShot, PowerUp.accelerant,
      'Ignitions leave burning ground.'),
  FusionRecipe('stormCircuit', 'Storm Circuit', PowerUp.staticCharge,
      PowerUp.conductiveCore, 'Lightning leaps through marked clusters.'),
  FusionRecipe('minefield', 'Minefield', PowerUp.sprintMine,
      PowerUp.fragmentation, 'Dashing leaves a mine trail.'),
  FusionRecipe('pinball', 'Pinball', PowerUp.ricochet, PowerUp.bankShot,
      'Extra ricochets with stronger impacts.'),
  FusionRecipe('breachEngine', 'Breach Engine', PowerUp.lastShell,
      PowerUp.breachLoader, 'Final shots and reload bursts hit harder.'),
  FusionRecipe('hunterSwarm', 'Hunter Swarm', PowerUp.orbitDrone,
      PowerUp.targetingLink, 'Three drones focus marked targets.'),
];
