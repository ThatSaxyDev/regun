import 'package:regun/systems/rank_effect_values.dart';
import 'package:regun/systems/rank_curve.dart';
import 'package:regun/systems/upgrade_offer_policy.dart';
import 'package:regun/services/balance_repository.dart';
import 'package:regun/data/weapon_power_balance.dart';
import 'package:regun/systems/survivor_runtime.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/systems/run_random.dart';
import 'package:regun/systems/xp_progression.dart';
import 'package:flutter/foundation.dart';

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/utils/soloud_play.dart';

final gameNotifierProvider = NotifierProvider<GameNotifier, GameState>(
  GameNotifier.new,
);

class GameNotifier extends Notifier<GameState> {
  SurvivorRuntime survivor = SurvivorRuntime();
  WeaponPowerBalance weaponPower = WeaponPowerBalance.current;
  int buildBalance = 2;
  int _offerPolicy = UpgradeOfferPolicy.version;
  List<String> _recentOffers = [];
  double _reloadElapsedMs = 0;
  double _reloadDurationMs = 0;
  int _reloadSoundsLeft = 0;
  int _reloadCue = 0;
  double _nextReloadSoundMs = ShotgunReload.shellIntervalMs.toDouble();
  bool _reloadTactical = false;
  bool supplyOffer = false;
  double get reloadRemainingSeconds =>
      state.reloading ? max(0, _reloadDurationMs - _reloadElapsedMs) / 1000 : 0;
  bool get reloadTactical => state.reloading && _reloadTactical;
  double _invincibilityMs = 0;
  double _hurtCooldownMs = 0;
  double _activeSeconds = 0;
  double _guardElapsed = 0;
  double _choiceGrace = 0;
  final upgradeConfirmed = ValueNotifier<int>(0);
  final reloadProgress = ValueNotifier<double>(0);
  final quickRefillProgress = ValueNotifier<double>(-1);
  double _quickRefillMs = -1;
  final _offerRandom = RunRandom(1);
  WeaponType weapon = WeaponType.shotgun;
  CharacterType character = CharacterType.rook;

  @override
  GameState build() {
    ref.onDispose(upgradeConfirmed.dispose);
    ref.onDispose(reloadProgress.dispose);
    ref.onDispose(quickRefillProgress.dispose);
    return GameState();
  }

  void resetRun({Loadout loadout = const Loadout(), int seed = 1}) {
    cancelPendingActions();
    weapon = loadout.weapon;
    character = loadout.character;
    buildBalance = 2;
    _offerPolicy = UpgradeOfferPolicy.version;
    _recentOffers = [];
    weaponPower = WeaponPowerBalance.live(BalanceRepository.shared.current);
    _offerRandom.state = seed;
    state = GameState(
      upgradeStrengths: weaponPower.upgradeStrengths,
      rankCurves: weaponPower.rankCurves,
      maxBullets: weaponPower.capacity(weapon),
      noOfBullets: weaponPower.capacity(weapon),
      maxHealth: weaponPower.health(character),
      health: weaponPower.health(character),
      movementSpeed: weaponPower.movement(character),
      bulletRange: weaponPower.range(weapon),
      bulletSpeed: weaponPower.speed(weapon),
      baseProjectileSpeed: weaponPower.speed(weapon),
      guard: character == CharacterType.warden,
    );
  }

  void changeTrainingWeapon(WeaponType next) {
    if (state.gameplayState != GameplayState.paused) return;
    final old = weapon;
    final rank = state.rank(PowerUp.maxBulletsIncrease);
    final extra = (state.rankTotal(
      PowerUp.maxBulletsIncrease,
      rank,
      next == WeaponType.carbine ? 6 : 2,
      next == WeaponType.carbine ? 2 : 1,
    )).round();
    final capacity = next == WeaponType.prismCutter
        ? min(24, weaponPower.capacity(next) + extra)
        : min(
            next == WeaponType.beltRepeater ? 128 : 100,
            weaponPower.capacity(next) + extra,
          );
    weapon = next;
    _reloadDurationMs = _reloadElapsedMs = 0;
    _reloadSoundsLeft = _reloadCue = 0;
    _reloadTactical = false;
    _quickRefillMs = -1;
    quickRefillProgress.value = -1;
    reloadProgress.value = 0;
    state = state.copyWith(
      maxBullets: capacity,
      noOfBullets: capacity,
      reloading: false,
      bulletRange:
          weaponPower.range(next) +
          max(0, state.bulletRange - weaponPower.range(old)),
      bulletSpeed: min(
        2000,
        weaponPower.speed(next) +
            max(0, state.bulletSpeed - weaponPower.speed(old)),
      ),
      baseProjectileSpeed: weaponPower.speed(next),
    );
  }

  void cancelPendingActions() {
    survivor = SurvivorRuntime();
    _choiceGrace = 0;
    supplyOffer = false;
    _quickRefillMs = -1;
    quickRefillProgress.value = -1;
    _reloadDurationMs = 0;
    _reloadElapsedMs = 0;
    _reloadTactical = false;
    _reloadSoundsLeft = 0;
    _nextReloadSoundMs = ShotgunReload.shellIntervalMs.toDouble();
    _invincibilityMs = 0;
    _hurtCooldownMs = 0;
    _activeSeconds = 0;
    _guardElapsed = 0;
    reloadProgress.value = 0;
  }

  Map<String, dynamic> checkpoint() => {
    'xpCurve': 3,
    'buildBalance': buildBalance,
    'offerPolicy': _offerPolicy,
    'recentOffers': List<String>.of(_recentOffers),
    'weaponPowerBalance': weaponPower.revision,
    if (weaponPower.snapshot != null)
      'balanceSnapshot': weaponPower.snapshot!.toJson(),
    'survivorRuntime': survivor.toJson(),
    'choiceGrace': _choiceGrace,
    'weaponBalance': 2,
    'shotgunReloadBalance': 1,
    'arsenalReviewBalance': 2,
    'survivorSpeedBalance': 3,
    'state': state.toJson(),
    'offerRandom': _offerRandom.state,
    'guardElapsed': _guardElapsed,
    'reloadCue': _reloadCue,
    'reloadTactical': _reloadTactical,
    'reloadPolicy': 2,
    'supplyOffer': supplyOffer,
    'activeSeconds': _activeSeconds,
    'reloadElapsedMs': _reloadElapsedMs,
    'reloadDurationMs': _reloadDurationMs,
    'reloadSoundsLeft': _reloadSoundsLeft,
    'nextReloadSoundMs': _nextReloadSoundMs,
  };

