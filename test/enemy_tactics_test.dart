import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/game.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/components/enemies/enemy_3_component.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/systems/enemy_tactics.dart';

class _QuietAudio extends SoloudPlay {
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
  Vector2 intent(EnemyKind kind, double x, double y,
          {double side = 1, Vector2? velocity}) =>
      EnemyTactics.intent(kind, Vector2(x, y), Vector2.zero(),
          velocity ?? Vector2.zero(), side);

  test('flankers split sides but close directly at striking distance', () {
    for (final kind in [EnemyKind.scorpion, EnemyKind.runner]) {
      final left = intent(kind, 500, 0);
      final right = intent(kind, 500, 0, side: -1);
      expect(left.x, lessThan(0));
      expect(left.y * right.y, lessThan(0));
      expect(left.y.abs(), greaterThan(.3));
      expect(intent(kind, 75, 0).y, closeTo(0, .001));
    }
  });

  test('bruisers and bursters lead movement; shields keep a direct advance',
      () {
    for (final kind in [EnemyKind.mummy, EnemyKind.burster]) {
      final lead = intent(kind, 400, 0, velocity: Vector2(0, 300));
      expect(lead.x, lessThan(0));
      expect(lead.y, greaterThan(.1));
    }
    final shield = intent(EnemyKind.shield, 400, 0, velocity: Vector2(0, 300));
    expect(shield.y, 0);
    expect(shield.x, -1);
    // A huge target velocity cannot send the bruiser chasing across the arena.
    expect(intent(EnemyKind.mummy, 400, 0, velocity: Vector2(0, 100000)).y,
        lessThan(.3));
  });

  test('revenants retreat when rushed, strafe at range, and approach from afar',
      () {
    expect(intent(EnemyKind.ranged, 180, 0).x, greaterThan(0));
    expect(intent(EnemyKind.ranged, 700, 0).x, lessThan(0));
    final strafe = intent(EnemyKind.ranged, 355, 0);
    expect(strafe.x, closeTo(0, .001));
    expect(strafe.y.abs(), greaterThan(.5));
    for (final kind in [EnemyKind.nest, EnemyKind.sentinel]) {
      expect(intent(kind, 355, 0).isZero(), isTrue);
    }
  });

  test('ordinary enemies yield sideways before a boss reaches their body', () {
    final boss = Vector2.zero(), target = Vector2(800, 0);
    final upper = EnemyTactics.yieldToBoss(Vector2(350, 30), boss, target, 1)!;
    final lower =
        EnemyTactics.yieldToBoss(Vector2(350, -30), boss, target, -1)!;
    expect(upper.y, 1);
    expect(lower.y, -1);
    expect(upper.x, 0);
    expect(EnemyTactics.yieldToBoss(Vector2(-50, 0), boss, target, 1), isNull);
    expect(EnemyTactics.yieldToBoss(Vector2(500, 0), boss, target, 1), isNull);
    expect(
        EnemyTactics.yieldToBoss(Vector2(100, 150), boss, target, 1), isNull);
  });

  test('overlapping spawns separate deterministically without teleporting', () {
    final tactics = EnemyTactics();
    final a =
        PositionComponent(position: Vector2(500, 0), size: Vector2.all(85));
    final b =
        PositionComponent(position: Vector2(500, 0), size: Vector2.all(85));
    tactics.rebuild([a, b]);
    final first = tactics.spaced(a, Vector2(-1, 0));
    final second = tactics.spaced(b, Vector2(-1, 0));
    expect(first.distanceTo(second), greaterThan(.5));
    expect(first.length, lessThanOrEqualTo(1.00001));
    expect(second.length, lessThanOrEqualTo(1.00001));
    tactics.rebuild([b, a]);
    expect(
        tactics.spaced(a, Vector2(-1, 0)).distanceTo(first), closeTo(0, .001));
    expect(tactics.side(a), -tactics.side(b));
  });

