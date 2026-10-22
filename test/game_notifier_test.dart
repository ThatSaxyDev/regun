import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/systems/xp_progression.dart';
import 'package:regun/utils/soloud_play.dart';

class SilentAudio extends SoloudPlay {
  int reloadSounds = 0;
  final sounds = <String>[];
  @override
  Future<void> play(String assetPath) async {
    sounds.add(assetPath);
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
      overrides: [soloudPlayProvider.overrideWithValue(audio)],
    );
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
          offerId: state().offerId + 1,
        )
        .toJson();
    notifier.restoreCheckpoint(snapshot);
    notifier.playGame();
    notifier.applyPowerUp(power, offerId: state().offerId);
  }

  test(
    'every upgrade family remains selectable through eight ranks, then stops',
    () {
      for (final power in powerUps) {
        final weapon = power == PowerUp.exposedSeam
            ? WeaponType.frostShotgun
            : power == PowerUp.sureFoot
            ? WeaponType.arcCaster
            : WeaponType.shotgun;
        notifier.resetRun(loadout: Loadout(weapon: weapon));
        if (power == PowerUp.accelerant || power == PowerUp.scouringHeat) {
          grant(PowerUp.hotShot);
        }
        if (power == PowerUp.conductiveCore || power == PowerUp.faradayReserve) {
          grant(PowerUp.staticCharge);
        }
        if (power == PowerUp.bankShot) grant(PowerUp.ricochet);
        if (power == PowerUp.targetingLink) grant(PowerUp.orbitDrone);
        for (var rank = 1; rank <= 8; rank++) {
          expect(
            eligiblePowerUps(state(), weapon: weapon),
            contains(power),
            reason: '${power.name} $rank',
          );
          grant(power);
          expect(state().rank(power), rank);
        }
        expect(
          eligiblePowerUps(state(), weapon: weapon),
          isNot(contains(power)),
        );
        grant(power); // A stale offered card must not grant rank nine.
        expect(state().rank(power), 8);
        final saved = notifier.checkpoint();
        notifier.restoreCheckpoint(saved);
        expect(state().rank(power), 8);
      }
    },
  );

  test('magazine pickup refills now, cancels reload, and its short cue freezes on pause', () {
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
    notifier.advanceTime(3.199);
    expect(state().reloading, isTrue);
    notifier.advanceTime(.001);
    expect(
      state().noOfBullets,
      7,
    ); // Bigger tubes retain the new 3.2-second base cap.
    grant(PowerUp.maxBulletsIncrease);
    notifier.decreaseBullets(); // Firing can interrupt the cosmetic cue immediately.
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
          weapon == WeaponType.shotgun ? 850 : weapon.reloadMs * .4,
        ),
      );
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
    'device weapon balance migrates old magazines and hammer range only once',
    () {
      for (final weapon in [
        WeaponType.beltRepeater,
        WeaponType.prismCutter,
        WeaponType.longwatchSniper,
      ]) {
        notifier.resetRun(loadout: Loadout(weapon: weapon));
        final delta = weapon == WeaponType.beltRepeater
            ? 40
            : weapon == WeaponType.prismCutter
            ? 8
            : 1;
        final old = notifier.checkpoint()..remove('arsenalReviewBalance');
        old['state'] = state()
            .copyWith(
              maxBullets: weapon.capacity - delta,
              noOfBullets: 1,
              bulletRange: weapon == WeaponType.longwatchSniper
                  ? 130
                  : state().bulletRange,
              bulletSpeed: weapon == WeaponType.longwatchSniper
                  ? 600
                  : state().bulletSpeed,
            )
            .toJson();
        notifier.restoreCheckpoint(old);
        expect(state().maxBullets, weapon.capacity);
        expect(state().noOfBullets, 1 + delta);
        if (weapon == WeaponType.longwatchSniper) {
          expect(state().bulletRange, 1200);
          expect(state().bulletSpeed, 1900);
        }
        notifier.restoreCheckpoint(notifier.checkpoint());
        expect(state().maxBullets, weapon.capacity);
        expect(state().noOfBullets, 1 + delta);
      }
      expect(
        Loadout.fromJson({
          'weapon': 'breachHammer',
          'character': 'rook',
          'arena': 'breach',
        }).weapon,
        WeaponType.longwatchSniper,
      );
    },
  );

  test('seventy-round Repeater saves migrate once and retain magazines above one hundred', () {
    notifier.resetRun(loadout: const Loadout(weapon: WeaponType.beltRepeater));
    final old = notifier.checkpoint();
    old['arsenalReviewBalance'] = 1;
    old['state'] = state().copyWith(maxBullets: 73, noOfBullets: 20).toJson();
    notifier.restoreCheckpoint(old);
    expect(state().maxBullets, 103);
    expect(state().noOfBullets, 50);
    notifier.restoreCheckpoint(notifier.checkpoint());
    expect(state().maxBullets, 103);
    expect(state().noOfBullets, 50);
    notifier.maxBulletsIncrease();
    final capacity = state().maxBullets;
    notifier.restoreCheckpoint(notifier.checkpoint());
    expect(state().maxBullets, capacity);
  });

  for (final weapon in WeaponType.values) {
    test(
      '${weapon.name} partial reload is faster and never plays its final action',
      () {
        notifier.resetRun(loadout: Loadout(weapon: weapon));
        notifier.decreaseBullets();
        notifier.reloadBullets(manual: true);
        final normal = weapon == WeaponType.shotgun ? 800 : weapon.reloadMs;
        expect(notifier.reloadTactical, true);
        expect(
          notifier.checkpoint()['reloadDurationMs'],
          closeTo(normal * .7, 1e-9),
        );
        notifier.advanceTime(normal * .7 / 1000 - .001);
        expect(state().reloading, true);
        expect(state().noOfBullets, weapon.capacity - 1);
        expect(
          audio.sounds,
          isNot(
            contains(
              weapon == WeaponType.shotgun
                  ? 'reload_shotgun_pump.wav'
                  : 'reload_${weapon.name}_2.wav',
            ),
          ),
        );
        final saved = notifier.checkpoint();
        notifier.restoreCheckpoint(saved);
        expect(notifier.reloadTactical, true);
        notifier.playGame();
        notifier.advanceTime(.001);
        expect(state().noOfBullets, weapon.capacity);
        expect(state().reloading, false);
        audio.sounds.clear();
        for (var i = 0; i < weapon.capacity; i++) {
          notifier.decreaseBullets();
        }
        notifier.reloadBullets();
        expect(notifier.reloadTactical, false);
        final empty = weapon == WeaponType.shotgun ? 3200 : weapon.reloadMs;
        expect(notifier.checkpoint()['reloadDurationMs'], empty);
        notifier.advanceTime(empty / 1000);
        expect(
          audio.sounds,
          contains(
            weapon == WeaponType.shotgun
                ? 'reload_shotgun_pump.wav'
                : 'reload_${weapon.name}_2.wav',
          ),
        );
      },
    );
  }

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
            bulletSpeed: 850,
          )
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
    },
  );

  test('carbine swaps one magazine with no per-round refill or shell cues', () {
    for (final spent in [1, WeaponType.carbine.capacity]) {
      notifier.resetRun(loadout: const Loadout(weapon: WeaponType.carbine));
      audio.sounds.clear();
      for (var round = 0; round < spent; round++) {
        notifier.decreaseBullets();
      }
      final before = state().noOfBullets;
      notifier.reloadBullets();
      expect(notifier.checkpoint()['reloadDurationMs'], 1800);
      for (var step = 0; step < 17; step++) {
        notifier.advanceTime(.1);
        expect(state().reloading, isTrue);
        expect(state().noOfBullets, before); // No bullet-by-bullet loading.
      }
      notifier.advanceTime(.1);
      expect(state().reloading, isFalse);
      expect(state().noOfBullets, WeaponType.carbine.capacity);
      expect(audio.sounds, [
        'reload_carbine_0.wav', // Magazine out.
        'reload_carbine_1.wav', // Fresh magazine seated.
        'reload_carbine_2.wav', // Bolt.
      ]);
    }
  });

  test('manual chambered Carbine skips bolt and empty reload keeps it', () {
    notifier.resetRun(loadout: const Loadout(weapon: WeaponType.carbine));
    notifier.decreaseBullets();
    notifier.reloadBullets(manual: true);
    expect(notifier.checkpoint()['reloadDurationMs'], closeTo(1260, .001));
    notifier.advanceTime(1.259);
    expect(state().reloading, isTrue);
    notifier.advanceTime(.001);
    expect(state().reloading, isFalse);
    expect(state().noOfBullets, state().maxBullets);
    expect(audio.sounds, ['reload_carbine_0.wav', 'reload_carbine_1.wav']);
    audio.sounds.clear();
    while (state().noOfBullets > 0) {
      notifier.decreaseBullets();
    }
    notifier.reloadBullets(manual: true);
    expect(notifier.checkpoint()['reloadDurationMs'], 1800);
    notifier.advanceTime(1.8);
    expect(audio.sounds, [
      'reload_carbine_0.wav',
      'reload_carbine_1.wav',
      'reload_carbine_2.wav',
    ]);
  });

  for (final weapon in WeaponType.values.where(
    (w) => w != WeaponType.carbine && w != WeaponType.burstRifle,
  )) {
    for (final spent in [1, weapon.capacity]) {
      test(
        '${weapon.name} completes the correct refill after $spent shots',
        () {
          notifier.resetRun(loadout: Loadout(weapon: weapon));
          for (var i = 0; i < spent; i++) {
            notifier.decreaseBullets();
          }
          final before = state().noOfBullets;
          notifier.reloadBullets(manual: true);
          final tactical = spent < weapon.capacity;
          final duration =
              (weapon == WeaponType.shotgun
                  ? GameNotifier.reloadDurationFor(spent)
                  : weapon.reloadMs) *
              (tactical ? .70 : 1.0);
          expect(notifier.checkpoint()['reloadDurationMs'], duration);
          expect(notifier.reloadTactical, tactical);
          notifier.advanceTime(duration / 2000);
          expect(state().noOfBullets, before);
          notifier.restoreCheckpoint(notifier.checkpoint());
          notifier.advanceTime(20); // Continue remains paused.
          expect(state().noOfBullets, before);
          notifier.playGame();
          notifier.advanceTime(duration / 2000 - .001);
          expect(state().reloading, isTrue);
          expect(state().noOfBullets, before);
          notifier.advanceTime(.001);
          expect(state().reloading, isFalse);
          expect(state().noOfBullets, state().maxBullets);
        },
      );
    }

    test('${weapon.name} migrates a saved interruption into a full reload', () {
      notifier.resetRun(loadout: Loadout(weapon: weapon));
      final duration = weapon == WeaponType.shotgun
          ? GameNotifier.reloadDurationFor(weapon.capacity)
          : weapon.reloadMs;
      final old = notifier.checkpoint();
      old['state'] = state().copyWith(noOfBullets: 1, reloading: true).toJson();
      if (weapon == WeaponType.shotgun) old.remove('shotgunReloadBalance');
      final originalDuration = weapon == WeaponType.shotgun ? 3700 : duration;
      old['reloadDurationMs'] = originalDuration * .85;
      old['reloadElapsedMs'] = originalDuration * .85 * .42;
      old['reloadPlan'] = {
        'startAmmo': 0,
        'missing': weapon.capacity,
        'loaded': 1,
        'tactical': true,
        'closeElapsedMs': 40,
        'closeDurationMs': 100,
        'closeStartProgress': .42,
      };
      notifier.restoreCheckpoint(old);
      expect(state().noOfBullets, 0);
      expect(
        notifier.checkpoint()['reloadDurationMs'],
        closeTo(duration, .001),
      );
      notifier.playGame();
      notifier.advanceTime(.15); // Old ready action must not finish the reload.
      expect(state().reloading, isTrue);
      expect(state().noOfBullets, 0);
      notifier.advanceTime(duration / 1000);
      expect(state().reloading, isFalse);
      expect(state().noOfBullets, weapon.capacity);
    });
  }

  test(
    'Burst Rifle chambered reload is1.4s and only empty reload cycles bolt',
    () {
      for (final left in [1, 9, 17]) {
        notifier.resetRun(
          loadout: const Loadout(weapon: WeaponType.burstRifle),
        );
        while (state().noOfBullets > left) {
          notifier.decreaseBullets();
        }
        audio.sounds.clear();
        notifier.reloadBullets(manual: true);
        expect(notifier.reloadTactical, isTrue);
        expect(notifier.checkpoint()['reloadDurationMs'], closeTo(1400, .001));
        notifier.advanceTime(1.147);
        expect(audio.sounds, ['reload_burstRifle_0.wav']);
        notifier.advanceTime(.001);
        expect(audio.sounds, [
          'reload_burstRifle_0.wav',
          'reload_burstRifle_1.wav',
        ]);
        expect(state().noOfBullets, left);
        notifier.advanceTime(.251);
        expect(state().reloading, isTrue);
        notifier.advanceTime(.001);
        expect(state().reloading, isFalse);
        expect(state().noOfBullets, 18);
        expect(audio.sounds, [
          'reload_burstRifle_0.wav',
          'reload_burstRifle_1.wav',
        ]);
      }
      notifier.resetRun(loadout: const Loadout(weapon: WeaponType.burstRifle));
      while (state().noOfBullets > 0) {
        notifier.decreaseBullets();
      }
      audio.sounds.clear();
      notifier.reloadBullets(manual: true);
      expect(notifier.reloadTactical, isFalse);
      expect(notifier.checkpoint()['reloadDurationMs'], 2000);
      notifier.advanceTime(1.999);
      expect(state().noOfBullets, 0);
      expect(state().reloading, isTrue);
      notifier.advanceTime(.001);
      expect(state().noOfBullets, 18);
      expect(audio.sounds, [
        'reload_burstRifle_0.wav',
        'reload_burstRifle_1.wav',
        'reload_burstRifle_2.wav',
      ]);
    },
  );

  test('Burst tactical Continue preserves timing and never replays a seated-mag cue', () {
    notifier.resetRun(loadout: const Loadout(weapon: WeaponType.burstRifle));
    notifier.decreaseBullets();
    notifier.reloadBullets(manual: true);
    notifier.advanceTime(1.2);
    final saved = notifier.checkpoint();
    audio.sounds.clear();
    notifier.restoreCheckpoint(saved);
    expect(notifier.reloadTactical, isTrue);
    notifier.advanceTime(10); // Continue still paused.
    expect(state().noOfBullets, 17);
    notifier.playGame();
    notifier.advanceTime(.199);
    expect(state().reloading, isTrue);
    notifier.advanceTime(.001);
    expect(state().reloading, isFalse);
    expect(audio.sounds, isEmpty);
  });

  test(
    'old full Burst reload saves retain their full duration and bolt cue',
    () {
      notifier.resetRun(loadout: const Loadout(weapon: WeaponType.burstRifle));
      notifier.decreaseBullets();
      notifier.reloadBullets(); // Earlier full-reload-only candidate snapshot.
      notifier.advanceTime(.5);
      final saved = notifier.checkpoint();
      notifier.restoreCheckpoint(saved);
      expect(notifier.reloadTactical, isFalse);
      expect(notifier.checkpoint()['reloadDurationMs'], 2000);
      notifier.playGame();
      notifier.advanceTime(1.5);
      expect(state().reloading, isFalse);
      expect(audio.sounds, [
        'reload_burstRifle_0.wav',
        'reload_burstRifle_1.wav',
        'reload_burstRifle_2.wav',
      ]);
    },
  );

  test('Carbine tactical timing survives Continue without replaying bolt', () {
    notifier.resetRun(loadout: const Loadout(weapon: WeaponType.carbine));
    notifier.decreaseBullets();
    notifier.reloadBullets(manual: true);
    notifier.advanceTime(.5);
    notifier.restoreCheckpoint(notifier.checkpoint());
    expect(notifier.reloadTactical, isTrue);
    notifier.playGame();
    notifier.advanceTime(.76);
    expect(state().reloading, isFalse);
    expect(audio.sounds, ['reload_carbine_0.wav', 'reload_carbine_1.wav']);
  });

  for (var missing = 1; missing <= 5; missing++) {
    test(
      'uses assisted shotgun timing and matching shell sounds for $missing missing shells',
      () {
        for (var i = 0; i < missing; i++) {
          notifier.decreaseBullets();
        }
        notifier.reloadBullets();
        final duration = 800 + 600 * (missing - 1);
        // Duplicate requests do not restart the reload or play extra sounds.
        notifier.reloadBullets();
        notifier.advanceTime((duration - 1) / 1000);
        expect(state().reloading, isTrue);
        expect(state().noOfBullets, 5 - missing);
        expect(audio.reloadSounds, missing);
        notifier.advanceTime(0.001);
        expect(state().reloading, isFalse);
        expect(state().noOfBullets, 5);
      },
    );
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

  test(
    'supply reward is unique, separate from XP, and respects prompt grace',
    () {
      notifier.increaseXP(7);
      final cost = state().noOfCoinsToUpgrade;
      expect(notifier.offerSupplyUpgrade(), isTrue);
      expect(notifier.supplyOffer, isTrue);
      expect(
        state().powerUpChoices.toSet().length,
        state().powerUpChoices.length,
      );
      expect(state().xP, 7);
      expect(state().currentLevel, 1);
      expect(state().noOfCoinsToUpgrade, cost);
      notifier.restoreCheckpoint(notifier.checkpoint());
      notifier.playGame();
      expect(notifier.supplyOffer, isTrue);
      notifier.applyPowerUp(
        state().powerUpChoices.first,
        offerId: state().offerId,
      );
      expect(notifier.offerSupplyUpgrade(), isFalse);
      notifier.advanceTime(4);
      notifier.increaseXP();
      expect(state().currentLevel, 2);
      expect(notifier.supplyOffer, isFalse);
    },
  );

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

  test('base dash protects the full duration and freezes while paused', () {
    final health = state().health;
    notifier.triggerSprintInvincibility();
    notifier.advanceTime(.10);
    expect(notifier.reduceHealth(cause: 'Chain Magistrate'), isFalse);
    notifier.advanceTime(.049);
    expect(notifier.reduceHealth(cause: 'Marshal laser', amount: 3), isFalse);
    expect(state().health, health);
    notifier.pauseGame();
    notifier.advanceTime(3);
    expect(state().triggerSprintInvincibility, isTrue);
    notifier.playGame();
    notifier.advanceTime(.002);
    expect(notifier.reduceHealth(cause: 'Ground hazard'), isTrue);
    expect(state().health, health - 1);
  });

  test(
    'Scrapper is 15% faster and old saved speed gains the new base once',
    () {
      notifier.resetRun(
        loadout: const Loadout(character: CharacterType.scrapper),
      );
      expect(state().movementSpeed, 345);
      notifier.walkingSpeedIncrease();
      final upgraded = state().movementSpeed;
      final old = notifier.checkpoint()..remove('survivorSpeedBalance');
      old['state'] = state().copyWith(movementSpeed: upgraded - 45).toJson();
      notifier.restoreCheckpoint(old);
      expect(state().movementSpeed, upgraded);
      notifier.restoreCheckpoint(notifier.checkpoint());
      expect(state().movementSpeed, upgraded);
      final previousCandidate = notifier.checkpoint();
      previousCandidate['survivorSpeedBalance'] = 2;
      previousCandidate['state'] = state()
          .copyWith(movementSpeed: upgraded + 105)
          .toJson();
      notifier.restoreCheckpoint(previousCandidate);
      expect(state().movementSpeed, upgraded);
      notifier.restoreCheckpoint(notifier.checkpoint());
      expect(state().movementSpeed, upgraded);
      notifier.resetWalkingSpeed();
      expect(state().movementSpeed, 345);
      notifier.resetRun();
      expect(state().movementSpeed, 300);
    },
  );

  test('Warden is 13% slower and existing upgraded saves migrate once', () {
    for (final previousBalance in [0, 1]) {
      notifier.resetRun(
        loadout: const Loadout(character: CharacterType.warden),
      );
      expect(state().movementSpeed, 261);
      notifier.walkingSpeedIncrease();
      final upgraded = state().movementSpeed;
      final old = notifier.checkpoint();
      old['survivorSpeedBalance'] = previousBalance;
      old['state'] = state().copyWith(movementSpeed: upgraded + 9).toJson();
      notifier.restoreCheckpoint(old);
      expect(state().movementSpeed, upgraded);
      notifier.restoreCheckpoint(notifier.checkpoint());
      expect(state().movementSpeed, upgraded);
      notifier.resetWalkingSpeed();
      expect(state().movementSpeed, 261);
    }
  });

  test('damage is guarded, respects invulnerability and ends the run once', () {
    expect(notifier.reduceHealth(), isTrue);
    expect(notifier.reduceHealth(), isFalse);
    expect(state().health, 5);
    notifier.advanceTime(0.5);
    notifier.sprintInvincibility();
    notifier.triggerSprintInvincibility();
    expect(notifier.reduceHealth(), isFalse);
    notifier.advanceTime(0.221);
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
    expect(
      [for (var level = 1; level <= 6; level++) XPProgression.cost(level)],
      [8, 18, 35, 59, 90, 128],
    );
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

  test(
    'boss rewards never give unfunded ordinary upgrades; fusion is explicit',
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
    },
  );

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
    test(
      'Scrap Armour rank $rank blocks a heavy hit and recharges in play',
      () {
        final checkpoint = notifier.checkpoint();
        checkpoint['state'] = state()
            .copyWith(
              ranks: {if (rank > 1) PowerUp.scrapArmour: rank - 1},
              powerUpChoices: [PowerUp.scrapArmour],
            )
            .toJson();
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
      },
    );
  }

  test(
    'old shotgun reloads migrate progress and pending cues exactly once',
    () {
      for (var i = 0; i < 5; i++) {
        notifier.decreaseBullets();
      }
      notifier.reloadBullets();
      notifier.advanceTime(.96);
      final old = notifier.checkpoint()..remove('shotgunReloadBalance');
      old['reloadDurationMs'] = 3700.0;
      old['reloadElapsedMs'] = 1110.0;
      old['nextReloadSoundMs'] = 1400.0;
      final sounds = audio.reloadSounds;
      notifier.restoreCheckpoint(old);
      expect(notifier.reloadProgress.value, closeTo(.3, 1e-9));
      expect(notifier.checkpoint()['reloadDurationMs'], 3200);
      expect(audio.reloadSounds, sounds);
      final current = notifier.checkpoint();
      notifier.restoreCheckpoint(current);
      expect(notifier.checkpoint()['reloadDurationMs'], 3200);
      expect(notifier.reloadProgress.value, closeTo(.3, 1e-9));
      notifier.playGame();
      notifier.advanceTime(.24);
      expect(audio.reloadSounds, sounds + 1);
      expect(state().noOfBullets, 0);
      notifier.advanceTime(2);
      expect(state().reloading, isFalse);
      expect(state().noOfBullets, 5);
    },
  );

  test('fast reload never slows down a partial shotgun reload', () {
    notifier.fastReload();
    notifier.decreaseBullets();
    notifier.reloadBullets();
    expect(notifier.checkpoint()['reloadDurationMs'], 800);
    notifier.advanceTime(0.9);
    expect(state().reloading, isFalse);
  });

  test(
    'run time and kill records freeze during selection and reset together',
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
    },
  );

  test('capped and one-time upgrades are excluded', () {
    final eligible = eligiblePowerUps(
      GameState(
        sprintInvincibility: true,
        bulletsPhaseThrough: true,
        bulletNumberRange: 4,
        bulletSpeed: 1300,
        fastReload: true,
        fastReloadTime: 1000,
      ),
    );
    expect(eligible, isNot(contains(PowerUp.sprintInvincibility)));
    expect(eligible, isNot(contains(PowerUp.bulletsPhaseThrough)));
    expect(eligible, isNot(contains(PowerUp.numberOfBulletsPerShotIncrease)));
    expect(eligible, isNot(contains(PowerUp.rapidFire)));
    expect(eligible, isNot(contains(PowerUp.fastReload)));
    expect(eligible.length, greaterThanOrEqualTo(2));
  });
}
