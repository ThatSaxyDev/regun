import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/notifiers/game_notifier.dart';
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

  test('XP upgrades at exactly seven pickups and freezes one choice set', () {
    for (var i = 0; i < 7; i++) {
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

  test('XP overflow survives sequential choices and stale offer tokens', () {
    notifier.increaseXP(30);
    expect(state().xP, 23);
    final offerId = state().offerId;
    final choice = state().powerUpChoices.first;
    notifier.applyPowerUp(choice, offerId: offerId);
    expect(state().gameplayState, GameplayState.powerup);
    expect(state().xP, 15);
    expect(state().currentLevel, 3);
    final next = state();
    notifier.applyPowerUp(choice, offerId: offerId);
    expect(identical(next, state()), isTrue);
  });

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
    notifier.increaseXP(7);
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
