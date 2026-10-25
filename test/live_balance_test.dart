import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/data/weapon_power_balance.dart';
import 'package:regun/models/live_balance.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/services/balance_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  LiveBalance changed(int revision, num damage) =>
      LiveBalance.create(revision, {
        ...LiveBalance.bundled.values,
        'weapons.shotgun.damage': damage,
        'weapons.shotgun.capacity': 7,
        'weapons.shotgun.reloadMs': 4000,
        'survivors.rook.health': 10,
        'survivors.rook.speed': 330,
      });
  test(
    'snapshot enforces full schema, finite bounds, relationships and hash',
    () {
      expect(LiveBalance.bundled.values.length, 340);
      expect(
        LiveBalance.fromJson(
          jsonDecode(
            File('test/fixtures/balance-bundled-v1.json').readAsStringSync(),
          ),
        ).hash,
        LiveBalance.bundled.hash,
      );
      final snapshot = changed(1, 2);
      expect(LiveBalance.fromJson(snapshot.toJson()).hash, snapshot.hash);
      expect(
        () => snapshot.values['weapons.shotgun.damage'] = 3,
        throwsUnsupportedError,
      );
      expect(
        () => LiveBalance.fromJson({...snapshot.toJson(), 'hash': 'bad'}),
        throwsFormatException,
      );
      expect(
        () => LiveBalance.create(1, {
          ...snapshot.values,
          'weapons.shotgun.damage': double.nan,
        }),
        throwsFormatException,
      );
      expect(
        () => LiveBalance.create(1, {
          ...snapshot.values,
          'effects.sporelobber.sporeStride': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => LiveBalance.create(1, {
          ...snapshot.values,
          'weapons.shotgun.capacity': 100,
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'a new run pins numbers and Continue remains self-contained offline',
    () {
      final previous = BalanceRepository.shared.current;
      addTearDown(() => BalanceRepository.shared.current = previous);
      BalanceRepository.shared.current = changed(1, 2);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier)
        ..resetRun();
      expect(container.read(gameNotifierProvider).maxBullets, 7);
      expect(container.read(gameNotifierProvider).maxHealth, 10);
      expect(container.read(gameNotifierProvider).movementSpeed, 330);
      expect(notifier.weaponPower.damage(WeaponType.shotgun), 2);
      final saved = notifier.checkpoint();
      BalanceRepository.shared.current = changed(2, 3);
      expect(notifier.weaponPower.damage(WeaponType.shotgun), 2);
      notifier.resetRun();
      expect(notifier.weaponPower.damage(WeaponType.shotgun), 3);
      notifier.restoreCheckpoint(saved);
      expect(notifier.weaponPower.damage(WeaponType.shotgun), 2);
      expect(notifier.weaponPower.shellDuration(5), 4000);
      expect(WeaponPowerBalance.read(1).damage(WeaponType.shotgun), 1.2);
      expect(WeaponPowerBalance.read(2).damage(WeaponType.shotgun), 1.7);
    },
  );
  test(
    'Rail mechanics and live damage remain pinned in old and new snapshots',
    () {
      final oldRaw = jsonDecode(
        File('test/fixtures/balance-legacy-v1.json').readAsStringSync(),
      );
      final old = WeaponPowerBalance.read(2, oldRaw);
      expect(old.damage(WeaponType.railLance), 9);
      expect(old.railChargeMultiplier, 1);
      expect(old.railBulletRadius, 5);
      expect(old.railReaction.stagger, .13);
      final fresh = WeaponPowerBalance.live(LiveBalance.bundled);
      expect(fresh.damage(WeaponType.railLance), 11.25);
      expect(fresh.railChargeMultiplier, 1.25);
      expect(fresh.railBulletRadius, 7);
      expect(fresh.railReaction.stagger, .23);
      final restored = WeaponPowerBalance.read(3, fresh.snapshot!.toJson());
      expect(restored.damage(WeaponType.railLance), 11.25);
      expect(restored.railChargeMultiplier, 1.25);
      // Operators may still adjust base damage; charge multiplies it once.
      final custom = WeaponPowerBalance.live(
        LiveBalance.create(2, {
          ...LiveBalance.bundled.values,
          'weapons.railLance.damage': 12,
        }),
      );
      expect(
        custom.damage(WeaponType.railLance) * custom.railChargeMultiplier,
        15,
      );
    },
  );

  test(
    'legacy snapshots keep their original hash and default power-up strength',
    () {
      final raw = jsonDecode(
        File('test/fixtures/balance-legacy-v1.json').readAsStringSync(),
      );
      final legacy = LiveBalance.fromJson(raw);
      expect(legacy.values.length, 168);
      expect(legacy.toJson(), raw);
      final old = BalanceRepository.shared.current;
      addTearDown(() => BalanceRepository.shared.current = old);
      BalanceRepository.shared.current = legacy;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameNotifierProvider.notifier)
        ..resetRun();
      final saved = notifier.checkpoint();
      BalanceRepository.shared.current = LiveBalance.create(9, {
        ...LiveBalance.bundled.values,
        'powerups.heavyLoad.strength': 1.5,
      });
      notifier.restoreCheckpoint(saved);
      expect(
        container.read(gameNotifierProvider).strength(PowerUp.heavyLoad),
        1,
      );
      notifier.resetRun();
      expect(
        container.read(gameNotifierProvider).strength(PowerUp.heavyLoad),
        1.5,
      );
      final state = container
          .read(gameNotifierProvider)
          .copyWith(ranks: {PowerUp.heavyLoad: 3});
      expect(state.effectRank(PowerUp.heavyLoad), 4.5);
      expect(state.rank(PowerUp.heavyLoad), 3);
    },
  );
  test('accepted upgrades apply pinned strength and survive Continue', () {
    final old = BalanceRepository.shared.current;
    addTearDown(() => BalanceRepository.shared.current = old);
    BalanceRepository.shared.current = LiveBalance.create(10, {
      ...LiveBalance.bundled.values,
      'powerups.heavyLoad.strength': 1.5,
      'powerups.healthIncrease.strength': 2,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(gameNotifierProvider.notifier)..resetRun();
    void grant(PowerUp power) {
      final checkpoint = notifier.checkpoint();
      final state = container.read(gameNotifierProvider);
      checkpoint['state'] = state
          .copyWith(
            gameplayState: GameplayState.powerup,
            powerUpChoices: [power],
            offerId: state.offerId + 1,
          )
          .toJson();
      notifier.restoreCheckpoint(checkpoint);
      notifier.playGame();
      notifier.applyPowerUp(
        power,
        offerId: container.read(gameNotifierProvider).offerId,
      );
    }

    grant(PowerUp.heavyLoad);
    grant(PowerUp.healthIncrease);
    expect(
      container.read(gameNotifierProvider).shotDamage,
      closeTo(1.525, 1e-9),
    );
    expect(container.read(gameNotifierProvider).maxHealth, 8);
    final saved = notifier.checkpoint();
    BalanceRepository.shared.current = LiveBalance.bundled;
    notifier.resetRun();
    notifier.restoreCheckpoint(saved);
    expect(
      container.read(gameNotifierProvider).shotDamage,
      closeTo(1.525, 1e-9),
    );
    expect(
      container.read(gameNotifierProvider).strength(PowerUp.heavyLoad),
      1.5,
    );
  });
  test(
    'a transport construction failure cannot escape background refresh',
    () async {
      final repository = BalanceRepository(
        client: () => throw StateError('unavailable'),
      );
      await repository.refresh(force: true);
      expect(repository.current.hash, LiveBalance.bundled.hash);
    },
  );
  test(
    'download is deduplicated, cached and never changes a captured snapshot',
    () async {
      final pending = Completer<http.Response>(), next = changed(8, 2);
      var calls = 0;
      final repository = BalanceRepository(
        endpoint: Uri.parse('https://test.example'),
        client: () => MockClient((request) {
          calls++;
          expect(request.url.path, '/balance/v1/current');
          return pending.future;
        }),
      );
      final captured = repository.current;
      final first = repository.refresh(force: true),
          second = repository.refresh(force: true);
      expect(
        repository.current.revision,
        0,
      ); // Offline/new-run input never waits.
      pending.complete(http.Response(jsonEncode(next.toJson()), 200));
      await Future.wait([first, second]);
      expect(calls, 1);
      expect(repository.current.revision, 8);
      expect(captured.revision, 0);
      final offline = BalanceRepository(
        endpoint: Uri.parse('https://test.example'),
        client: () => MockClient((_) async => throw StateError('offline')),
      );
      await offline.start();
      expect(offline.current.hash, next.hash);
      final malformed = BalanceRepository(
        endpoint: Uri.parse('https://test.example'),
        client: () => MockClient((_) async => http.Response('{}', 200)),
      );
      await malformed.start();
      expect(malformed.current.hash, next.hash);
    },
  );
}