  test(
      'crowd spreads while continuing to close in, with local neighbor queries',
      () {
    final tactics = EnemyTactics();
    final crowd = [
      for (var i = 0; i < 16; i++)
        PositionComponent(
            position: Vector2(600, (i - 7.5) * 8), size: Vector2.all(85))
    ];
    double nearestMean() =>
        crowd
            .map((a) => crowd
                .where((b) => b != a)
                .map((b) => a.position.distanceTo(b.position))
                .reduce((a, b) => a < b ? a : b))
            .reduce((a, b) => a + b) /
        crowd.length;
    final before = nearestMean();
    for (var tick = 0; tick < 360; tick++) {
      tactics.rebuild(crowd);
      for (final actor in crowd) {
        final desired = EnemyTactics.intent(EnemyKind.scorpion, actor.position,
            Vector2.zero(), Vector2.zero(), tactics.side(actor));
        actor.position.addScaled(tactics.spaced(actor, desired), 60 / 60);
      }
    }
    expect(nearestMean(), greaterThan(before * 2));
    expect(crowd.every((a) => a.position.x < 500), isTrue);
    final scattered = [
      for (var i = 0; i < 120; i++)
        PositionComponent(
            position: Vector2((i % 12 - 6) * 180.0, (i ~/ 12 - 5) * 180.0),
            size: Vector2.all(85))
    ];
    tactics.rebuild(scattered);
    for (final actor in scattered) {
      tactics.spaced(actor, Vector2(-1, 0));
    }
    expect(tactics.neighborChecks, lessThan(120 * 119 ~/ 10));
    tactics.clear();
    expect(tactics.spaced(scattered.first, Vector2(-1, 0)).x, -1);
  });
  test('a sustained pursuit does not compress bodies into one dense clump', () {
    final tactics = EnemyTactics();
    final crowd = [
      for (var i = 0; i < 40; i++)
        PositionComponent(
            position: Vector2(500 + (i % 5) * 18.0, (i ~/ 5 - 4) * 14.0),
            size: Vector2.all(85))
    ];
    for (var tick = 0; tick < 1200; tick++) {
      final target = Vector2(-tick * .65, 0);
      tactics.rebuild(crowd);
      for (final actor in crowd) {
        final desired = EnemyTactics.intent(EnemyKind.scorpion, actor.position,
            target, Vector2(-39, 0), tactics.side(actor));
        final velocity = tactics.spaced(actor, desired);
        expect(velocity.length, lessThanOrEqualTo(1.00001));
        actor.position.addScaled(velocity, 1);
      }
    }
    final nearest = crowd
        .map((a) => crowd
            .where((b) => b != a)
            .map((b) => a.position.distanceTo(b.position))
            .reduce((a, b) => a < b ? a : b))
        .toList()
      ..sort();
    expect(nearest[nearest.length ~/ 2], greaterThan(65),
        reason: 'Most enemy bodies should remain individually readable');
    expect(nearest.where((gap) => gap < 45).length, lessThanOrEqualTo(4),
        reason:
            'Sustained chasing must not preserve a tightly overlapped core');
    expect(crowd.every((actor) => actor.position.x < 500), isTrue,
        reason: 'Spacing must preserve pursuit');
  });

  testWidgets(
      'live tactics preserve committed attacks and keep a pursuing crowd separate',
      (tester) async {
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
          overrides: [soloudPlayProvider.overrideWithValue(_QuietAudio())],
          child: const MaterialApp(
              home: RepaintBoundary(
                  key: Key('crowd-capture'),
                  child: BaseView(loadout: Loadout(training: true))))));
      game = tester
          .widget<RiverpodAwareGameWidget>(find.byType(RiverpodAwareGameWidget))
          .game! as RegunGame;
      await game.loaded;
      await tester.pump();
      await game.ready();
      game.update(2); // Finish deployment before exercising combat.
      game.myPlayer.position.setZero();
      final caster = Enemy3Component(position: Vector2(180, 0));
      final runner = ArenaEnemy(EnemyKind.runner, position: Vector2(200, 0));
      await game.world.add(caster);
      await game.ready();
      caster.update(.1);
      expect(caster.position.x, greaterThan(180),
          reason: 'Rush a caster and it retreats');
      caster.position.setValues(355, 0);
      caster.timeSinceLastAttack = 0;
      caster.update(2);
      expect(caster.isAttacking, isTrue);
      final planted = caster.position.clone();
      caster.update(.2);
      expect(caster.position, planted);
      expect(game.runtimeCounts['hostileProjectiles'], 0);
      caster.update(.21);
      await game.ready();
      expect(caster.isAttacking, isFalse);
      expect(game.runtimeCounts['hostileProjectiles'], 1);
      caster.removeFromParent();
      await game.ready();
      await game.world.add(runner);
      await game.ready();
      runner.clock = 1.3;
      runner.update(0);
      expect(runner.phase, 1);
      game.myPlayer.position.setValues(0, 300);
      runner.update(.56);
      expect(runner.phase, 2);
      final launch = runner.position.clone();
      runner.update(.1);
      expect(runner.position.x, lessThan(launch.x));
      expect(runner.position.y, closeTo(launch.y, .001),
          reason: 'Committed lunge must remain dodgeable');
      for (final enemy in game.liveEnemies.toList()) {
        enemy.removeFromParent();
      }
      await game.ready();
      game.myPlayer.position.setZero();
      final pack = [
        for (var i = 0; i < 40; i++) EnemyComponent(position: Vector2(400, 0))
      ];
      await game.world.addAll(pack);
      await game.ready();
      expect(pack.every((enemy) => enemy.parent == game.world), isTrue);
      for (var frame = 0; frame < 480; frame++) {
        game.myPlayer.position.setValues(-frame * .5, 0);
        game.update(1 / 60);
        if (frame % 60 != 0) continue;
        await game.ready();
        for (var a = 0; a < pack.length; a++) {
          for (var b = a + 1; b < pack.length; b++) {
            expect(
                pack[a].position.distanceTo(pack[b].position),
                greaterThanOrEqualTo(game.crowdRadius(pack[a]) +
                    game.crowdRadius(pack[b]) +
                    3.99),
                reason: 'Real enemy bodies must stay separate during pursuit');
          }
        }
      }
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('crowd-capture')));
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/crowd-spacing.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
