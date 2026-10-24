import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/game.dart';
import 'package:regun/models/solo_recovery.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/widgets/solo_revive_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

const owner = '11111111-1111-4111-8111-111111111111';

class Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  void pauseMusic(bool paused) {}
}

class MemoryRun extends RunStore {
  Map<String, dynamic>? saved;
  bool fail = false;
  final writes = <Map<String, dynamic>>[];
  @override
  Future<bool> write(Map<String, dynamic> data) async {
    if (fail) return false;
    saved = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    writes.add(saved!);
    return true;
  }

  @override
  Future<bool> writeRecovery(Map<String, dynamic> data) => write(data);

  @override
  Future<void> clear({String? expectedRunId}) async {
    if (expectedRunId == null || saved?['id'] == expectedRunId) saved = null;
  }
}

Future<void> idle(RegunGame game) async {
  for (var i = 0; i < 300 && game.recovery.busy; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(game.recovery.busy, isFalse);
}

void main() {
  test('500 banked before starting and five active minutes; no Training, guests or second revive', () {
    final r = SoloRecovery(owner: owner, startingScrap: 500);
    expect(r.eligible(299, false), isFalse);
    expect(r.eligible(300, false), isTrue);
    expect(r.eligible(300, true), isFalse);
    r.continued = true;
    expect(r.eligible(999, false), isFalse);
    expect(
      SoloRecovery(owner: owner, startingScrap: 499).eligible(500, false),
      isFalse,
    );
    expect(
      SoloRecovery(owner: 'guest', startingScrap: 500).eligible(500, false),
      isFalse,
    );
  });
  Future<RegunGame> mount(
    WidgetTester tester,
    MemoryRun store,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) transport, {
    Map<String, dynamic>? snapshot,
  }) async {
    late RegunGame game;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalPreferences.shared.load();
      await LocalPreferences.shared.activateProfile(owner);
      LocalPreferences.shared.profile.scrap = 1000;
      await LocalPreferences.shared.saveProfile();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(Quiet())],
          child: MaterialApp(
            home: BaseView(
              key: UniqueKey(),
              runStore: store,
              recoveryTransport: transport,
              resumeSnapshot: snapshot,
            ),
          ),
        ),
      );
      game =
          tester
                  .widget<RiverpodAwareGameWidget>(
                    find.byType(RiverpodAwareGameWidget),
                  )
                  .game!
              as RegunGame;
      await game.loaded;
      await tester.pump();
      await game.ready();
      if (snapshot == null) {
        game.update(2);
        await game.ready();
      }
    });
    return game;
  }

  void setTime(RegunGame game, int seconds) {
    final s = game.gameNotifier.checkpoint();
    s['activeSeconds'] = seconds.toDouble();
    s['state'] = game.gameState
        .copyWith(survivalSeconds: seconds, kills: 20, score: 123)
        .toJson();
    game.gameNotifier.restoreCheckpoint(s);
    game.resumeGame();
  }

  testWidgets(
    'lost debit response recovers once, preserves ordnance/build, and final rewards settle once',
    (tester) async {
      final store = MemoryRun();
      var buys = 0;
      var paid = false, activated = false, lose = true;
      late RegunGame game;
      Future<Map<String, dynamic>> transport(Map<String, dynamic> b) async {
        if (b['action'] == 'buy') {
          buys++;
          paid = true;
          if (lose) {
            lose = false;
            throw const AccountError('Connection interrupted');
          }
        }
        if (b['action'] == 'activate') activated = true;
        if (paid) LocalPreferences.shared.profile.scrap = 500;
        return {
          'revive': {
            'run': b['run'],
            'epoch': '0',
            'price': 500,
            'paid': paid,
            'state': activated
                ? 'activated'
                : paid
                ? 'purchased'
                : 'offered',
          },
        };
      }

      game = await mount(tester, store, transport);
      await tester.runAsync(() async {
        setTime(game, 300);
        game.grenades.spend(18);
        game.gameOver();
        await idle(game);
      });
      await tester.pump();
      expect(find.byType(SoloRevivePanel), findsOneWidget);
      expect(game.recovery.available, isTrue);
      expect(game.preferences.profile.totalKills, 0);
      expect(RunCheckpoint.valid(store.saved!), isTrue);
      final charges = game.grenades.charges;
      await tester.runAsync(() async {
        await Future.wait([game.buySoloRecovery(), game.buySoloRecovery()]);
      });
      expect(buys, 1);
      expect(game.recovery.stage, 'requested');
      expect(game.gameState.health, 0);
      await tester.runAsync(() async {
        await game.checkSoloRecovery();
      });
      expect(buys, 1);
      expect(activated, isTrue);
      expect(game.recovery.continued, isTrue);
      expect(game.gameState.health, (game.gameState.maxHealth / 2).ceil());
      expect(game.grenades.charges, charges);
      expect(
        store.writes.any(
          (s) =>
              (s['recovery'] as Map)['stage'] == 'prepared' &&
              s['state']['health'] > 0,
        ),
        isTrue,
      );
      expect(game.playerEntrance.active, isTrue);
      game.pauseGame();
      game.update(4);
      expect(game.playerEntrance.elapsed, 0);
      game.resumeGame();
      game.update(4);
      expect(game.gameState.health, (game.gameState.maxHealth / 2).ceil());
      await tester.runAsync(() async {
        game.gameOver();
        await game.leaveRun();
      });
      expect(game.preferences.profile.scrap, 507);
      expect(game.preferences.profile.continuedBestScore, 123);
      expect(game.preferences.profile.continuedBestSeconds, 300);
      expect(game.preferences.profile.bestScore, 0);
      expect(game.preferences.profile.bestSeconds, 0);
      final restoredProfile = game.preferences.profile.toJson();
      expect(restoredProfile['continuedBestScore'], 123);
      expect(game.preferences.profile.totalKills, 20);
      await tester.runAsync(() async {
        await game.settleRun();
      });
      expect(game.preferences.profile.scrap, 507);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed death journal never submits a spend; cancel an offline offer settles exactly once',
    (tester) async {
      final store = MemoryRun();
      var calls = 0;
      final game = await mount(tester, store, (b) async {
        calls++;
        throw const AccountError('Offline');
      });
      await tester.runAsync(() async {
        setTime(game, 300);
        store.fail = true;
        game.gameOver();
        await idle(game);
      });
      expect(calls, 0);
      expect(game.preferences.profile.totalKills, 0);
      await tester.runAsync(() async {
        await game.buySoloRecovery();
      });
      expect(calls, 0);
      await tester.runAsync(() async {
        store.fail = false;
        await game.checkSoloRecovery();
        await game.endRecoveryRun();
      });
      expect(game.preferences.profile.scrap, 1007);
      expect(game.preferences.profile.totalKills, 20);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'prepared recovery restores and activates the same receipt before resuming',
    (tester) async {
      final store = MemoryRun();
      var paid = false, activated = false;
      var activations = 0;
      Future<Map<String, dynamic>> transport(Map<String, dynamic> b) async {
        if (b['action'] == 'buy') paid = true;
        if (b['action'] == 'activate') {
          activations++;
          if (activations == 1) throw const AccountError('Offline');
          activated = true;
        }
        return {
          'revive': {
            'run': b['run'],
            'epoch': '0',
            'price': 500,
            'paid': paid,
            'state': activated
                ? 'activated'
                : paid
                ? 'purchased'
                : 'offered',
          },
        };
      }

      var game = await mount(tester, store, transport);
      await tester.runAsync(() async {
        setTime(game, 300);
        game.gameOver();
        await idle(game);
        await game.buySoloRecovery();
      });
      expect(game.recovery.stage, 'prepared');
      final snapshot = store.saved!;
      expect(RunCheckpoint.valid(snapshot), isTrue);
      game = await mount(tester, store, transport, snapshot: snapshot);
      await tester.runAsync(() async {
        await idle(game);
        await game.checkSoloRecovery();
      });
      expect(activated, isTrue);
      expect(game.recovery.continued, isTrue);
      expect(game.playerEntrance.active, isTrue);
      game.resumeGame();
      game.update(4); // Finish deployment without advancing the combat clock.
      final health = game.gameState.health;
      game.gameNotifier.advanceTime(1.5);
      expect(game.gameNotifier.reduceHealth(), isFalse);
      expect(game.gameState.health, health);
      game.gameNotifier.advanceTime(.6);
      expect(game.gameNotifier.reduceHealth(), isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final size in [const Size(844, 390), const Size(667, 375)]) {
    testWidgets(
      'pixel recovery controls fit ${size.width} and render ready/offline/confirmation states',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          for (final font in ['PressStart2P', 'Orbitron']) {
            await (FontLoader(font)
                  ..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf')))
                .load();
          }
        });
        for (final stage in ['offered', 'requested', 'prepared']) {
          final r = SoloRecovery(owner: owner, startingScrap: 1000)
            ..stage = stage
            ..available = stage == 'offered'
            ..epoch = '0';
          const key = Key('revive-render');
          await tester.pumpWidget(
            ProviderScope(
              overrides: [soloudPlayProvider.overrideWithValue(Quiet())],
              child: MaterialApp(
                home: RepaintBoundary(
                  key: key,
                  child: SoloRevivePanel(
                    state: GameState().copyWith(
                      survivalSeconds: 347,
                      kills: 164,
                      bosses: 1,
                      causeOfDeath: 'Mummy strike',
                    ),
                    recovery: r,
                    banked: 1000,
                    onBuy: () {},
                    onRetry: () {},
                    onEnd: () {},
                    onMenu: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text('END RUN'), findsOneWidget);
          expect(find.textContaining('records'), findsNothing);
          expect(find.textContaining('counts normally'), findsNothing);
          if (size.width >= 667) {
            expect(find.byType(SingleChildScrollView), findsNothing);
          }
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(key),
            );
            final im = await boundary.toImage();
            final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
            await Directory('build/test-previews').create(recursive: true);
            await File(
              'build/test-previews/revive-${size.width.toInt()}-$stage.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            im.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'large text and offline recovery keep end/retry actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final recovery = SoloRecovery(owner: owner, startingScrap: 1000)
        ..stage = 'offered'
        ..message =
            'Connect to confirm recovery. Retry or safely end this run.';
      var ended = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(Quiet())],
          child: MaterialApp(
            home: SoloRevivePanel(
              state: GameState(),
              recovery: recovery,
              banked: 1000,
              onBuy: () {},
              onRetry: () {},
              onEnd: () {
                ended = true;
              },
              onMenu: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.tap(find.text('END RUN'));
      expect(ended, isTrue);
      expect(find.text('RETRY CONNECTION'), findsOneWidget);
    },
  );
}