  void restoreCheckpoint(
    Map<String, dynamic> snapshot, {
    bool allowDead = false,
  }) {
    final restoredPower = WeaponPowerBalance.read(
      snapshot['weaponPowerBalance'],
      snapshot['balanceSnapshot'],
    );
    var restored = GameState.fromJson(
      Map<String, dynamic>.from(snapshot['state'] as Map),
    );
    if ((restored.health <= 0 && !allowDead) ||
        restored.health < 0 ||
        restored.health > 10000 ||
        restored.maxBullets < 1 ||
        restored.maxBullets > (weapon == WeaponType.beltRepeater ? 128 : 100) ||
        restored.noOfBullets < 0 ||
        restored.noOfBullets > restored.maxBullets ||
        restored.noOfCoinsToUpgrade < 1 ||
        !restored.noOfCoinsToUpgrade.isFinite ||
        restored.xP < 0) {
      throw const FormatException('Invalid run state');
    }
    final survivorSpeedBalance =
        (snapshot['survivorSpeedBalance'] as num?)?.toInt() ?? 0;
    if (character == CharacterType.scrapper && survivorSpeedBalance < 1) {
      restored = restored.copyWith(movementSpeed: restored.movementSpeed + 45);
    }
    if (character == CharacterType.scrapper &&
        survivorSpeedBalance >= 1 &&
        survivorSpeedBalance < 3) {
      restored = restored.copyWith(movementSpeed: restored.movementSpeed - 105);
    }
    if (character == CharacterType.warden && survivorSpeedBalance < 2) {
      restored = restored.copyWith(movementSpeed: restored.movementSpeed - 9);
    }
    if (weapon == WeaponType.arcCaster && snapshot['weaponBalance'] != 2) {
      restored = restored.copyWith(
        maxBullets: min(100, restored.maxBullets + 2),
        noOfBullets: restored.reloading
            ? restored.noOfBullets
            : min(100, restored.noOfBullets + 2),
        bulletRange: restored.bulletRange + 80,
        bulletSpeed: restored.bulletSpeed + 400,
        baseProjectileSpeed: restored.baseProjectileSpeed + 400,
      );
    }
    if (((snapshot['arsenalReviewBalance'] as num?)?.toInt() ?? 0) < 1) {
      final delta = weapon == WeaponType.beltRepeater
          ? 10
          : weapon == WeaponType.prismCutter
          ? 8
          : weapon == WeaponType.longwatchSniper
          ? 1
          : 0;
      if (delta > 0) {
        restored = restored.copyWith(
          maxBullets: min(100, restored.maxBullets + delta),
          noOfBullets: restored.reloading
              ? restored.noOfBullets
              : min(100, restored.noOfBullets + delta),
        );
      }
      if (weapon == WeaponType.longwatchSniper) {
        restored = restored.copyWith(
          bulletRange: restored.bulletRange + 1070,
          bulletSpeed: restored.bulletSpeed + 1300,
          baseProjectileSpeed: 1900,
        );
      }
    }
    if (((snapshot['arsenalReviewBalance'] as num?)?.toInt() ?? 0) < 2 &&
        weapon == WeaponType.beltRepeater) {
      restored = restored.copyWith(
        maxBullets: min(128, restored.maxBullets + 30),
        noOfBullets: restored.reloading
            ? restored.noOfBullets
            : min(128, restored.noOfBullets + 30),
      );
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
      _nextReloadSoundMs,
    ].every((value) => value.isFinite && value >= 0)) {
      throw const FormatException('Invalid run clocks');
    }
    _offerRandom.state = snapshot['offerRandom'] as int? ?? 1;
    _guardElapsed = (snapshot['guardElapsed'] as num?)?.toDouble() ?? 0;
    _choiceGrace = ((snapshot['choiceGrace'] as num?)?.toDouble() ?? 0).clamp(
      0,
      4,
    );
    if (snapshot['xpCurve'] != 3) {
      final fraction = restored.xP / restored.noOfCoinsToUpgrade;
      final cost = XPProgression.cost(restored.currentLevel);
      restored = restored.copyWith(
        noOfCoinsToUpgrade: cost.toDouble(),
        xP: (fraction * cost).floor(),
      );
    }
    // Read the previous staged-reload experiment, but always finish the full
    // reload. Never resume its short interruption/closing path after Continue.
    final oldPlan = snapshot['reloadPlan'] as Map?;
    if (restored.reloading && oldPlan != null) {
      final start = oldPlan['startAmmo'] as int;
      final missing = oldPlan['missing'] as int;
      final loaded = oldPlan['loaded'] as int;
      if (start < 0 ||
          missing <= 0 ||
          loaded < 0 ||
          loaded > missing ||
          start + missing != restored.maxBullets ||
          start + loaded != restored.noOfBullets ||
          _reloadDurationMs <= 0) {
        throw const FormatException('Invalid legacy reload plan');
      }
      if (weapon != WeaponType.carbine) {
        restored = restored.copyWith(noOfBullets: start);
        if (oldPlan['tactical'] == true) {
          _reloadDurationMs /= .85;
          _reloadElapsedMs /= .85;
          _nextReloadSoundMs /= .85;
        }
      }
    }
    // Preserve completion and already-consumed cues when continuing a run
    // recorded before the faster base shotgun reload. Arc migration is separate.
    if (weapon == WeaponType.shotgun &&
        snapshot['shotgunReloadBalance'] != 1 &&
        restored.reloading &&
        _reloadDurationMs > 0) {
      final missing = restored.maxBullets - restored.noOfBullets;
      final normal = reloadDurationFor(
        min(missing, weaponPower.capacity(weapon)),
      );
      if (normal > 0) {
        final progress = (_reloadElapsedMs / _reloadDurationMs).clamp(0.0, 1.0);
        final duration = restored.fastReload
            ? min(restored.fastReloadTime, normal)
            : normal;
        _reloadDurationMs = duration.toDouble();
        _reloadElapsedMs = progress * _reloadDurationMs;
        _nextReloadSoundMs *= ShotgunReload.shellIntervalMs / 700;
      }
    }
    _reloadTactical =
        weapon.supportsTacticalReload &&
        (snapshot['reloadTactical'] == true &&
            (oldPlan == null || weapon == WeaponType.carbine));
    final policy = snapshot['offerPolicy'] ?? 0;
    final history = snapshot['recentOffers'] ?? <String>[];
    if (policy is! int ||
        ![0, UpgradeOfferPolicy.version].contains(policy) ||
        history is! List ||
        history.length > 3 ||
        history.toSet().length != history.length ||
        history.any(
          (id) => id is! String || !PowerUp.values.any((p) => p.name == id),
        )) {
      throw const FormatException('Invalid upgrade offer policy');
    }
    _offerPolicy = policy;
    _recentOffers = List<String>.from(history);
    buildBalance = snapshot['buildBalance'] as int? ?? 1;
    weaponPower = restoredPower;
    if (snapshot['survivorRuntime'] case final Map raw) {
      survivor.restore(Map<String, dynamic>.from(raw));
    }
    supplyOffer =
        snapshot['supplyOffer'] == true && restored.powerUpChoices.isNotEmpty;
    _reloadCue = snapshot['reloadCue'] as int? ?? 0;
    reloadProgress.value = _reloadDurationMs > 0
        ? (_reloadElapsedMs / _reloadDurationMs).clamp(0, 1)
        : 0;
    _hurtCooldownMs = 1000; // Clear, fair resume window; no offline simulation.
    state = restored.copyWith(
      upgradeStrengths: restoredPower.upgradeStrengths,
      rankCurves: restoredPower.rankCurves,
      gameplayState: restored.health == 0
          ? GameplayState.gameOver
          : GameplayState.paused,
      triggerSprintInvincibility: false,
    );
  }

  /// Faster base shell reload; larger magazines still use the five-shell cap.
  static int reloadDurationFor(int missingShells) =>
      ShotgunReload.durationFor(missingShells);

  void reloadBullets({bool manual = false, bool allowFull = false}) {
    if (state.gameplayState != GameplayState.playing ||
        state.reloading ||
        (!allowFull && state.noOfBullets >= state.maxBullets)) {
      return;
    }
    final missing = state.maxBullets - state.noOfBullets;
    _quickRefillMs = -1;
    quickRefillProgress.value = -1;
    _reloadElapsedMs = 0;
    _reloadCue = 0;
    _reloadTactical =
        manual && weapon.supportsTacticalReload && state.noOfBullets > 0;
    final normal = weapon == WeaponType.shotgun
        ? weaponPower.shellDuration(min(missing, 5))
        : weaponPower.reloadMs(weapon);
    _reloadDurationMs = weapon == WeaponType.shotgun
        ? (state.fastReload ? min(state.fastReloadTime, normal) : normal)
              .toDouble()
        : (normal *
                  pow(
                    0.8,
                    max(
                      state.effectRank(PowerUp.fastReload),
                      state.fastReload
                          ? (2500 - state.fastReloadTime) ~/ 500
                          : 0,
                    ),
                  ))
              .toDouble();
    if (character == CharacterType.flint) {
      _reloadDurationMs = max(
        weapon == WeaponType.shotgun ? min(850, normal).toDouble() : 0,
        _reloadDurationMs * .88,
      );
    }
    if (_reloadTactical) _reloadDurationMs *= .70;
    _reloadSoundsLeft = weapon == WeaponType.shotgun && !state.fastReload
        ? missing - 1
        : 0;
    reloadProgress.value = 0;
    _nextReloadSoundMs =
        weaponPower.shellInterval() * (_reloadTactical ? .70 : 1.0);
    state = state.copyWith(reloading: true);
    ref
        .read(soloudPlayProvider)
        .play(
          weapon == WeaponType.shotgun
              ? 'reload_shotgun_shell.wav'
              : 'reload_${weapon.name}_0.wav',
        );
  }

  void fastReloadBullets() => reloadBullets();

  /// Called only by the game simulation: engine pause also freezes these clocks.
  void advanceTime(double dt) {
    if (state.gameplayState != GameplayState.playing || dt <= 0) return;
    survivor.advance(dt);
    if (character == CharacterType.suture &&
        survivor.triageReady &&
        state.health > 0 &&
        state.health < state.maxHealth) {
      survivor.triage = 0;
      survivor.healGate = 12;
      heal();
    }
    _choiceGrace = max(0, _choiceGrace - dt);
    if (_quickRefillMs >= 0) {
      _quickRefillMs += dt * 1000;
      quickRefillProgress.value = (_quickRefillMs / 320).clamp(0, 1);
      if (_quickRefillMs >= 320) {
        _quickRefillMs = -1;
        quickRefillProgress.value = -1;
      }
    }
    _activeSeconds += dt;
    if (_activeSeconds.floor() != state.survivalSeconds) {
      state = state.copyWith(
        survivalSeconds: _activeSeconds.floor(),
        score:
            state.score + (_activeSeconds.floor() - state.survivalSeconds) * 2,
      );
    }
    if (!state.guard &&
        (state.rank(PowerUp.scrapArmour) > 0 ||
            character == CharacterType.warden)) {
      _guardElapsed += dt;
      if (_guardElapsed >=
          max(6.5, 20 - state.effectRank(PowerUp.scrapArmour) * 3)) {
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
    if (_reloadTactical && weapon != WeaponType.shotgun) {
      if (_reloadCue == 0 && reloadProgress.value >= .82) {
        _reloadCue = 2; // Chambered round: seat magazine, skip the bolt.
        ref.read(soloudPlayProvider).play('reload_${weapon.name}_1.wav');
      }
    } else if (weapon != WeaponType.shotgun) {
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
      _nextReloadSoundMs +=
          weaponPower.shellInterval() * (_reloadTactical ? .70 : 1.0);
    }
    if (weapon == WeaponType.shotgun &&
        !_reloadTactical &&
        _reloadCue == 0 &&
        _reloadElapsedMs >= _reloadDurationMs - 180) {
      _reloadCue = 1;
      ref.read(soloudPlayProvider).play('reload_shotgun_pump.wav');
    }
    if (_reloadElapsedMs + 0.000001 >= _reloadDurationMs) {
      _reloadDurationMs = 0;
      _reloadSoundsLeft = 0;
      if (state.noOfBullets < state.maxBullets) {
        survivor.completedReload(character);
      }
      state = state.copyWith(noOfBullets: state.maxBullets, reloading: false);
    }
  }

  void decreaseBullets() {
    if (state.noOfBullets <= 0 ||
        state.reloading ||
        state.gameplayState != GameplayState.playing) {
      return;
    }
    _quickRefillMs = -1;
    quickRefillProgress.value = -1;
    state = state.copyWith(noOfBullets: state.noOfBullets - 1);
  }

  void restorePrimaryUnits(int amount) {
    if (amount <= 0 ||
        state.reloading ||
        state.gameplayState != GameplayState.playing) {
      return;
    }
    state = state.copyWith(
      noOfBullets: min(state.maxBullets, state.noOfBullets + amount),
    );
  }

  void addBullets() {
    _reloadDurationMs = 0;
    _reloadSoundsLeft = 0;
    state = state.copyWith(noOfBullets: 5, maxBullets: 5, reloading: false);
  }

  /// One damage path for contact, melee and projectiles; simultaneous overlaps
  /// cannot consume all health in a single frame.
  bool reduceHealth({
    int amount = 1,
    String cause = 'The horde',
    bool trainingRespawn = false,
  }) {
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
    noOfCoinsToUpgrade: 8,
    powerUpChoices: const [],
  );

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
    if (_choiceGrace <= 0 && state.xP >= state.noOfCoinsToUpgrade.floor()) {
      upgradeLevel();
    }
  }

  void resetXP() => state = state.copyWith(xP: 0);

  List<PowerUp> _rollOffers() {
    final pool = eligiblePowerUps(
      state,
      weapon: weapon,
      character: character,
      power: weaponPower,
    );
    if (_offerPolicy == UpgradeOfferPolicy.version) {
      final selected = UpgradeOfferPolicy.choose(
        eligible: pool.map((p) => p.name).toList(),
        ranks: {for (final p in pool) p.name: state.rank(p)},
        special: pool
            .where((p) => p.group == UpgradeGroup.special)
            .map((p) => p.name)
            .toSet(),
        luck: state.effectRank(PowerUp.luckyFind),
        recent: _recentOffers,
        random: _offerRandom.nextDouble,
      );
      _recentOffers = selected;
      return selected.map(PowerUp.values.byName).toList();
    }
    final choices = <PowerUp>[];
    while (choices.length < 3 && pool.isNotEmpty) {
      double weight(PowerUp p) =>
          (p.group == UpgradeGroup.special
              ? 1 + state.effectRank(PowerUp.luckyFind) * 0.35
              : 1) *
          (state.rank(p) > 0 ? 1.5 : 1);
      final candidates =
          choices.isEmpty &&
              buildBalance >= 2 &&
              pool.any((p) => state.rank(p) > 0)
          ? pool.where((p) => state.rank(p) > 0).toList()
          : pool;
      final total = candidates.fold<double>(0, (sum, p) => sum + weight(p));
      var pick = _offerRandom.nextDouble() * total;
      var index = candidates.length - 1;
      for (var i = 0; i < candidates.length; i++) {
        pick -= weight(candidates[i]);
        if (pick <= 0) {
          index = i;
          break;
        }
      }
      final chosen = candidates[index];
      choices.add(chosen);
      pool.remove(chosen);
    }
    return choices;
  }

  void upgradeLevel() {
    if (state.gameplayState != GameplayState.playing ||
        _choiceGrace > 0 ||
        state.xP < state.noOfCoinsToUpgrade.floor()) {
      return;
    }
    supplyOffer = false;
    final choices = _rollOffers();
    state = state.copyWith(
      xP: max(0, state.xP - state.noOfCoinsToUpgrade.floor()),
      currentLevel: state.currentLevel + 1,
      offerId: state.offerId + 1,
      noOfCoinsToUpgrade: XPProgression.cost(state.currentLevel + 1).toDouble(),
      gameplayState: GameplayState.powerup,
      powerUpChoices: List.unmodifiable(choices.take(3)),
    );
  }

  /// Earned by holding a supply field, rather than funded by XP. The same
  /// rank/bans/unique-choice rules and prompt grace still apply.
  bool offerSupplyUpgrade() {
    if (state.gameplayState != GameplayState.playing || _choiceGrace > 0) {
      return false;
    }
    supplyOffer = true;
    state = state.copyWith(
      offerId: state.offerId + 1,
      gameplayState: GameplayState.powerup,
      powerUpChoices: List.unmodifiable(_rollOffers()),
      evolutionChoices: const [],
    );
    return true;
  }

  void applyPowerUp(PowerUp powerUp, {int? offerId}) {
    if ((offerId != null && offerId != state.offerId) ||
        (powerUp != PowerUp.salvage &&
            state.rank(powerUp) >= state.rankLimit(powerUp)) ||
        state.gameplayState != GameplayState.powerup ||
        !state.powerUpChoices.contains(powerUp)) {
      return;
    }
    if (powerUp != PowerUp.salvage &&
        state.rankCurves['ranks.meta.policy'] == 1 &&
        !usefulPowerUpRank(state, powerUp, weapon, character, weaponPower)) {
      return;
    }
    if (powerUp != PowerUp.salvage) {
      state = state.copyWith(
        ranks: Map.unmodifiable({
          ...state.ranks,
          powerUp: state.rank(powerUp) + 1,
        }),
      );
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
        state = state.copyWith(
          shotDamage: state.shotDamage + state.gain(powerUp, .35, .1),
        );
      case PowerUp.lastShell:
        state = state.copyWith(lastShellRank: state.lastShellRank + 1);
      case PowerUp.breachLoader:
        state = state.copyWith(breachRank: state.breachRank + 1);
      case PowerUp.scrapArmour:
        state = state.copyWith(guard: true);
      case PowerUp.salvage:
        state = state.copyWith(
          scrap: state.scrap + 5,
          health: max(state.health, min(state.maxHealth, state.health + 1)),
        );
      default:
        break;
    }
    state = state.copyWith(
      gameplayState: GameplayState.playing,
      powerUpChoices: const [],
      evolutionChoices: const [],
    );
    supplyOffer = false;
    _choiceGrace = 4;
    upgradeConfirmed.value++;
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
      powerUpChoices: List.unmodifiable(pool.take(3)),
    );
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
      banned: Set.unmodifiable({...state.banned, powerUp}),
    );
    final pool = _rollOffers();
    state = state.copyWith(
      offerId: state.offerId + 1,
      powerUpChoices: List.unmodifiable(pool.take(3)),
    );
  }

  void awardBossCore() {
    // Two fusion slots need at most two banked cores. Surplus bosses still
    // reward scrap without creating another upgrade interruption.
    state = state.pendingCores >= 2 || state.evolutions.length >= 2
        ? state.copyWith(scrap: state.scrap + 5)
        : state.copyWith(pendingCores: state.pendingCores + 1);
  }

  bool get canFuse =>
      state.pendingCores > 0 &&
      fusionRecipes.any((recipe) => recipe.available(state, weapon: weapon));

  void openBossCore() {
    if (!canFuse ||
        (state.gameplayState != GameplayState.playing &&
            state.gameplayState != GameplayState.paused)) {
      return;
    }
    final recipes = fusionRecipes
        .where((r) => r.available(state, weapon: weapon))
        .map((r) => r.id)
        .toList();
    state = state.copyWith(
      pendingCores: max(0, state.pendingCores - 1),
      gameplayState: GameplayState.powerup,
      offerId: state.offerId + 1,
      evolutionChoices: List.unmodifiable(recipes),
      powerUpChoices: const [],
    );
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
      gameplayState: GameplayState.playing,
    );
    supplyOffer = false;
    _choiceGrace = 4;
    upgradeConfirmed.value++;
  }

  void prepareTrainingFusion(FusionRecipe recipe) {
    final ranks = {...state.ranks, recipe.first: 3, recipe.second: 2};
    state = state.copyWith(
      ranks: Map.unmodifiable(ranks),
      lastShellRank: ranks[PowerUp.lastShell] ?? 0,
      breachRank: ranks[PowerUp.breachLoader] ?? 0,
      evolutions: const {},
      pendingCores: 1,
      gameplayState: GameplayState.playing,
    );
    openBossCore();
  }

  void heal([int amount = 1]) {
    if (state.health <= 0 || state.health >= state.maxHealth || amount <= 0) {
      return;
    }
    final health = min(state.maxHealth, state.health + amount);
    survivor.healed += health - state.health;
    state = state.copyWith(health: health);
  }

  /// Boss recovery is temporary extra health, not an increase to base max HP.
  void awardBossHealth() {
    if (state.health <= 0) return;
    survivor.healed += 2;
    state = state.copyWith(health: state.health + 2);
  }

  void refillPractice() {
    _reloadDurationMs = 0;
    _reloadSoundsLeft = 0;
    _reloadElapsedMs = 0;
    reloadProgress.value = 0;
    _hurtCooldownMs = 1000;
    state = state.copyWith(
      health: state.maxHealth,
      noOfBullets: state.maxBullets,
      reloading: false,
    );
  }

  void grantResumeGrace({int milliseconds = 1000}) =>
      _hurtCooldownMs = milliseconds.toDouble();

  void prepareSoloRevive() {
    refillPractice();
    _hurtCooldownMs = 2000;
    state = state.copyWith(
      health: (state.maxHealth / 2).ceil(),
      causeOfDeath: '',
      gameplayState: GameplayState.paused,
    );
  }

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
            : GameplayState.playing,
      );
    }
  }

  void powerupState() => upgradeLevel();
  void gameOver() =>
      state = state.copyWith(health: 0, gameplayState: GameplayState.gameOver);

  void maxBulletsIncrease() {
    _reloadDurationMs = 0;
    _reloadSoundsLeft = 0;
    final capacity = min(
      weapon == WeaponType.beltRepeater ? 128 : 100,
      state.maxBullets +
          state.integerGain(
            PowerUp.maxBulletsIncrease,
            weapon == WeaponType.carbine ? 6 : 2,
            weapon == WeaponType.carbine ? 2 : 1,
          ),
    );
    _quickRefillMs = 0;
    quickRefillProgress.value = 0;
    reloadProgress.value = 0;
    ref
        .read(soloudPlayProvider)
        .play(
          weapon == WeaponType.shotgun
              ? 'reload_shotgun_pump.wav'
              : 'reload_${weapon.name}_2.wav',
        );
    final boundedCapacity = weapon == WeaponType.prismCutter
        ? min(24, capacity)
        : capacity;
    state = state.copyWith(
      maxBullets: boundedCapacity,
      noOfBullets: boundedCapacity,
      reloading: false,
    );
  }

  void healthIncrease() => state = state.copyWith(
    health: state.health + state.strength(PowerUp.healthIncrease).round(),
    maxHealth: state.maxHealth + state.strength(PowerUp.healthIncrease).round(),
  );
  void resetHealth() => state = state.copyWith(health: state.maxHealth);
  void walkingSpeedIncrease() => state = state.copyWith(
    movementSpeed:
        state.movementSpeed + state.gain(PowerUp.walkingSpeedIncrease, 50, 12),
  );
  void resetWalkingSpeed() =>
      state = state.copyWith(movementSpeed: weaponPower.movement(character));
  void sprintDistanceIncrease() =>
      state = state.copyWith(sprintTimeDistance: state.sprintTimeDistance + 15);
  void resetSprintTimeDistance() =>
      state = state.copyWith(sprintTimeDistance: 150);
  void bulletRangeIncrease() => state = state.copyWith(
    bulletRange:
        state.bulletRange +
        state.integerGain(PowerUp.bulletRangeIncrease, 60, 24),
  );
  void resetBulletRange() => state = state.copyWith(bulletRange: 420);
  void numberOfBulletsPerShotIncrease() => state = state.copyWith(
    bulletNumberRange:
        1 + min(3, state.countRank(PowerUp.numberOfBulletsPerShotIncrease)),
  );
  void resetBulletNumberRange() => state = state.copyWith(bulletNumberRange: 1);
  void fastReload() => state = state.copyWith(
    fastReload: true,
    fastReloadTime: max(
      850,
      state.fastReloadTime - state.integerGain(PowerUp.fastReload, 500, 30),
    ),
  );
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
        ? state.sprintTimeDistance +
              (70 +
                      max(0, state.rank(PowerUp.sprintInvincibility) - 1) *
                          15.0) *
                  state.strength(PowerUp.sprintInvincibility)
        : state.sprintTimeDistance.toDouble();
    state = state.copyWith(triggerSprintInvincibility: true);
  }

  void removeSprintInvincibilityTrigger() =>
      state = state.copyWith(triggerSprintInvincibility: false);
  void triggerBulletsPhaseThrough() =>
      state = state.copyWith(bulletsPhaseThrough: true);
  void resetBulletsPhaseThrough() =>
      state = state.copyWith(bulletsPhaseThrough: false);
  void rapidFire() => state = state.copyWith(
    bulletSpeed: min(
      min(weapon.velocityCeiling.toDouble(), state.baseProjectileSpeed + 800),
      state.bulletSpeed + state.integerGain(PowerUp.rapidFire, 200, 40),
    ),
  );
  void resetFireRate() => state = state.copyWith(bulletSpeed: 700);
  void sprintMine() => state = state.copyWith(triggerSprintMine: true);
  void removeSprintMine() => state = state.copyWith(triggerSprintMine: false);
  void decreaseSprintMineCount() => state = state.copyWith(
    sprintMineCount: max(0, state.sprintMineCount - 1),
  );
  void increaseSprintMineCount() => state = state.copyWith(
    sprintMineCount: min(3, state.sprintMineCount + 1),
  );
  void resetSprintMineCount() => state = state.copyWith(sprintMineCount: 3);
}

