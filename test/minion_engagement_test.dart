import 'package:flame/components.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/game.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Audio extends SoloudPlay {
  @override
  Future<void> play(String name) async {}
  @override
  Future<void> playMusic(String name) async {}
  @override
  void pauseMusic(bool value) {}
}

class _Minion extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy {
  _Minion(double x)
    : super(
        position: Vector2(x, 0),
        size: Vector2.all(60),
        anchor: Anchor.center,
      );
  @override
  Future<void> onLoad() async {
    initializeHealth(5);
  }

  @override
  void onCombatDeath() {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<RegunGame> mount(
    WidgetTester tester, {
    Map<String, dynamic>? snapshot,
  }) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
          child: MaterialApp(
            home: BaseView(
              reviewControlledSpawns: true,
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
      game.pauseEngine();
      if (snapshot == null) {
        game.update(2);
        await game.ready();
      }
    });
    return game;
  }

  Future<void> ticks(
    WidgetTester tester,
    RegunGame game,
    double seconds,
  ) async {
    await tester.runAsync(() async {
      for (var i = 0; i < (seconds * 120).ceil(); i++) {
        game.update(1 / 120);
        if (i % 30 == 0) await game.ready();
      }
      await game.ready();
    });
  }

  testWidgets(
    'Skitter crosses living minions, hits the player and still stops at cover',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = await mount(tester);
      await ticks(tester, game, 6);
      game.myPlayer.position.setValues(300, 0);
      final runner = ArenaEnemy(EnemyKind.runner, position: Vector2.zero());
      final a = _Minion(120), b = _Minion(220);
      await tester.runAsync(() async {
        game.world.addAll([runner, a, b]);
        await game.ready();
      });
      runner.position.setZero();
      a.position.setValues(120, 0);
      b.position.setValues(220, 0);
      runner.phase = 2;
      runner.clock = 0;
      final hp = game.gameState.health;
      await ticks(tester, game, .31);
      expect(runner.position.x, greaterThan(300));
      expect(runner.phase, 3);
      expect(game.gameState.health, hp - 1);
      expect(a.combatHealth.current, 5);
      expect(b.combatHealth.current, 5);
      expect(a.position.x, 120);
      expect(b.position.x, 220);
      // Recoil/pressure movement must not reserve a landing space mid-flight.
      runner.phase = 2;
      runner.position.setValues(120, 0);
      game.moveTo(runner, Vector2(130, 0), game.crowdRadius(runner));
      expect(runner.position.x, 130);
      expect(runner.position.y, 0);
      // A resumed airborne jump retains cover collision.
      const wall = Rect.fromLTRB(160, -200, 180, 200);
      final original = game.geometry;
      game.geometry = ArenaGeometry(original.bounds, obstacles: [wall]);
      runner.position.setZero();
      runner.phase = 2;
      runner.clock = 0;
      await ticks(tester, game, .31);
      expect(
        runner.position.x,
        lessThanOrEqualTo(160 - game.crowdRadius(runner)),
      );
      game.geometry = original;
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'mummy walks until melee, opens with a .3s strike, then hits only in reach',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = await mount(tester);
      await ticks(tester, game, 6);
      game.myPlayer.position.setZero();
      final mummy = Enemy2Component(position: Vector2(130, 0));
      await tester.runAsync(() async {
        await game.world.add(mummy);
        await game.ready();
      });
      mummy.position.setValues(130, 0);
      final hp = game.gameState.health;
      await ticks(tester, game, .6);
      expect(mummy.isAttacking, false);
      expect(mummy.position.x, closeTo(73, 1));
      expect(
        game.gameState.health,
        hp,
        reason: 'no attack pose or damage while still approaching',
      );
      await ticks(tester, game, .5);
      expect(mummy.isAttacking, true);
      expect(
        game.gameState.health,
        hp,
        reason: 'opening strike still winds up after contact',
      );
      await ticks(tester, game, .25);
      expect(
        game.gameState.health,
        hp - 1,
        reason: 'opening strike lands .3s after reaching melee',
      );
      game.myPlayer.position.setValues(-500, 0);
      await ticks(tester, game, .1);
      expect(mummy.isAttacking, false);
      expect(mummy.timeSinceLastAttack, 0);
      const wall = Rect.fromLTRB(-50, -200, -40, 200);
      final original = game.geometry;
      game.geometry = ArenaGeometry(original.bounds, obstacles: [wall]);
      mummy.position.setValues(10, 0);
      game.myPlayer.position.setValues(-60, 0);
      final protected = game.gameState.health;
      await ticks(tester, game, .7);
      expect(game.gameState.health, protected);
      game.geometry = original;
      await tester.pumpWidget(const SizedBox());
    },
  );
}
