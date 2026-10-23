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
      expect(LiveBalance.bundled.values.length, 209);
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