class GameState {
  final Map<String, num> upgradeStrengths;
  final Map<String, num> rankCurves;
  double rankTotal(PowerUp p, int n, double early, double tail) =>
      RankCurve.total(n, p.name, early, tail, rankCurves) * strength(p);
  double gain(PowerUp p, double early, double tail) =>
      rankTotal(p, rank(p), early, tail) -
      rankTotal(p, max(0, rank(p) - 1), early, tail);
  double effectAt(PowerUp p, int n) => rankTotal(
    p,
    n,
    1,
    (p == PowerUp.fastReload || p == PowerUp.quickstep) ? .2 : .3,
  );
  Map<String, num> effectInputs(
    WeaponType w,
    CharacterType c,
    WeaponPowerBalance power,
  ) => {
    ...?power.snapshot?.values,
    ...rankCurves,
    for (final p in PowerUp.values)
      'powerups.${p.name}.${p == PowerUp.dashCapacity || p == PowerUp.grenadeCapacity ? 'capacity' : 'strength'}':
          p == PowerUp.dashCapacity
          ? 1 + rankLimit(p)
          : p == PowerUp.grenadeCapacity
          ? 2 + rankLimit(p)
          : strength(p),
    'weapons.${w.name}.capacity': power.capacity(w),
    'weapons.${w.name}.damage': power.damage(w),
    'weapons.${w.name}.cadence': power.cadence(w),
    'weapons.${w.name}.reloadMs': power.reloadMs(w),
    'weapons.${w.name}.range': power.range(w),
    'weapons.${w.name}.speed': power.speed(w),
    'weapons.${w.name}.ricochets': power.ricochets(w),
    'survivors.${c.name}.health': power.health(c),
    'survivors.${c.name}.speed': power.movement(c),
  };
  Map<String, num> rankValues(
    PowerUp p,
    int n,
    WeaponType w,
    CharacterType c,
    WeaponPowerBalance power,
  ) => RankEffects.values(
    p.name,
    n,
    effectInputs(w, c, power),
    weapon: w.name,
    survivor: c.name,
    fusions: evolutions,
    railChargeMultiplier: power.railChargeMultiplier,
  );
  double strength(PowerUp value) =>
      (value == PowerUp.dashCapacity || value == PowerUp.grenadeCapacity)
      ? 1
      : (upgradeStrengths[value.name] ?? 1).toDouble();
  int countRank(PowerUp value) =>
      (rank(value) * strength(value)).round().clamp(0, 8);
  int integerGain(PowerUp value, int early, int late) {
    int total(int n) =>
        rankTotal(value, n, early.toDouble(), late.toDouble()).round();
    return total(rank(value)) - total(max(0, rank(value) - 1));
  }

