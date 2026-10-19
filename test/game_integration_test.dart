import 'package:regun/components/enemies/shadow_boss_component.dart';
import 'package:regun/components/enemies/shadow_projectile.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/components/game_utils/empty_component.dart';
import 'package:regun/components/game_utils/coin_component.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_3_component.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/game.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

class SilentAudio extends SoloudPlay {
  @override
  Future<void> play(String assetPath) async {}
}

void main() {
  testWidgets(
      'native game scene mounts, pauses for upgrades, clamps and restarts',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late RegunGame game;
    const capture = Key('game-capture');
    await tester.runAsync(() async {
      final pixelFont = FontLoader('PressStart2P')
        ..addFont(rootBundle.load('assets/fonts/PressStart2P-Regular.ttf'));
      await pixelFont.load();
      final hudFont = FontLoader('Orbitron')
        ..addFont(rootBundle.load('assets/fonts/Orbitron-Bold.ttf'));
      await hudFont.load();
      await tester.pumpWidget(ProviderScope(
        overrides: [soloudPlayProvider.overrideWithValue(SilentAudio())],
        child: MaterialApp(
            theme: ThemeData.dark(),
            home: const RepaintBoundary(key: capture, child: BaseView())),
      ));
      game = tester
          .widget<RiverpodAwareGameWidget>(find.byType(RiverpodAwareGameWidget))
          .game! as RegunGame;
      await game.loaded.timeout(const Duration(seconds: 15));
      await tester.pump();
      await game.ready().timeout(const Duration(seconds: 15));
    });
    Future<void> screenshot(String name) async {
      await tester.pump();
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await screenshot('survival-hud');
    game.pauseGame();
    await tester.pump();
    await tester.tap(find.text('CONTROLS'));
    await tester.pump();
    await screenshot('control-settings');
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(find.text('LEFT'));
    await tester.pump();
    expect(game.controls.leftHanded, isTrue);
    await screenshot('control-settings-left');
    await tester.tap(find.text('RIGHT'));
    await tester.pump();
    expect(game.controls.leftHanded, isFalse);
    await tester.tap(find.text('DONE'));
    await tester.pump();
    game.resumeGame();

    expect(game.myPlayer.isMounted, isTrue);
    expect(game.boostButtonComponent.parent, game.camera.viewport);
    expect(game.reloadButtonComponent.parent, game.camera.viewport);
    expect(game.map.size.x, 4512);
    final notifier = game.gameNotifier;
    for (var i = 0; i < 7; i++) {
      notifier.increaseXP();
    }
    expect(game.paused, isFalse);
    expect(game.timeScale, 0.1);
    final slowEnemy = EnemyComponent(position: Vector2(-500, 0));
    await tester.runAsync(() async {
      await game.world.add(slowEnemy);
      await game.ready();
    });
    await screenshot('upgrade-cards');
    final start = slowEnemy.position.clone();
    game.update(1);
    // Scorpion speed is 60 units/sec: one real second advances only 6 units.
    expect(slowEnemy.position.distanceTo(start), closeTo(6, 0.001));
    expect(game.gameState.health, 6);
    final offers = game.gameState.powerUpChoices;
    notifier.applyPowerUp(offers.first);
    expect(game.paused, isFalse);
    expect(game.timeScale, 1);
    game.myPlayer.position.setValues(-9999, 9999);
    game.update(1 / 60);
    expect(game.map.bounds.floor.contains(game.myPlayer.position.toOffset()),
        isTrue);
    expect(
        game.camera.viewfinder.position,
        game.map.bounds.cameraPosition(
            game.myPlayer.position, game.camera.viewport.virtualSize));
    expect(game.camera.visibleWorldRect.left,
        greaterThanOrEqualTo(game.map.bounds.rect.left));
    expect(game.camera.visibleWorldRect.bottom,
        lessThanOrEqualTo(game.map.bounds.rect.bottom));
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      game.render(ui.Canvas(recorder));
      final picture = recorder.endRecording();
      final image = await picture.toImage(844, 390);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/game-controls.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    });
    // Retain no placeholder components when the firing timer ticks while idle.
    for (var i = 0; i < 120; i++) {
      game.update(1 / 60);
    }
    expect(game.world.children.whereType<EmptyComponent>(), isEmpty);
    game.restartGame();
    await tester
        .runAsync(() => game.ready().timeout(const Duration(seconds: 15)));
    expect(game.gameState.currentLevel, 1);
    expect(game.gameState.reloading, isFalse);
    expect(game.world.children.whereType<EnemyComponent>(), isEmpty);
    expect(game.world.children.whereType<BulletComponent>(), isEmpty);
    expect(game.myPlayer.isMounted, isTrue);
    // Actual damage, delayed death and conserved rewards across a full drop pool.
    final bruiser = Enemy2Component(position: Vector2(500, 0));
    await tester.runAsync(() async {
      await game.world.add(bruiser);
      await game.ready();
    });
    expect(bruiser.takeDamage(1), isTrue);
    expect(bruiser.combatHealth.current, 5);
    expect(bruiser.isDying, isFalse);
    expect(bruiser.takeDamage(5), isTrue);
    expect(bruiser.isDying, isTrue);
    expect(game.gameState.kills, 1);
    expect(bruiser.takeDamage(10), isFalse);
    expect(game.gameState.kills, 1);
    for (var i = 0; i < 100; i++) {
      game.dropXP(Vector2(1200, 1200), 1);
    }
    await tester.runAsync(() => game.ready());
    final drops = game.world.children.whereType<CoinComponent>().toList();
    expect(drops.length, RegunGame.maxCoins);
    expect(drops.fold<int>(0, (sum, c) => sum + c.value), 103);

    game.spawnShadowBoss();
    await tester.runAsync(() => game.ready());
    final boss = game.shadowBoss!;
    expect(boss.phase, ShadowPhase.arrival);
    expect(boss.combatHealth.current, 140);
    await screenshot('shadow-arrival');
    expect(boss.takeDamage(80), isTrue);
    expect(boss.enraged, isTrue);
    game.gameNotifier.increaseXP(7);
    final phase = boss.phase;
    game.update(20);
    expect(boss.phase, phase); // Selection freezes the attack scheduler.
    game.gameNotifier.applyPowerUp(game.gameState.powerUpChoices.first);
    for (var i = 0; i < 8 * 60; i++) {
      game.update(1 / 60);
    }
    await tester.runAsync(() => game.ready());
    expect(game.world.children.whereType<ShadowProjectile>(), isNotEmpty);
    expect(boss.takeDamage(1000), isTrue);
    expect(game.gameState.bosses, 1);
    expect(boss.takeDamage(1000), isFalse);
    await tester.runAsync(() => game.ready());
    expect(game.shadowBoss, isNull);
    expect(game.world.children.whereType<ShadowProjectile>(), isEmpty);
    expect(game.director.bossActive, isFalse);

    game.gameOver();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/test-previews/results-buttons.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    game.restartGame();
    await tester.runAsync(() => game.ready());
    // Dense long-run simulation. Keep moving to avoid ending the test run;
    // this checks population bounds and entity lifecycle, not mobile frame rate.
    // Enough test health to keep the simulation running through contact hits.
    for (var i = 0; i < 1000; i++) {
      notifier.healthIncrease();
    }
    var peakEnemies = 0;
    var peakCoins = 0;
    await tester.runAsync(() async {
      for (var frame = 0; frame < 180 * 60; frame++) {
        final phase = frame / 60 * 0.45;
        game.myPlayer.position
            .setValues(math.cos(phase) * 1000, math.sin(phase) * 1000);
        if (frame > 120 * 60 && frame % 21 == 0) {
          game.weaponJoystick.delta.setValues(60, 0);
          game.spawnShotgunBullets();
        }
        if (game.gameState.powerUpChoices.isNotEmpty) {
          notifier.applyPowerUp(game.gameState.powerUpChoices.first);
        }
        game.update(1 / 60);
        if (frame % 60 == 0) {
          await game.ready().timeout(const Duration(seconds: 10));
          final count = game.world.children
              .where((c) =>
                  c is EnemyComponent ||
                  c is Enemy2Component ||
                  c is Enemy3Component)
              .length;
          peakEnemies = math.max(peakEnemies, count);
          peakCoins = math.max(
              peakCoins, game.world.children.whereType<CoinComponent>().length);
          expect(count, lessThanOrEqualTo(RegunGame.maxEnemies));
          expect(game.enemyPopulation.arena,
              lessThanOrEqualTo(game.director.populationLimit + 1),
              reason:
                  'Reinforcements include pending arrivals; a boss has its own slot');
          expect(peakCoins, lessThanOrEqualTo(RegunGame.maxCoins));
        }
      }
    });
    debugPrint(
        'DENSE SCENE: simulatedSeconds=180 peakEnemies=$peakEnemies peakCoins=$peakCoins retained=${game.world.children.length}');
    expect(peakEnemies, greaterThanOrEqualTo(20),
        reason: 'The scene must exercise a substantial active crowd');
    expect(peakEnemies, lessThanOrEqualTo(game.director.populationLimit));
    expect(peakCoins, lessThanOrEqualTo(RegunGame.maxCoins));
    expect(game.world.children.whereType<EmptyComponent>(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
