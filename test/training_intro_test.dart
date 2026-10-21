import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:regun/views/menu_view.dart';
import 'package:regun/widgets/training_notice.dart';

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
    SharedPreferences.setMockInitialValues({});
    for (final font in ['PressStart2P', 'Orbitron']) {
      await (FontLoader(font)
            ..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf')))
          .load();
    }
  });

  Future<RegunGame> firstPlay(WidgetTester tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await LocalPreferences.shared.load();
      await LocalPreferences.shared.resetProgress();
      await tester.pumpWidget(ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: RepaintBoundary(
              key: const Key('capture'), child: MaterialApp(
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(disableAnimations: true),
                    child: child!),
                home: const MenuView()))));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    for (var i = 0; i < 40 && find.text('PLAY').evaluate().isEmpty; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
    await tester.tap(find.text('PLAY'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final game = tester
          .widget<RiverpodAwareGameWidget>(find.byType(RiverpodAwareGameWidget))
          .game! as RegunGame;
      await game.loaded;
      await tester.pump();
      await game.ready();
    });
    await tester.pump(const Duration(milliseconds: 400));
    return tester
        .widget<RiverpodAwareGameWidget>(find.byType(RiverpodAwareGameWidget))
        .game! as RegunGame;
  }

  testWidgets('first Play explains training and holds the arena until Start',
      (tester) async {
    final game = await firstPlay(tester);
    expect(find.byType(TrainingNotice), findsOneWidget);
    expect(find.text('TRAINING MODE').hitTestable(), findsOneWidget);
    expect(find.text('SKIP TRAINING').hitTestable(), findsOneWidget);
    expect(game.gameState.gameplayState, GameplayState.paused);
    expect(find.text('RESUME'), findsNothing);
    game.update(10);
    expect(game.gameState.survivalSeconds, 0);
    expect(game.trainingStep, 0);
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('capture')));
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/training-intro-ingame.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.text('START TRAINING'));
    await tester.pump();
    expect(find.byType(TrainingNotice), findsNothing);
    expect(game.gameState.gameplayState, GameplayState.playing);
    expect(find.text('Move with the movement stick'), findsOneWidget);
    expect(LocalPreferences.shared.profile.tutorialComplete, isFalse);
    game.pauseGame();
    await tester.pump();
    expect(find.byType(TrainingNotice), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Skip training opens normal loadout and remembers the choice',
      (tester) async {
    await firstPlay(tester);
    await tester.tap(find.text('SKIP TRAINING'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.pumpAndSettle();
    expect(find.byType(LoadoutView), findsOneWidget);
    expect(
        tester.widget<LoadoutView>(find.byType(LoadoutView)).training, isFalse);
    expect(LocalPreferences.shared.profile.tutorialComplete, isTrue);
    expect(find.byType(BaseView), findsNothing);
    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.pump(const Duration(milliseconds: 400));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(LoadoutView), findsNothing);
    expect(find.text('PLAY').hitTestable(), findsOneWidget);
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LoadoutView), findsOneWidget);
    expect(find.byType(TrainingNotice), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('briefing fits compact landscape and enlarged text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(568, 320), const Size(844, 390)]) {
      tester.view.physicalSize = size;
      for (final scale in [1.0, 1.5]) {
        await tester.pumpWidget(ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
            child: MaterialApp(
                home: MediaQuery(
                    data: MediaQueryData(
                        size: size, textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                        backgroundColor: const Color(0xff141117),
                        body: RepaintBoundary(
                            key: const Key('capture'),
                            child: SafeArea(
                                minimum: const EdgeInsets.all(16),
                                child: Center(
                                    child: TrainingNotice(
                                        onStart: () {}, onSkip: () {})))))))));
        await tester.pump();
        await tester.ensureVisible(find.text('SKIP TRAINING'));
        expect(find.text('SKIP TRAINING').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (size.width == 844 && scale == 1) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('capture')));
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('build/test-previews').create(recursive: true);
            await File('build/test-previews/training-intro.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    }
  });
}
