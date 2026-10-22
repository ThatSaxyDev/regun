import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/systems/survivor_runtime.dart';
import 'package:regun/systems/upgrade_details.dart';
import 'package:regun/utils/soloud_play.dart';

class _Audio extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
}

void main() {
  late ProviderContainer container;
  late GameNotifier n;
  GameState state() => container.read(gameNotifierProvider);
  setUp(() {
    container = ProviderContainer(
      overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
    );
    n = container.read(gameNotifierProvider.notifier);
  });
  tearDown(() => container.dispose());
  test('all 210 kits initialize independently and retain identity through Continue', () {
    expect(CharacterType.values.length, 10);
    for (final c in CharacterType.values) {
      for (final w in WeaponType.values) {
        n.resetRun(
          loadout: Loadout(character: c, weapon: w),
        );
        expect(state().health, c.health);
        expect(state().movementSpeed, c.speed);
        expect(state().noOfBullets, w.capacity);
        final snap =
            jsonDecode(jsonEncode(n.checkpoint())) as Map<String, dynamic>;
        n.restoreCheckpoint(snap);
        expect(n.character, c);
        expect(n.weapon, w);
        expect(state().health, c.health);
        expect(n.buildBalance, 2);
      }
    }
    expect(CharacterType.values.where((c) => c.availableOnline).length, 3);
  });
  test('Flint finishes reload before charging one release; pickup refill never charges', () {
    n.resetRun(
      loadout: const Loadout(
        character: CharacterType.flint,
        weapon: WeaponType.revolver,
      ),
    );
    n.decreaseBullets();
    n.reloadBullets(manual: true);
    expect(n.checkpoint()['reloadDurationMs'], closeTo(2100 * .88 * .7, 1e-7));
    n.advanceTime(1);
    expect(state().reloading, true);
    expect(n.survivor.reloadCharge, 0);
    n.pauseGame();
    n.advanceTime(20);
    expect(n.survivor.reloadCharge, 0);
    n.playGame();
    n.advanceTime(.4);
    expect(state().reloading, false);
    expect(n.survivor.reloadCharge, 4);
    expect(n.survivor.release(n.character, 0), 1.2);
    expect(n.survivor.release(n.character, 0), 1);
    n.maxBulletsIncrease();
    expect(n.survivor.reloadCharge, 0);
    expect(n.survivor.reloads, 1);
  });
  test('Vesper cannot extend or stack windows by rapidly dashing', () {
    final r = n.survivor;
    r.landedDash(CharacterType.vesper);
    r.advance(.5);
    r.landedDash(CharacterType.vesper);
    expect(r.dashWindow, .5);
    expect(r.release(CharacterType.vesper, 0), 1.18);
    r.advance(.51);
    expect(r.release(CharacterType.vesper, 0), 1);
    r.advance(3);
    r.landedDash(CharacterType.vesper);
    expect(r.dashWindow, 1);
  });
  test('release ledger counts fans once, continuous slices at most twice per second', () {
    final r = n.survivor;
    r.release(CharacterType.coil, 0);
    expect(r.qualifyingHit(r.lastRelease), true);
    for (var i = 0; i < 10; i++) {
      expect(r.qualifyingHit(r.lastRelease), false);
    }
    r.release(CharacterType.coil, 0);
    expect(r.qualifyingHit(r.lastRelease, continuous: true), true);
    r.release(CharacterType.coil, 0);
    expect(r.qualifyingHit(r.lastRelease, continuous: true), false);
    r.advance(.5);
    r.release(CharacterType.coil, 0);
    expect(r.qualifyingHit(r.lastRelease, continuous: true), true);
    for (var i = 0; i < 4; i++) {
      expect(r.coilHit(), false);
    }
    expect(r.coilHit(), true);
    for (var i = 0; i < 5; i++) {
      expect(r.coilHit(), false);
    }
    r.advance(.8);
    expect(r.coilHit(), true);
  });
  test('Suture banks at most one heal and cannot revive lethal damage', () {
    n.resetRun(loadout: const Loadout(character: CharacterType.suture));
    for (var i = 0; i < 100; i++) {
      n.survivor.kill();
    }
    expect(n.survivor.triage, 15);
    n.advanceTime(1);
    expect(n.survivor.triage, 15);
    n.reduceHealth();
    n.advanceTime(.01);
    expect(state().health, 7);
    expect(n.survivor.triage, 0);
    for (var i = 0; i < 15; i++) {
      n.survivor.kill();
    }
    n.advanceTime(.5);
    n.reduceHealth();
    n.advanceTime(1);
    expect(state().health, 6);
    final saved = n.checkpoint();
    n.restoreCheckpoint(saved);
    n.playGame();
    n.advanceTime(11);
    expect(state().health, 7);
    expect(n.survivor.healed, 2);
    n.advanceTime(1);
    n.reduceHealth(amount: 100);
    n.advanceTime(100);
    expect(state().health, 0);
  });
  test('dependencies avoid inert support offers and capped velocity stops', () {
    final pool = eligiblePowerUps(GameState());
    expect(pool, isNot(contains(PowerUp.accelerant)));
    expect(pool, isNot(contains(PowerUp.bankShot)));
    expect(pool, isNot(contains(PowerUp.targetingLink)));
    expect(pool, isNot(contains(PowerUp.exposedSeam)));
    expect(
      eligiblePowerUps(GameState(), character: CharacterType.moth),
      contains(PowerUp.accelerant),
    );
    expect(
      eligiblePowerUps(GameState(), character: CharacterType.coil),
      contains(PowerUp.faradayReserve),
    );
    expect(
      eligiblePowerUps(
        GameState(bulletSpeed: 2000, baseProjectileSpeed: 1900),
        weapon: WeaponType.longwatchSniper,
      ),
      isNot(contains(PowerUp.rapidFire)),
    );
    expect(
      eligiblePowerUps(GameState(), weapon: WeaponType.anchorEngine),
      contains(PowerUp.sureFoot),
    );
  });
  test('passive state validates bounded clocks and preserves progress without replay', () {
    final r = SurvivorRuntime()
      ..completedReload(CharacterType.flint)
      ..landedDash(CharacterType.vesper);
    r.chainVictim(10);
    r.chainVictim(10);
    r.chainVictim(11);
    r.advance(.2);
    final copy = SurvivorRuntime()..restore(jsonDecode(jsonEncode(r.toJson())));
    expect(copy.reloadCharge, 3.8);
    expect(copy.chainVictims, 2);
    copy.chainVictim(10);
    expect(copy.chainVictims, 2);
    expect(copy.lastRelease, 0);
    expect(
      () =>
          SurvivorRuntime().restore({...r.toJson(), 'dashWindow': double.nan}),
      throwsFormatException,
    );
    expect(
      () => SurvivorRuntime().restore({...r.toJson(), 'coil': 6}),
      throwsFormatException,
    );
    n.resetRun();
    final old = n.checkpoint()
      ..remove('buildBalance')
      ..remove('survivorRuntime');
    n.restoreCheckpoint(old);
    expect(n.buildBalance, 1);
  });
  test(
    'unlock counters settle once, old milestones keep original membership',
    () {
      final p = PlayerProfile(
        totalBossVictories: 3,
        eliteKills: 15,
        cycleCharacters: {'rook', 'scrapper', 'warden'},
        fusions: {
          'firebreak',
          'stormCircuit',
          'minefield',
          'pinball',
          'breachEngine',
          'hunterSwarm',
        },
      );
      Set<String> settle({bool training = false}) => p.settle(
        runId: 'proof',
        loadout: Loadout(training: training),
        kills: 0,
        score: 0,
        seconds: 360,
        earnedScrap: 0,
        scorpions: 0,
        elites: 0,
        bosses: {},
        noHitBosses: {},
        foundFusions: {},
        enemies: {},
        dashes: 30,
        survivorProgress: {
          'reloads': 40,
          'grenadeKills': 120,
          'burningKills': 150,
          'chainVictims': 200,
          'healed': 40,
        },
      );
      expect(settle(training: true), isEmpty);
      expect(p.survivorCounters, isEmpty);
      expect(
        settle(),
        containsAll([
          'flint',
          'vesper',
          'fuse',
          'moth',
          'coil',
          'suture',
          'harrow',
          'survivor',
          'engineer',
        ]),
      );
      expect(settle(), isEmpty);
      expect(p.survivorCounters['reloads'], 40);
      final copy = PlayerProfile.fromJson(p.toJson());
      expect(copy.survivorCounters, p.survivorCounters);
      expect(copy.challenges, p.challenges);
      expect(PlayerProfile.fromJson({}).survivorCounters, isEmpty);
    },
  );
  test('all 41 offer details are concrete and preserve integer zeroes', () {
    for (final p in powerUps) {
      for (final rank in [0, 2, 3, 7]) {
        final detail = upgradeDetails(
          p,
          GameState(ranks: {p: rank}),
          WeaponType.shotgun,
        );
        expect(detail, isNotEmpty);
        expect(detail, isNot(contains('NaN')));
      }
    }
    expect(
      upgradeDetails(PowerUp.scavenger, GameState(), WeaponType.shotgun),
      contains('180 to 240'),
    );
    expect(
      upgradeDetails(PowerUp.bankShot, GameState(), WeaponType.shotgun),
      contains('1.08'),
    );
  });
}