  int rankLimit(PowerUp value) => switch (value) {
    PowerUp.dashCapacity =>
      (upgradeStrengths[value.name] ?? 3).toInt().clamp(2, 3) - 1,
    PowerUp.grenadeCapacity =>
      (upgradeStrengths[value.name] ?? 4).toInt().clamp(3, 4) - 2,
    _ => value.maxRank,
  };
  int get dashCapacity =>
      1 + rank(PowerUp.dashCapacity).clamp(0, rankLimit(PowerUp.dashCapacity));
  int get grenadeCapacity =>
      2 +
      rank(PowerUp.grenadeCapacity)
          .clamp(0, rankLimit(PowerUp.grenadeCapacity));

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

  /// Keep I–III intact; IV–VIII give smaller, bounded scalar gains.
  static double scaledRank(int rank, {double lateGain = .3}) =>
      min(rank, 3) + max(0, rank - 3) * lateGain;
  double effectRank(PowerUp value) => effectAt(value, rank(value));
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
    this.upgradeStrengths = const {},
    this.rankCurves = const {},
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
    this.noOfCoinsToUpgrade = 8,
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
    'rankCurves': rankCurves,
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
    rankCurves: Map<String, num>.from(json['rankCurves'] as Map? ?? {}),
    maxHealth: json['maxHealth'] as int? ?? 3,
    guard: json['guard'] as bool? ?? false,
    rerolls: json['rerolls'] as int? ?? 2,
    bans: json['bans'] as int? ?? 1,
    scrap: json['scrap'] as int? ?? 0,
    pendingCores: json['pendingCores'] as int? ?? 0,
    causeOfDeath: json['causeOfDeath'] as String? ?? '',
    ranks: Map.unmodifiable(
      (json['ranks'] as Map? ?? {}).map(
        (key, value) =>
            MapEntry(PowerUp.values.byName(key as String), value as int),
      ),
    ),
    banned: Set.unmodifiable(
      (json['banned'] as List? ?? []).map(
        (name) => PowerUp.values.byName(name as String),
      ),
    ),
    evolutions: Set.unmodifiable(
      (json['evolutions'] as List? ?? []).cast<String>(),
    ),
    evolutionChoices: List.unmodifiable(
      (json['evolutionChoices'] as List? ?? []).cast<String>(),
    ),
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
    powerUpChoices: List.unmodifiable(
      (json['powerUpChoices'] as List).map(
        (name) => PowerUp.values.byName(name as String),
      ),
    ),
    gameplayState: GameplayState.values.byName(json['gameplayState'] as String),
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
    Map<String, num>? upgradeStrengths,
    Map<String, num>? rankCurves,
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
      upgradeStrengths: upgradeStrengths ?? this.upgradeStrengths,
      rankCurves: rankCurves ?? this.rankCurves,
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

enum GameplayState { playing, paused, gameOver, powerup }

enum UpgradeGroup { core, utility, special, legacy, fallback }

enum PowerUp {
  heavyLoad(
    'Heavy Load',
    'More projectile damage. Diminishing gains.',
    UpgradeGroup.core,
  ),
  quickTrigger(
    'Quick Trigger',
    'Fire faster. Diminishing gains.',
    UpgradeGroup.core,
  ),
  maxBulletsIncrease(
    'Extended Tube',
    'Larger mag. Refill now. Same reload time.',
    UpgradeGroup.core,
  ),
  fastReload('Sleight of Hand', 'Reload faster.', UpgradeGroup.core),
  numberOfBulletsPerShotIncrease(
    'Scattershot',
    'More projectiles. Later ranks tighten spread.',
    UpgradeGroup.core,
  ),
  bulletsPhaseThrough(
    'Piercing Rounds',
    'Hit additional enemies.',
    UpgradeGroup.core,
  ),
  bulletRangeIncrease(
    'Long Barrel',
    'Increase effective range.',
    UpgradeGroup.core,
  ),
  rapidFire('High Velocity', 'Faster projectiles.', UpgradeGroup.core),
  walkingSpeedIncrease('Fleet Foot', 'Move faster.', UpgradeGroup.utility),
  healthIncrease(
    'Vitality',
    'Add a heart and recover one.',
    UpgradeGroup.utility,
  ),
  fieldMedic(
    'Field Medic',
    'Kills: 5–22.5% chance to restore a heart.',
    UpgradeGroup.utility,
  ),
  scrapArmour(
    'Scrap Armour',
    'Absorb a hit; guard recharges.',
    UpgradeGroup.utility,
  ),
  quickstep('Quickstep', 'Dash recharges faster.', UpgradeGroup.utility),
  dashCapacity(
    'Double Dash',
    'Store another dash. Up to three.',
    UpgradeGroup.utility,
  ),
  grenadeCapacity(
    'Grenade Reserve',
    'Carry another grenade. Up to four.',
    UpgradeGroup.utility,
  ),
  sprintInvincibility(
    'Afterimage',
    'Longer dash protection.',
    UpgradeGroup.utility,
  ),
  scavenger('Scavenger', 'Attract XP from farther away.', UpgradeGroup.utility),
  luckyFind(
    'Lucky Find',
    'Special upgrades appear more often.',
    UpgradeGroup.utility,
  ),
  hotShot('Hot Shot', 'Hits ignite enemies.', UpgradeGroup.special),
  accelerant(
    'Accelerant',
    'Burning kills ignite nearby enemies.',
    UpgradeGroup.special,
  ),
  staticCharge(
    'Static Charge',
    'Primary hits can arc to another enemy.',
    UpgradeGroup.special,
  ),
  conductiveCore(
    'Conductive Core',
    'Lightning chains farther and hits more targets.',
    UpgradeGroup.special,
  ),
  sprintMine('Dash Mine', 'Leave a mine after a dash.', UpgradeGroup.special),
  fragmentation(
    'Fragmentation',
    'Explosions emit a small shard burst.',
    UpgradeGroup.special,
  ),
  ricochet(
    'Ricochet',
    'Projectiles bounce to a new enemy.',
    UpgradeGroup.special,
  ),
  bankShot('Bank Shot', 'Bounced shots hit harder.', UpgradeGroup.special),
  lastShell(
    'Last Shell',
    'Stronger final shot. Diminishing gains.',
    UpgradeGroup.special,
  ),
  breachLoader(
    'Breach Loader',
    'Stronger first shot after reload.',
    UpgradeGroup.special,
  ),
  orbitDrone(
    'Orbit Drone',
    'A companion fires at nearby enemies.',
    UpgradeGroup.special,
  ),
  targetingLink(
    'Targeting Link',
    'Shots mark targets for drone focus.',
    UpgradeGroup.special,
  ),
  shrapnel(
    'Shrapnel',
    'Kills can release a close-range shard cone.',
    UpgradeGroup.special,
  ),
  executioner(
    'Executioner',
    'Deal more damage to wounded enemies.',
    UpgradeGroup.special,
  ),
  grenadeDamage(
    'Heavy Payload',
    'Grenades deal more damage.',
    UpgradeGroup.utility,
  ),
  grenadeRadius(
    'Wide Burst',
    'Grenades cover more ground.',
    UpgradeGroup.utility,
  ),
  grenadeRecharge(
    'Ordnance Cycle',
    'Grenades recharge faster.',
    UpgradeGroup.utility,
  ),
  braceLoader(
    'Brace Loader',
    'Move faster while reloading.',
    UpgradeGroup.utility,
  ),
  sureFoot(
    'Sure Foot',
    'Recover part of weapon weight mobility loss.',
    UpgradeGroup.utility,
  ),
  scouringHeat(
    'Scouring Heat',
    'Burns hurt elites and bosses more.',
    UpgradeGroup.special,
  ),
  faradayReserve(
    'Faraday Reserve',
    'Chains retain more damage per jump.',
    UpgradeGroup.special,
  ),
  blastHarness(
    'Blast Harness',
    'Grenades and mines push ordinary foes farther.',
    UpgradeGroup.utility,
  ),
  exposedSeam(
    'Exposed Seam',
    'Primary hits hurt frozen enemies more.',
    UpgradeGroup.special,
  ),
  measuredShot(
    'Measured Shot',
    'Wait briefly. Empower the next release.',
    UpgradeGroup.special,
  ),
  closeQuarters(
    'Close Quarters',
    'Primary hits hurt more at close range.',
    UpgradeGroup.special,
  ),
  sprintDistanceIncrease('Long Dash', 'Dash farther.', UpgradeGroup.legacy),
  salvage(
    'Scrap Cache',
    'Gain 5 scrap and recover a heart.',
    UpgradeGroup.fallback,
  );

