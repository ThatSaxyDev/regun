import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

class _Audio extends SoloudPlay {
  @override
  Future<void> play(String path) async {}
  @override
  Future<void> playMusic(String path) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool paused) {}
}

void main() {
  Future<RegunGame> mount(WidgetTester tester, {bool training = true}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late RegunGame game;
    await tester.runAsync(() async {
      for (final font in ['PressStart2P', 'Orbitron']) {
        await (FontLoader(font)
              ..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf')))
            .load();
      }
      await tester.pumpWidget(ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
          child: MaterialApp(
              home: RepaintBoundary(
                  key: const Key('entrance'),
                  child: BaseView(loadout: Loadout(training: training))))));
      game = tester
          .widget<RiverpodAwareGameWidget>(find.byType(RiverpodAwareGameWidget))
          .game! as RegunGame;
      await game.loaded;
      await tester.pump();
      await game.ready();
    });
    return game;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('entrance')));
      final picture = await boundary.toImage(pixelRatio: 2);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  }

  testWidgets(
      'deployment and training recovery share a paused, protected entrance',
      (tester) async {
    final game = await mount(tester);
    expect(game.playerEntrance.active, isTrue);
    expect(game.damagePlayer(), isFalse);
    game.update(.45);
    expect(game.playerEntrance.height, greaterThan(0));
    await capture(tester, 'player-deployment');
    game.update(2);
    expect(game.playerEntrance.active, isFalse);
    expect(game.damagePlayer(), isFalse); // Training defaults to protection.
    game.pauseGame();
    await tester.pump();
    await tester.tap(find.text('SURVIVAL PRACTICE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Take damage'), findsOneWidget);
    await tester.ensureVisible(find.text('ON'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ON'));
    expect(game.trainingDamage, isTrue);
    await capture(tester, 'training-damage-setting');
    game.resumeGame();
    game.myPlayer.position.setValues(900, 400);
    game.update(.01);
    final origin = game.myPlayer.position.clone();
    final camera = game.camera.viewfinder.position.clone();
    await tester.runAsync(() async {
      game.spawnBoss(BossKind.bellkeeper);
      await game.ready();
      game.update(3); // Recovery damage starts after the held boss reveal.

    });
    final boss = game.activeBoss!;
    final bossPosition = boss.position.clone();
    final elapsed = game.director.elapsed;
    expect(game.damagePlayer(amount: 100), isTrue);
    expect(game.gameState.health, 0);
    expect(game.gameState.gameplayState, GameplayState.playing);
    expect(game.playerEntrance.respawning, isTrue);
    expect(game.damagePlayer(), isFalse);
    game.update(.2);
    expect(game.myPlayer.position, origin);
    await capture(tester, 'player-fallen');
    game.update(.65);
    expect(game.camera.viewfinder.position.distanceTo(camera), greaterThan(0));
    expect(game.camera.viewfinder.position.length, greaterThan(0));
    expect(game.myPlayer.position, origin);
    expect(boss.position, bossPosition);
    expect(game.director.elapsed, elapsed);
    final age = game.playerEntrance.elapsed;
    game.pauseGame();
    game.update(2);
    expect(game.playerEntrance.elapsed, age);
    game.resumeGame();
    game.update(1.15);
    expect(game.myPlayer.position, Vector2.zero());
    expect(game.playerEntrance.active, isTrue);
    await capture(tester, 'player-return-landing');
    game.update(1);
    expect(game.playerEntrance.active, isFalse);
    expect(game.gameState.health, game.gameState.maxHealth);
    expect(game.activeBoss, same(boss));
    expect(game.gameState.noOfBullets, game.gameState.maxBullets);
    expect(game.damagePlayer(), isFalse); // Two seconds to leave the center.
    game.update(2.1);
    expect(game.damagePlayer(), isTrue);
    game.setTrainingDamage(false);
    expect(game.gameState.health, game.gameState.maxHealth);
    expect(game.damagePlayer(amount: 100), isFalse);
    game.restartGame();
    expect(game.playerEntrance.active, isTrue);
    expect(game.playerEntrance.respawning, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'reduced motion conceals relocation and normal deaths still end runs',
      (tester) async {
    final game = await mount(tester, training: false);
    game.update(2);
    game.setTrainingDamage(true);
    expect(game.trainingDamage, isFalse);
    expect(game.damagePlayer(amount: 100), isTrue);
    expect(game.gameState.gameplayState, GameplayState.gameOver);
    expect(game.playerEntrance.active, isFalse);
    await tester.runAsync(() async {
      game.restartGame();
      await game.ready();
    });
    game.update(2);
    // The same reduced-motion timeline is used by deployment and recovery.
    game.playerEntrance
        .begin(respawn: true, reducedMotion: true, camera: Vector2(900, 400));
    game.update(.3);
    expect(game.playerEntrance.height, 0);
    expect(game.playerEntrance.cameraProgress, 0);
    game.update(.15);
    expect(game.playerEntrance.cameraProgress, 1);
    game.update(2);
    expect(game.playerEntrance.active, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
