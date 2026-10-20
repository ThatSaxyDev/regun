import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/systems/xp_progression.dart';
import 'package:regun/utils/soloud_play.dart';

class SilentAudio extends SoloudPlay {
  int reloadSounds = 0;
  @override
  Future<void> play(String assetPath) async {
    if (assetPath == 'reload_shotgun_shell.wav') reloadSounds++;
  }
}

void main() {
  late ProviderContainer container;
  late GameNotifier notifier;
  late SilentAudio audio;
  GameState state() => container.read(gameNotifierProvider);
  setUp(() {
    audio = SilentAudio();
    container = ProviderContainer(
        overrides: [soloudPlayProvider.overrideWithValue(audio)]);
    notifier = container.read(gameNotifierProvider.notifier);
  });
  tearDown(() => container.dispose());

  void grant(PowerUp power) {
    final snapshot = notifier.checkpoint();
    snapshot['state'] = state()
        .copyWith(
            gameplayState: GameplayState.powerup,
            powerUpChoices: [power],
            evolutionChoices: const [],
            offerId: state().offerId + 1)
        .toJson();
    notifier.restoreCheckpoint(snapshot);
    notifier.playGame();
    notifier.applyPowerUp(power, offerId: state().offerId);
  }

  test(
      'every upgrade family remains selectable through eight ranks, then stops',
      () {
    for (final power in powerUps) {
      notifier.resetRun();
      for (var rank = 1; rank <= 8; rank++) {
        expect(eligiblePowerUps(state()), contains(power),
            reason: '${power.name} $rank');
        grant(power);
        expect(state().rank(power), rank);
      }
      expect(eligiblePowerUps(state()), isNot(contains(power)));
      grant(power); // A stale offered card must not grant rank nine.
      expect(state().rank(power), 8);
      final saved = notifier.checkpoint();
      notifier.restoreCheckpoint(saved);
      expect(state().rank(power), 8);
    }
  });

  test(
      'magazine pickup refills now, cancels reload, and its short cue freezes on pause',
      () {
    for (var i = 0; i < 5; i++) {
      notifier.decreaseBullets();
    }
    notifier.reloadBullets();
    grant(PowerUp.maxBulletsIncrease);
    expect(state().maxBullets, 7);
    expect(state().noOfBullets, 7);
    expect(state().reloading, isFalse);
    expect(notifier.quickRefillProgress.value, 0);
    notifier.advanceTime(.16);
    expect(notifier.quickRefillProgress.value, closeTo(.5, .001));
    notifier.pauseGame();
    notifier.advanceTime(20);
    expect(notifier.quickRefillProgress.value, closeTo(.5, .001));
    notifier.playGame();
    notifier.advanceTime(.16);
    expect(notifier.quickRefillProgress.value, -1);
    for (var i = 0; i < 7; i++) {
      notifier.decreaseBullets();
    }
    notifier.reloadBullets();
    notifier.advanceTime(3.699);
    expect(state().reloading, isTrue);
    notifier.advanceTime(.001);
    expect(state().noOfBullets, 7); // Bigger tube no longer adds 1.4 seconds.
    grant(PowerUp.maxBulletsIncrease);
    notifier
        .decreaseBullets(); // Firing can interrupt the cosmetic cue immediately.
    expect(notifier.quickRefillProgress.value, -1);
  });

  test('eight-rank reload and guard gains have safe rewarding bounds', () {
    for (final weapon in WeaponType.values) {
      notifier.resetRun(loadout: Loadout(weapon: weapon));
      for (var rank = 0; rank < 8; rank++) {
        grant(PowerUp.maxBulletsIncrease);
        grant(PowerUp.fastReload);
      }
      expect(state().fastReloadTime, 850);
      for (var i = state().noOfBullets; i > 0; i--) {
        notifier.decreaseBullets();
      }
      notifier.reloadBullets();
      final duration = notifier.checkpoint()['reloadDurationMs'] as double;
      expect(
          duration,
          greaterThanOrEqualTo(
              weapon == WeaponType.shotgun ? 850 : weapon.reloadMs * .4));
      notifier.advanceTime(duration / 1000);
      expect(state().noOfBullets, state().maxBullets);
    }
    notifier.resetRun();
    for (var i = 0; i < 8; i++) {
      grant(PowerUp.scrapArmour);
    }
    notifier.advanceTime(1);
    notifier.reduceHealth();
    notifier.advanceTime(6.499);
    expect(state().guard, isFalse);
    notifier.advanceTime(.001);
    expect(state().guard, isTrue);
    expect(state().effectRank(PowerUp.scrapArmour), 4.5);
  });

  test(
      'older Arc Caster runs receive the new base once without losing upgrades',
      () {
    notifier.resetRun(loadout: const Loadout(weapon: WeaponType.arcCaster));
    final old = notifier.checkpoint()..remove('weaponBalance');
    old['state'] = state()
        .copyWith(
            maxBullets: 8,
            noOfBullets: 3,
            bulletRange: 600,
            baseProjectileSpeed: 650,
            bulletSpeed: 850)
        .toJson();
    notifier.restoreCheckpoint(old);
    expect(state().maxBullets, 10);
    expect(state().noOfBullets, 5);
    expect(state().bulletRange, 680);
    expect(state().bulletSpeed, 1250);
    final upgraded = notifier.checkpoint();
    notifier.restoreCheckpoint(upgraded);
    expect(state().maxBullets, 10);
    expect(state().noOfBullets, 5);
  });

  for (var missing = 1; missing <= 5; missing++) {
    test(
        'preserves shotgun timing and shell sounds for $missing missing shells',
        () {
      for (var i = 0; i < missing; i++) {
        notifier.decreaseBullets();
      }
      notifier.reloadBullets();
      final duration = 900 + 700 * (missing - 1);
      // Duplicate requests do not restart the reload or play extra sounds.
      notifier.reloadBullets();
      notifier.advanceTime((duration - 1) / 1000);
      expect(state().reloading, isTrue);
      expect(state().noOfBullets, 5 - missing);
      expect(audio.reloadSounds, missing);
      notifier.advanceTime(0.001);
      expect(state().reloading, isFalse);
      expect(state().noOfBullets, 5);
    });
  }

  test('reload and shell sounds freeze while paused', () {
    for (var i = 0; i < 5; i++) {
      notifier.decreaseBullets();
    }
    notifier.reloadBullets();
    notifier.advanceTime(0.7);
    expect(audio.reloadSounds, 2);
    notifier.pauseGame();
    notifier.advanceTime(60);
    expect(state().reloading, isTrue);
    expect(audio.reloadSounds, 2);
    notifier.playGame();
    notifier.advanceTime(3);
    expect(state().reloading, isFalse);
    expect(audio.reloadSounds, 5);
  });

  test('restart discards an old reload, invulnerability and upgrades', () {
    notifier.fastReload();
    notifier.sprintInvincibility();
    notifier.triggerSprintInvincibility();
    notifier.decreaseBullets();
    notifier.reloadBullets();
    notifier.resetRun();
    notifier.decreaseBullets();
    notifier.advanceTime(60);
    expect(state().noOfBullets, 4);
    expect(state().reloading, isFalse);
    expect(state().fastReload, isFalse);
    expect(state().triggerSprintInvincibility, isFalse);
  });

  test('ammo never becomes negative or decreases during reload', () {
    for (var i = 0; i < 9; i++) {
      notifier.decreaseBullets();
    }
    expect(state().noOfBullets, 0);
    notifier.reloadBullets();
    notifier.decreaseBullets();
    expect(state().noOfBullets, 0);
  });

  test('XP upgrades at exactly eight pickups and freezes one choice set', () {
    for (var i = 0; i < 8; i++) {
      notifier.increaseXP();
    }
    expect(state().currentLevel, 2);
    expect(state().gameplayState, GameplayState.powerup);
    final choices = state().powerUpChoices;
    expect(choices.toSet().length, 3);
    for (var i = 0; i < 10; i++) {
      notifier.increaseXP();
    }
    notifier.advanceTime(30);
    expect(identical(state().powerUpChoices, choices), isTrue);
    expect(state().currentLevel, 2);
    notifier.applyPowerUp(choices.first);
    expect(state().gameplayState, GameplayState.playing);
    expect(state().powerUpChoices, isEmpty);
    // A second queued tap from the old overlay cannot apply another upgrade.
    final applied = state();
    notifier.applyPowerUp(choices.last);
    expect(identical(state(), applied), isTrue);
  });

  test('damage is guarded, respects invulnerability and ends the run once', () {
    expect(notifier.reduceHealth(), isTrue);
    expect(notifier.reduceHealth(), isFalse);
    expect(state().health, 5);
    notifier.advanceTime(0.5);
    notifier.sprintInvincibility();
    notifier.triggerSprintInvincibility();
    expect(notifier.reduceHealth(), isFalse);
    notifier.advanceTime(0.151);
    expect(notifier.reduceHealth(), isTrue);
    expect(state().health, 4);
    for (var hit = 0; hit < 4; hit++) {
      notifier.advanceTime(0.5);
      expect(notifier.reduceHealth(), isTrue);
    }
    expect(state().health, 0);
    expect(state().gameplayState, GameplayState.gameOver);
    notifier.advanceTime(30);
    expect(notifier.reduceHealth(), isFalse);
    expect(state().health, 0);
  });

  test('XP has accelerating costs and no automatic back-to-back choices', () {
    expect([for (var level = 1; level <= 6; level++) XPProgression.cost(level)],
        [8, 18, 35, 59, 90, 128]);
    notifier.increaseXP(130);
    expect(state().xP, 122);
    final offerId = state().offerId;
    final choice = state().powerUpChoices.first;
    notifier.applyPowerUp(choice, offerId: offerId);
    expect(state().gameplayState, GameplayState.playing);
    expect(state().xP, 122);
    expect(state().currentLevel, 2);
    final next = state();
    notifier.applyPowerUp(choice, offerId: offerId);
    expect(identical(next, state()), isTrue);
    notifier.increaseXP();
    expect(state().gameplayState, GameplayState.playing);
    notifier.pauseGame();
    notifier.advanceTime(100);
    notifier.playGame();
    notifier.advanceTime(4);
    expect(state().gameplayState, GameplayState.playing);
    notifier.increaseXP();
    expect(state().gameplayState, GameplayState.powerup);
    expect(state().currentLevel, 3);
    expect(state().xP, 106);
  });

  test('boss rewards never give unfunded ordinary upgrades; fusion is explicit',
      () {
    notifier.awardBossCore();
    expect(state().xP, 0);
    expect(state().currentLevel, 1);
    expect(state().gameplayState, GameplayState.playing);
    expect(state().pendingCores, 1);
    notifier.awardBossCore();
    notifier.awardBossCore();
    expect(state().pendingCores, 2);
    expect(state().scrap, 5);
    notifier.openBossCore();
    expect(state().gameplayState, GameplayState.playing);
    expect(state().pendingCores, 2);
    final recipe = fusionRecipes.first;
    for (var i = 0; i < 3; i++) {
      grant(recipe.first);
    }
    for (var i = 0; i < 2; i++) {
      grant(recipe.second);
    }
    expect(notifier.canFuse, isTrue);
    expect(state().gameplayState, GameplayState.playing);
    notifier.openBossCore();
    expect(state().powerUpChoices, isEmpty);
    expect(state().evolutionChoices, contains(recipe.id));
    notifier.fuse(recipe.id, offerId: state().offerId);
    expect(state().gameplayState, GameplayState.playing);
    expect(state().pendingCores, 1);
  });

  test('old saves retain XP-bar progress under the new curve once', () {
    final old = notifier.checkpoint()..remove('xpCurve');
    old['state'] = state()
        .copyWith(currentLevel: 3, noOfCoinsToUpgrade: 10, xP: 5)
        .toJson();
    notifier.restoreCheckpoint(old);
    expect(state().noOfCoinsToUpgrade, 35);
    expect(state().xP, 17);
    notifier.restoreCheckpoint(notifier.checkpoint());
    expect(state().xP, 17);
  });

  for (var rank = 1; rank <= 3; rank++) {
    test('Scrap Armour rank $rank blocks a heavy hit and recharges in play',
        () {
      final checkpoint = notifier.checkpoint();
      checkpoint['state'] = state().copyWith(
          ranks: {if (rank > 1) PowerUp.scrapArmour: rank - 1},
          powerUpChoices: [PowerUp.scrapArmour]).toJson();
      notifier.restoreCheckpoint(checkpoint);
      notifier.playGame();
      notifier.applyPowerUp(PowerUp.scrapArmour);
      expect(state().rank(PowerUp.scrapArmour), rank);
      expect(state().guard, isTrue);
      notifier.advanceTime(1); // Expire the checkpoint's resume protection.
      final health = state().health;
      expect(notifier.reduceHealth(amount: 2, cause: 'Demon cleave'), isTrue);
      expect(state().health, health);
      expect(state().guard, isFalse);
      expect(notifier.reduceHealth(), isFalse);
      notifier.advanceTime(.499);
      expect(notifier.reduceHealth(), isFalse);
      notifier.advanceTime(.001);
      expect(notifier.reduceHealth(), isTrue);
      expect(state().health, health - 1);
      notifier.pauseGame();
      notifier.advanceTime(100);
      expect(state().guard, isFalse);
      notifier.playGame();
      notifier.advanceTime(20 - rank * 3 - .501);
      expect(state().guard, isFalse);
      notifier.advanceTime(.001);
      expect(state().guard, isTrue);
      expect(notifier.reduceHealth(amount: 2), isTrue);
      expect(state().health, health - 1);
      expect(state().guard, isFalse);
    });
  }

  test('fast reload never slows down a partial shotgun reload', () {
    notifier.fastReload();
    notifier.decreaseBullets();
    notifier.reloadBullets();
    notifier.advanceTime(0.9);
    expect(state().reloading, isFalse);
  });

  test('run time and kill records freeze during selection and reset together',
      () {
    notifier.advanceTime(12.2);
    notifier.recordKill(score: 25);
    notifier.recordKill(score: 1000, boss: true);
    expect(state().survivalSeconds, 12);
    expect(state().kills, 2);
    expect(state().bosses, 1);
    expect(state().score, 1049);
    notifier.increaseXP(8);
    notifier.advanceTime(100);
    notifier.recordKill();
    expect(state().survivalSeconds, 12);
    expect(state().kills, 2);
    notifier.resetRun();
    expect(state().kills, 0);
    expect(state().bosses, 0);
    expect(state().survivalSeconds, 0);
  });

  test('capped and one-time upgrades are excluded', () {
    final eligible = eligiblePowerUps(GameState(
        sprintInvincibility: true,
        bulletsPhaseThrough: true,
        bulletNumberRange: 4,
        bulletSpeed: 1300,
        fastReload: true,
        fastReloadTime: 1000));
    expect(eligible, isNot(contains(PowerUp.sprintInvincibility)));
    expect(eligible, isNot(contains(PowerUp.bulletsPhaseThrough)));
    expect(eligible, isNot(contains(PowerUp.numberOfBulletsPerShotIncrease)));
    expect(eligible, isNot(contains(PowerUp.rapidFire)));
    expect(eligible, isNot(contains(PowerUp.fastReload)));
    expect(eligible.length, greaterThanOrEqualTo(2));
  });
}