  const PowerUp(this.title, this.description, this.group);
  final String title, description;
  final UpgradeGroup group;
  int get maxRank => switch (this) {
    PowerUp.salvage => 0,
    PowerUp.dashCapacity || PowerUp.grenadeCapacity => 2,
    _ => 8,
  };
}

final List<PowerUp> powerUps = List.unmodifiable(
  PowerUp.values.where(
    (p) => p.group != UpgradeGroup.legacy && p.group != UpgradeGroup.fallback,
  ),
);

bool weaponSupportsPowerUp(WeaponType weapon, PowerUp power) => switch (power) {
  PowerUp.numberOfBulletsPerShotIncrease => weapon.supportsScatter,
  PowerUp.bulletsPhaseThrough => weapon.supportsPierce,
  PowerUp.ricochet || PowerUp.bankShot => weapon.supportsRicochet,
  PowerUp.rapidFire => weapon.supportsVelocity,
  PowerUp.bulletRangeIncrease => weapon.supportsRange,
  PowerUp.lastShell || PowerUp.breachLoader => weapon.hasLastRound,
  PowerUp.hotShot ||
  PowerUp.accelerant ||
  PowerUp.staticCharge ||
  PowerUp.conductiveCore ||
  PowerUp.executioner => weapon.hasDirectHits,
  PowerUp.closeQuarters || PowerUp.exposedSeam => weapon.hasDirectHits,
  PowerUp.quickTrigger => weapon != WeaponType.prismCutter,
  _ => true,
};

bool usefulPowerUpRank(
  GameState state,
  PowerUp p,
  WeaponType weapon,
  CharacterType character,
  WeaponPowerBalance power,
) {
  return RankEffects.improves(
        state.rankValues(p, state.rank(p), weapon, character, power),
        state.rankValues(p, state.rank(p) + 1, weapon, character, power),
      ) ||
      fusionRecipes.any(
        (f) =>
            !state.fused(f.id) &&
            state.evolutions.length < 2 &&
            weaponSupportsPowerUp(weapon, f.first) &&
            weaponSupportsPowerUp(weapon, f.second) &&
            !state.banned.contains(f.first) &&
            !state.banned.contains(f.second) &&
            ((f.first == p && state.rank(p) < 3) ||
                (f.second == p && state.rank(p) < 2)),
      );
}

List<PowerUp> eligiblePowerUps(
  GameState state, {
  WeaponType weapon = WeaponType.shotgun,
  CharacterType character = CharacterType.rook,
  WeaponPowerBalance power = WeaponPowerBalance.current,
}) {
  final specialSlots = state.ranks.keys
      .where((p) => p.group == UpgradeGroup.special)
      .length;
  final eligible = powerUps.where((p) {
    if (!weaponSupportsPowerUp(weapon, p) &&
        !(p == PowerUp.accelerant && character == CharacterType.moth)) {
      return false;
    }
    final burn =
        state.rank(PowerUp.hotShot) > 0 ||
        character == CharacterType.moth ||
        weapon == WeaponType.cinderHose;
    final chain =
        state.rank(PowerUp.staticCharge) > 0 ||
        character == CharacterType.coil ||
        weapon == WeaponType.arcCaster;
    if ((p == PowerUp.accelerant || p == PowerUp.scouringHeat) && !burn) {
      return false;
    }
    if (p == PowerUp.conductiveCore &&
        state.rank(PowerUp.staticCharge) == 0 &&
        weapon != WeaponType.arcCaster) {
      return false;
    }
    if (p == PowerUp.faradayReserve && !chain) return false;
    if (p == PowerUp.bankShot &&
        state.rank(PowerUp.ricochet) == 0 &&
        power.ricochets(weapon) == 0) {
      return false;
    }
    if (p == PowerUp.targetingLink && state.rank(PowerUp.orbitDrone) == 0) {
      return false;
    }
    if (p == PowerUp.exposedSeam && weapon != WeaponType.frostShotgun) {
      return false;
    }
    if (p == PowerUp.sureFoot &&
        {
          WeaponType.shotgun,
          WeaponType.carbine,
          WeaponType.revolver,
          WeaponType.burstRifle,
        }.contains(weapon)) {
      return false;
    }
    if (p == PowerUp.rapidFire &&
        state.bulletSpeed >=
            min(
              weapon.velocityCeiling.toDouble(),
              state.baseProjectileSpeed + 800,
            )) {
      return false;
    }
    if (p == PowerUp.bulletRangeIncrease &&
        weapon.rangeCeiling != null &&
        state.bulletRange >= weapon.rangeCeiling!) {
      return false;
    }
    if (weapon == WeaponType.prismCutter &&
        p == PowerUp.maxBulletsIncrease &&
        state.maxBullets >= 24) {
      return false;
    }
    if (state.banned.contains(p) || state.rank(p) >= state.rankLimit(p)) {
      return false;
    }
    if (p.group == UpgradeGroup.special &&
        state.rank(p) == 0 &&
        specialSlots >= 6) {
      return false;
    }
    if (state.rankCurves['ranks.meta.policy'] == 1 &&
        !usefulPowerUpRank(state, p, weapon, character, power)) {
      return false;
    }
    return switch (p) {
      PowerUp.sprintInvincibility =>
        !state.sprintInvincibility || state.rank(p) > 0,
      PowerUp.bulletsPhaseThrough =>
        !state.bulletsPhaseThrough || state.rank(p) > 0,
      PowerUp.numberOfBulletsPerShotIncrease =>
        state.bulletNumberRange < 4 || state.rank(p) > 0,
      PowerUp.rapidFire =>
        state.bulletSpeed < state.baseProjectileSpeed + 600 ||
            state.rank(p) > 0,
      PowerUp.fastReload =>
        !state.fastReload || state.fastReloadTime > 1000 || state.rank(p) > 0,
      PowerUp.heavyLoad => state.shotDamage < 2.05 || state.rank(p) > 0,
      _ => true,
    };
  }).toList();
  if (eligible.length < 3) eligible.add(PowerUp.salvage);
  return eligible;
}

class FusionRecipe {
  const FusionRecipe(
    this.id,
    this.title,
    this.first,
    this.second,
    this.description,
  );
  final String id, title, description;
  final PowerUp first, second;
  bool available(GameState state, {WeaponType weapon = WeaponType.shotgun}) =>
      weaponSupportsPowerUp(weapon, first) &&
      weaponSupportsPowerUp(weapon, second) &&
      state.evolutions.length < 2 &&
      !state.fused(id) &&
      state.rank(first) >= 3 &&
      state.rank(second) >= 2;
}

const fusionRecipes = [
  FusionRecipe(
    'kilnPact',
    'Kiln Pact',
    PowerUp.hotShot,
    PowerUp.scouringHeat,
    'Burning elite and boss deaths leave fire.',
  ),
  FusionRecipe(
    'groundWire',
    'Ground Wire',
    PowerUp.staticCharge,
    PowerUp.faradayReserve,
    'Every fourth discharge gains a jump.',
  ),
  FusionRecipe(
    'firebreak',
    'Firebreak',
    PowerUp.hotShot,
    PowerUp.accelerant,
    'Ignitions leave burning ground.',
  ),
  FusionRecipe(
    'stormCircuit',
    'Storm Circuit',
    PowerUp.staticCharge,
    PowerUp.conductiveCore,
    'Lightning gains two more jumps.',
  ),
  FusionRecipe(
    'minefield',
    'Minefield',
    PowerUp.sprintMine,
    PowerUp.fragmentation,
    'Dashing leaves a mine trail.',
  ),
  FusionRecipe(
    'pinball',
    'Pinball',
    PowerUp.ricochet,
    PowerUp.bankShot,
    'Extra ricochets with stronger impacts.',
  ),
  FusionRecipe(
    'breachEngine',
    'Breach Engine',
    PowerUp.lastShell,
    PowerUp.breachLoader,
    'First and final releases hit harder.',
  ),
  FusionRecipe(
    'hunterSwarm',
    'Hunter Swarm',
    PowerUp.orbitDrone,
    PowerUp.targetingLink,
    'Three drones focus marked targets.',
  ),
];
