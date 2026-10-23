import 'package:regun/widgets/wallet_bar.dart';
import 'package:regun/data/loadout.dart';

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
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/widgets/confirm_run_action.dart';
import 'package:regun/widgets/game_notice.dart';
import 'package:regun/widgets/run_pause_summary.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Audio extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool paused) {}
}

class _Store extends RunStore {
  bool succeeds = true;
  Map<String, dynamic>? saved;
  @override
  Future<bool> write(Map<String, dynamic> data) async {
    if (succeeds) saved = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    return succeeds;
  }

  @override
  Future<void> clear({String? expectedRunId}) async {
    saved = null;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final font in ['PressStart2P', 'Orbitron']) {
      await (FontLoader(
        font,
      )..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf'))).load();
    }
  });
  Future<RegunGame> mount(WidgetTester tester, _Store store) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    late RegunGame game;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
        child: RepaintBoundary(
          key: const Key('pause-capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Start run'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BaseView(runStore: store),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Start run'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
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
      game.update(2);
    });
    await tester.pump();
    final state = game.gameState.copyWith(
      health: 3,
      kills: 47,
      bosses: 2,
      survivalSeconds: 187,
      currentLevel: 4,
      xP: 10,
      noOfCoinsToUpgrade: 59,
      noOfBullets: 3,
    );
    game.gameNotifier.restoreCheckpoint({
      ...game.gameNotifier.checkpoint(),
      'state': state.toJson(),
    });
    game.pauseGame();
    await tester.pump();
    return game;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('pause-capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2),
          bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'normal pause shows recorded progress and resources, and restart requires confirmation',
    (tester) async {
      final game = await mount(tester, _Store()), run = game.runId;
      expect(find.byType(RunPauseSummary), findsOneWidget);
      final heading = tester.getRect(find.text('PAUSED'));
      final wallet = tester.getRect(find.byType(WalletBar));
      expect(wallet.left, greaterThan(heading.right));
      expect((wallet.center.dy - heading.center.dy).abs(), lessThan(3));
      expect(find.text('SCRAP'), findsNothing);
      expect(find.text('CREDITS'), findsNothing);
      for (final text in [
        '3:07',
        '47',
        '2',
        '3 / 6',
        '3 / 5',
        '4',
        '10 / 59 XP',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('The horde can wait.'), findsNothing);
      await capture(tester, 'normal-pause-summary');
      final restart = tester.widget<ClickButton>(
        find.ancestor(
          of: find.text('RESTART'),
          matching: find.byType(ClickButton),
        ),
      );
      restart.onTap!();
      restart.onTap!(); // Double tap must open one prompt.
      await tester.pumpAndSettle();
      expect(find.byType(GameNotice), findsOneWidget);
      expect(game.runId, run);
      expect(game.gameState.kills, 47);
      game.update(5);
      expect(game.gameState.survivalSeconds, 187);
      await capture(tester, 'restart-run-notice');
      await tester.tap(find.byKey(const Key('run-action-cancel')));
      await tester.pumpAndSettle();
      expect(game.runId, run);
      expect(game.gameState.gameplayState, GameplayState.paused);
      await tester.tap(find.text('RESTART'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('run-action-confirm')));
        await tester.pump();
        await game.ready();
      });
      expect(game.runId, isNot(run));
      expect(game.gameState.kills, 0);
      expect(game.gameState.health, 6);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Menu cancellation preserves the run, confirmation saves it, and save failure stays paused',
    (tester) async {
      final store = _Store(),
          game = await mount(tester, store),
          run = game.runId;
      await tester.tap(find.byKey(const Key('pause-menu-home')));
      await tester.pumpAndSettle();
      expect(find.text('Your run will be saved for Continue.'), findsOneWidget);
      await capture(tester, 'save-and-leave-notice');
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byType(BaseView), findsOneWidget);
      expect(game.runId, run);
      store.succeeds = false;
      await tester.tap(find.byKey(const Key('pause-menu-home')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('run-action-confirm')));
        await Future<void>.delayed(Duration.zero);
        await tester.pump();
      });
      await tester.pumpAndSettle();
      expect(find.byType(BaseView), findsOneWidget);
      expect(game.runId, run);
      expect(game.gameState.gameplayState, GameplayState.paused);
      expect(
        find.text('Run could not be saved. Stay here and try Menu again.'),
        findsOneWidget,
      );
      store.succeeds = true;
      await tester.tap(find.byKey(const Key('pause-menu-home')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('run-action-confirm')));
        await Future<void>.delayed(Duration.zero);
        await tester.pump();
      });
      await tester.pumpAndSettle();
      expect(find.byType(BaseView), findsNothing);
      expect(store.saved!['id'], run);
      expect(store.saved!['state']['kills'], 47);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'all shared confirmation banners fit small screens and large text without accidental acceptance',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [const Size(568, 320), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        for (final scale in [1.0, 1.5]) {
          bool? accepted;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
              child: RepaintBoundary(
                key: const Key('pause-capture'),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        child: const Text('Open'),
                        onPressed: () async {
                          accepted = await confirmRunAction(
                            context,
                            eyebrow: 'RE-GUN / SAVED RUN',
                            title: 'REPLACE SAVED RUN?',
                            message: 'Starting a new run replaces your saved run and its upgrades.',
                            action: 'New run',
                            cancel: 'Keep run',
                            destructive: true,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.byType(GameNotice), findsOneWidget);
          await tester.ensureVisible(find.text('NEW RUN'));
          await tester.pump();
          expect(find.text('NEW RUN').hitTestable(), findsOneWidget);
          if (size.width == 568 && scale == 1) {
            await capture(tester, 'replace-saved-run-notice');
          }
          await tester.ensureVisible(find.text('KEEP RUN'));
          await tester.pump();
          await tester.tap(find.text('KEEP RUN'));
          await tester.pumpAndSettle();
          expect(accepted, isFalse);
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'pause resources include a frozen reload time and fit narrow enlarged-text layouts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [const Size(568, 320), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: RunPauseSummary(
                      state: GameState(
                        reloading: true,
                        noOfBullets: 2,
                        health: 3,
                        survivalSeconds: 187,
                        kills: 47,
                      ),
                      loadout: const Loadout(),
                      reloadSeconds: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Reloading 1.2s'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
