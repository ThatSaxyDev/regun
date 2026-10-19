import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/game.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/components/enemies/enemy_3_component.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
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
  testWidgets(
      'live revenant retreats and plants to cast; lunges cannot track mid-charge',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_QuietAudio())],
          child: const MaterialApp(
              home: BaseView(loadout: Loadout(training: true)))));
      game = tester
          .widget<RiverpodAwareGameWidget>(find.byType(RiverpodAwareGameWidget))
          .game! as RegunGame;
      await game.loaded;
      await tester.pump();
      await game.ready();
      game.myPlayer.position.setZero();
      final caster = Enemy3Component(position: Vector2(180, 0));
      final runner = ArenaEnemy(EnemyKind.runner, position: Vector2(200, 0));
      await game.world.addAll([caster, runner]);
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
    });
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
