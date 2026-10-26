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
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/hostile_area.dart';
import 'package:regun/components/enemies/pattern_boss.dart';
import 'package:regun/components/enemies/shadow_boss_component.dart';
import 'package:regun/components/enemies/shadow_projectile.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

class _Silent extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool paused) {}
}

Future<RegunGame> mount(WidgetTester tester, {bool training = false}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(844, 390);
  tester.view.devicePixelRatio = 1;
  late RegunGame game;
  await tester.runAsync(() async {
    for (final font in [
      ('PressStart2P', 'PressStart2P-Regular.ttf'),
      ('Orbitron', 'Orbitron-Bold.ttf')
    ]) {
      await (FontLoader(font.$1)
            ..addFont(rootBundle.load('assets/fonts/${font.$2}')))
          .load();
    }
    await tester.pumpWidget(ProviderScope(
        overrides: [soloudPlayProvider.overrideWithValue(_Silent())],
        child: MaterialApp(
            key: UniqueKey(),
            home: RepaintBoundary(
                key: const Key('boss-capture'),
                child: BaseView(loadout: Loadout(training: training))))));
    game = tester
        .widget<RiverpodAwareGameWidget>(find.byType(RiverpodAwareGameWidget))
        .game! as RegunGame;
    await game.loaded;
    await tester.pump();
    await game.ready();
    game.update(2); // Finish deployment before exercising combat.
  });
  return game;
}

