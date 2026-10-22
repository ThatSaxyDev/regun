import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/controls_view.dart';
import 'package:regun/views/settings_view.dart';
import 'package:regun/widgets/control_settings.dart';
import 'package:regun/widgets/practice_section.dart';
import 'package:regun/widgets/training_notice.dart';
import 'package:regun/widgets/weapon_practice_tile.dart';
import 'package:regun/widgets/weapon_thumbnail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool paused) {}
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
  Future<RegunGame> mount(
    WidgetTester tester, {
    bool completedIntro = false,
    double scale = 1,
    bool intro = false,
    bool training = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    late RegunGame game;
    await tester.runAsync(() async {
      await LocalPreferences.shared.load();
      if (completedIntro) await LocalPreferences.shared.completeTraining();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: const Key('capture'),
              child: BaseView(
                loadout: Loadout(training: training),
                showTrainingIntro: intro,
              ),
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
      game.update(2);
      await game.ready();
    });
    await tester.pump();
    return game;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'upgrade rows align card edges and Ban actions with unequal copy',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const choices = [
        PowerUp.closeQuarters,
        PowerUp.executioner,
        PowerUp.grenadeDamage,
      ];
      for (final layout in [
        (const Size(844, 390), 1.0),
        (const Size(568, 320), 1.5),
      ]) {
        tester.view.physicalSize = layout.$1;
        final game = await mount(tester, scale: layout.$2);
        final snapshot = game.gameNotifier.checkpoint();
        final state = snapshot['state'] as Map<String, dynamic>;
        state['gameplayState'] = 'powerup';
        state['powerUpChoices'] = choices.map((p) => p.name).toList();
        state['bans'] = 2;
        game.gameNotifier.restoreCheckpoint(snapshot);
        game.resumeGame();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Primary shots hit harder below 35% enemy health.'),
          findsOneWidget,
        );
        expect(find.text('LESS DETAIL'), findsWidgets);
        final cards = [
          for (final choice in choices)
            tester.getRect(
              find.byKey(ValueKey('upgrade-card-${choice.title}')),
            ),
        ];
        final bans = [
          for (final choice in choices)
            tester.getRect(
              find.descendant(
                of: find.byKey(ValueKey('upgrade-card-${choice.title}')),
                matching: find.text('BAN'),
              ),
            ),
        ];
        for (var i = 0; i < cards.length; i++) {
          expect(cards[i].left, greaterThanOrEqualTo(0));
          expect(cards[i].right, lessThanOrEqualTo(layout.$1.width));
          for (var j = i + 1; j < cards.length; j++) {
            if ((cards[i].top - cards[j].top).abs() < 1) {
              expect(cards[i].bottom, closeTo(cards[j].bottom, .01));
              expect(bans[i].bottom, closeTo(bans[j].bottom, .01));
            }
          }
        }
        if (layout.$2 == 1) {
          expect(cards[0].top, cards[2].top);
          await capture(tester, 'upgrade-aligned');
        } else {
          await tester.ensureVisible(find.text('REROLL (2)'));
          await tester.pump();
          expect(find.text('REROLL (2)').hitTestable(), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'normal offers explain effects; Details never buys and stays reachable at large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final layout in [
        (const Size(844, 390), 1.0),
        (const Size(568, 320), 1.5),
      ]) {
        tester.view.physicalSize = layout.$1;
        final game = await mount(tester, scale: layout.$2, training: false);
        final snapshot = game.gameNotifier.checkpoint();
        final state = snapshot['state'] as Map<String, dynamic>;
        state['gameplayState'] = 'powerup';
        state['powerUpChoices'] = ['heavyLoad', 'scavenger', 'fastReload'];
        game.gameNotifier.restoreCheckpoint(snapshot);
        game.resumeGame();
        await tester.pump();
        expect(find.text('Primary shots deal more damage.'), findsOneWidget);
        expect(find.text('Damage bonus 0% to 35%'), findsOneWidget);
        expect(find.text('Primary 1x to 1.35x'), findsNothing);
        final card = find.byKey(const ValueKey('upgrade-card-Heavy Load'));
        final details = find.descendant(
          of: card,
          matching: find.text('DETAILS'),
        );
        await tester.ensureVisible(details);
        await tester.tap(details);
        await tester.pump();
        expect(find.text('Primary 1x to 1.35x'), findsOneWidget);
        expect(game.gameState.rank(PowerUp.heavyLoad), 0);
        expect(game.gameState.gameplayState, GameplayState.powerup);
        expect(game.gameState.powerUpChoices.length, 3);
        if (layout.$2 == 1) await capture(tester, 'upgrade-details');
        final less = find.descendant(
          of: card,
          matching: find.text('LESS DETAIL'),
        );
        await tester.ensureVisible(less);
        await tester.tap(less);
        await tester.pump();
        expect(find.text('Primary 1x to 1.35x'), findsNothing);
        if (layout.$2 == 1) await capture(tester, 'upgrade-simple');
        await tester.ensureVisible(find.text('REROLL (2)'));
        await tester.pump();
        expect(find.text('REROLL (2)').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'returning training skips tutorial clutter; pause actions stay pinned with animated weapon art',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = await mount(tester, completedIntro: true, intro: true);
      expect(find.byType(TrainingNotice), findsNothing);
      expect(find.text('SKIP'), findsNothing);
      expect(find.text('READY'), findsNothing);
      expect(find.text(game.trainingHint), findsNothing);
      game.pauseGame();
      await tester.pump();
      expect(find.text('CONTROLS'), findsNothing);
      expect(find.byType(PracticeSection), findsNWidgets(5));
      expect(find.byType(WeaponPracticeTile), findsNothing);
      expect(find.text('START RUSH'), findsNothing);
      final menuRect = tester.getRect(find.byKey(const Key('pause-menu-home')));
      expect(menuRect.top, lessThan(70));
      await capture(tester, 'training-pause-collapsed');
      await tester.runAsync(() async {
        await tester.tap(find.text('WEAPON PRACTICE'));
        await tester.pump();
      });
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      expect(find.byType(WeaponThumbnail), findsNWidgets(21));
      expect(
        RegunArt.shared.contains(WeaponType.mourningBell.atlasName),
        isTrue,
      );
      expect(RegunArt.shared.decodedBytes, lessThanOrEqualTo(32 * 1024 * 1024));
      await capture(tester, 'training-pause-weapons');
      final choice = find.byKey(const ValueKey('practice-weapon-mourningBell'));
      await tester.ensureVisible(choice);
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const Key('pause-menu-home'))),
        menuRect,
      );
      await tester.tap(choice);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      expect(game.loadout.weapon, WeaponType.mourningBell);
      expect(game.gameState.gameplayState, GameplayState.paused);
      await tester.ensureVisible(find.text('WEAPON PRACTICE'));
      await tester.pump();
      await tester.tap(find.text('WEAPON PRACTICE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pump();
      expect(find.byType(WeaponThumbnail), findsNothing);
      expect(
        RegunArt.shared.contains(WeaponType.anchorEngine.atlasName),
        isFalse,
      );
      expect(
        RegunArt.shared.contains(WeaponType.mourningBell.atlasName),
        isTrue,
      ); // Equipped gun retains its own lease.
      expect(RegunArt.shared.decodedBytes, lessThanOrEqualTo(32 * 1024 * 1024));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'practice sections fit compact/portrait and large text; reduced motion collapses immediately',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [const Size(568, 320), const Size(390, 844)]) {
        tester.view.physicalSize = const Size(568, 320);
        final game = await mount(tester, scale: 1.5);
        LocalPreferences.shared.reducedMotion = true;
        game.pauseGame();
        await tester.pump();
        tester.view.physicalSize = size;
        await tester.pump();
        for (final label in [
          'WEAPON PRACTICE',
          'SURVIVAL PRACTICE',
          'SUPPLY PRACTICE',
          'BOSS PRACTICE',
          'FUSION PRACTICE',
        ]) {
          await tester.ensureVisible(find.text(label));
          await tester.pump();
          await tester.tap(find.text(label));
          await tester.pump();
          expect(
            find.byKey(const Key('pause-menu-home')).hitTestable(),
            findsOneWidget,
          );
          expect(find.text('RESUME').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull, reason: '$size $label');
          await tester.ensureVisible(find.text(label));
          await tester.pump();
          await tester.tap(find.text(label));
          await tester.pump();
        }
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'shared settings and controls have separated rows, values and reachable actions',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: const MaterialApp(
            home: RepaintBoundary(key: Key('capture'), child: SettingsView()),
          ),
        ),
      );
      await tester.pump();
      await capture(tester, 'settings-audio-layout');
      await tester.tap(find.text('CONTROLS'));
      await tester.pumpAndSettle();
      expect(find.byType(ControlsView), findsOneWidget);
      expect(
        tester.getRect(find.text('Sticks')).top -
            tester.getRect(find.text('Aim hand')).bottom,
        greaterThanOrEqualTo(16),
      );
      final sliders = find.byType(ControlSlider);
      await tester.ensureVisible(sliders.first);
      await tester.pump();
      expect(tester.getSize(sliders.first).height, greaterThanOrEqualTo(68));
      await tester.ensureVisible(find.text('Side inset'));
      await tester.pump();
      // Route screenshots use the root boundary, including the pushed settings route.
      final root = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      await tester.runAsync(() async {
        final image = await root.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('build/test-previews/controls-spaced-layout.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.ensureVisible(find.text('DONE'));
      await tester.pump();
      expect(find.text('DONE').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