void main() {
  testWidgets('dash rejects boss, projectile and floor damage throughout movement', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = await mount(tester);
    final health = game.gameState.health;
    game.boostButtonComponent.tapped = true;
    game.gameNotifier.triggerSprintInvincibility();
    game.gameNotifier.advanceTime(.14);
    for (final cause in ['Chain Magistrate', 'Marshal laser', 'Revenant shot', 'Burning ground']) {
      expect(game.damagePlayer(amount: 3, cause: cause), isFalse);
    }
    expect(game.gameState.health, health);
    // Active movement remains immune even if notifier/frame order crosses expiry.
    game.gameNotifier.advanceTime(.02);
    expect(game.damagePlayer(cause: 'Chain Magistrate'), isFalse);
    game.boostButtonComponent.cancelDash();
    expect(game.damagePlayer(cause: 'Burning ground'), isTrue);
    expect(game.gameState.health, health-1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'training separates bosses and fusions and safely replaces practice bosses',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = await mount(tester, training: true);
    game.pauseGame();
    await tester.pumpAndSettle();
    expect(find.text('BOSS PRACTICE'), findsOneWidget);
    expect(find.text('FUSION PRACTICE'), findsOneWidget);
    expect(tester.getTopLeft(find.text('BOSS PRACTICE')).dy,
        lessThan(tester.getTopLeft(find.text('FUSION PRACTICE')).dy));
    await tester.runAsync(() async {
      game.practiceBoss(BossKind.demon);
      await game.ready();
      final old = game.activeBoss! as CombatEnemy;
      final earned = game.gameState.kills;
      game.pauseGame();
      game.practiceBoss(BossKind.queen);
      await game.ready();
      expect(old.combatHealth.isDead, isTrue);
      expect(game.activeBoss, isA<PatternBoss>());
      expect((game.activeBoss! as PatternBoss).kind, BossKind.queen);
      expect(game.gameState.kills, earned,
          reason: 'Replacing practice targets must not farm rewards');
    });
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'bosses pressure a straight retreat; committed attacks keep their facing and clean up',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final kind in BossKind.values.where((kind) => !kind.expansion)) {
      final game = await mount(tester);
      for (var i = 0; i < 30; i++) {
        game.gameNotifier.healthIncrease();
      }
      // Find a long obstacle-free lane so this measures attacks, not corner traps.
      Vector2? lane;
      for (var y = -1600; y <= 1400 && lane == null; y += 200) {
        for (var x = -1700; x <= -900; x += 200) {
          final rect =
              Rect.fromLTWH(x.toDouble(), y.toDouble() - 140, 2900, 280);
          if (game.geometry.obstacles
              .every((o) => !o.inflate(90).overlaps(rect))) {
            lane = Vector2(x.toDouble() + 100, y.toDouble());
            break;
          }
        }
      }
      expect(lane, isNotNull);
      game.random.state = 61;
      game.spawnBoss(kind);
      await tester.runAsync(() => game.ready());
      game.update(3); // Input starts after the held boss reveal returns.

      final boss = game.activeBoss!;
      boss.position.setFrom(lane!);
      game.myPlayer.position.setFrom(lane + Vector2(400, 0));
      final before = game.gameState.health;
      game.update(1 / 60);
      await tester.pump();
      final factor = game.canvasSize.y / game.camera.viewport.virtualSize.y;
      final inset =
          (game.canvasSize - game.camera.viewport.virtualSize * factor) / 2;
      final move = await tester.startGesture(
          (game.movementJoystick.position * factor + inset).toOffset());
      await move.moveBy(const Offset(20, 0));
      await move.moveBy(const Offset(60, 0));
      game.update(1 / 60);
      expect(game.movementJoystick.relativeDelta.x, greaterThan(.9));
      final retreatStart = game.myPlayer.position.clone();
      var sawAttack = false;
      await tester.runAsync(() async {
        for (var tick = 0; tick < 600; tick++) {
          // Isolate the retreat test from random adds obstructing the marked
          // lane; crowd/body interactions have separate live-scene coverage.
          for (final enemy in game.liveEnemies.toList()) {
            if (!identical(enemy, boss)) enemy.removeFromParent();
          }
          game.update(1 / 60);
          if (tick % 6 == 0) await game.ready();
          if (boss is PatternBoss && boss.phase == PatternBossPhase.active ||
              boss is ShadowBossComponent &&
                  [ShadowPhase.fan, ShadowPhase.dash, ShadowPhase.strike]
                      .contains(boss.phase)) {
            sawAttack = true;
          }
          if (game.gameState.health < before) break;
        }
      });
      expect(sawAttack, isTrue, reason: kind.name);
      expect(game.gameState.health, lessThan(before),
          reason:
              '${kind.name}: walking straight away must not neutralize the whole encounter');
      expect(game.myPlayer.position.x - retreatStart.x, greaterThan(250),
          reason: 'Verify a real sustained retreat, not a stationary target');
      await move.up();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('boss-capture')));
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/boss-revised-${kind.name}.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
        (boss as CombatEnemy).takeDamage(100000);
        for (var i = 0; i < 3; i++) {
          game.update(1 / 60);
          await game.ready();
        }
        expect(
            game.world.children
                .whereType<HostileArea>()
                .where((h) => h.ownerHealth?.isDead ?? false),
            isEmpty);
        expect(
            game.world.children
                .whereType<ShadowProjectile>()
                .where((p) => p.ownerHealth?.isDead ?? false),
            isEmpty);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'locked warnings allow escape and walking does not hold an attack pose',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final kind in [BossKind.demon, BossKind.queen]) {
      final game = await mount(tester);
      game.spawnBoss(kind);
      await tester.runAsync(() => game.ready());
      game.update(3); // Input starts after the held boss reveal returns.

      final boss = game.activeBoss! as PatternBoss;
      boss.position.setValues(-1000, -1400);
      game.myPlayer.position.setValues(-600, -1400);
      boss.update(1.51);
      boss.update(1.01);
      expect(boss.phase, PatternBossPhase.warning);
      final body = boss.children.whereType<SpriteAnimationComponent>().single;
      final facing = body.scale.x;
      final before = game.gameState.health;
      game.myPlayer.position.setFrom(boss.position + Vector2(-450, -500));
      boss.update(.35);
      body.update(
          .35); // Direct FSM stepping needs the child ticker stepped too.
      expect(body.scale.x, facing,
          reason: 'Attack cannot silently flip after its warning');
      expect(body.animationTicker!.currentIndex, greaterThan(0));
      boss.update(.7);
      expect(boss.phase, PatternBossPhase.active);
      boss.update(.2);
      await tester.runAsync(() => game.ready());
      for (var tick = 0; tick < 40; tick++) {
        for (final hazard
            in game.world.children.whereType<HostileArea>().toList()) {
          hazard.update(1 / 60);
        }
      }
      expect(game.gameState.health, before,
          reason: 'Leaving the locked warning must avoid the attack');
      boss.update(.61);
      expect(boss.phase, PatternBossPhase.recovery);
      boss.update(.9);
      boss.update(.1);
      expect(boss.phase, PatternBossPhase.approach);
      expect(body.animation!.loop, isTrue);
      expect(body.animationTicker!.totalDuration(),
          kind == BossKind.demon ? .64 : .56);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    }
  });

  test(
      'curated Queen impacts exclude incomplete final cells and retain full body height',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await RegunArt.shared.load();
    for (var pattern = 0; pattern < 3; pattern++) {
      for (final index in BossArt.impactFrames(BossKind.queen, pattern)) {
        expect(index % 8, lessThan(6));
        final pose = RegunArt.shared.sprite('bosses/queen', index);
        final idle = RegunArt.shared.sprite('bosses/queen', 0);
        expect(pose.srcSize.y / idle.srcSize.y, greaterThan(.85));
      }
    }
  });
}
