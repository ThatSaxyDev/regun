import 'package:flame/components.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/walker_boss.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/game.dart';
import 'package:regun/systems/walker_combat.dart';
import 'package:regun/models/run_checkpoint.dart';
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
    'grounded Walker blocks minions, rush flies over them and landing kills without rewards',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = await mount(tester);
      await tester.runAsync(() async {
        game.spawnBoss(BossKind.walker);
        expect(
          RunCheckpoint.valid(game.checkpoint()),
          isTrue,
          reason: 'arrival autosave before atlas load',
        );
        await game.ready();
      });
      await ticks(tester, game, 3.5);
      final boss = game.activeBoss! as WalkerBoss;
      boss.rig.carryTo(Offset.zero);
      boss.position.setZero();
      boss.rig.yaw = boss.rig.desiredYaw = 0;
      final path = _Minion(250), land = _Minion(750);
      await tester.runAsync(() async {
        game.world.addAll([path, land]);
        await game.ready();
      });
      final hp = path.combatHealth.current;
      game.crowdOccupancy.rebuild(game.liveEnemies, game.crowdRadius);
      game.moveTo(path, Vector2.zero(), 30);
      expect(
        path.position.length,
        greaterThanOrEqualTo(88 + game.crowdRadius(path)),
      );
      path.position.setValues(250, 0);
      game.myPlayer.position.setValues(-800, -800);
      boss.fight.phase = WalkerPhase.chargeLock;
      boss.fight.clock = 1.44;
      boss.fight.locked = const Offset(540, 0);
      boss.fight.chargeDirection = const Offset(1, 0);
      final kills = game.gameState.kills, xp = game.gameState.xP;
      await ticks(tester, game, .5);
      expect(path.combatHealth.current, hp);
      expect(land.combatHealth.isDead, isFalse);
      await ticks(tester, game, .8);
      expect(path.combatHealth.current, hp);
      expect(land.combatHealth.isDead, isTrue);
      expect(game.gameState.kills, kills);
      expect(game.gameState.xP, xp);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'normal Walker resumes its mechanical fight and pays one victory after destruction',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var game = await mount(tester);
      for (var i = 0; i < 20; i++) {
        game.gameNotifier.healthIncrease();
      }
      await tester.runAsync(() async {
        game.spawnBoss(BossKind.walker);
        expect(
          RunCheckpoint.valid(game.checkpoint()),
          isTrue,
          reason: 'arrival autosave before atlas load',
        );
        await game.ready();
      });
      var boss = game.activeBoss! as WalkerBoss;
      expect(game.walkerTrial, isFalse);
      expect(game.bossReveal.active, isFalse);
      await ticks(tester, game, 4);
      expect(boss.fight.vulnerable, isTrue);
      boss.takeDamage(20);
      final hp = boss.combatHealth.current;
      expect(
        WalkerCombat.validState(boss.fight.toJson()),
        isTrue,
        reason: 'fight snapshot',
      );
      final saved = game.checkpoint();
      expect(
        (saved['enemies'] as List).where((e) => e['kind'] == 'walker').length,
        1,
        reason: 'one Walker body record',
      );
      expect(RunCheckpoint.valid(saved), isTrue);
      final age = boss.fight.elapsed;
      game = await mount(tester, snapshot: saved);
      boss = game.activeBoss! as WalkerBoss;
      expect(boss.combatHealth.current, hp);
      expect(boss.fight.elapsed, age);
      expect(game.bossReveal.active, isFalse);
      game.resumeGame();
      game.myPlayer.position.setValues(-800, -800);
      expect(boss.takeDamage(100000), isTrue);
      await ticks(tester, game, 1.2);
      expect(game.gameState.bosses, 0);
      expect(game.gameState.pendingCores, 0);
      final dying = game.checkpoint();
      expect(RunCheckpoint.valid(dying), isTrue);
      game = await mount(tester, snapshot: dying);
      boss = game.activeBoss! as WalkerBoss;
      expect(boss.combatHealth.current, 0);
      expect(boss.fight.defeated, isTrue);
      game.resumeGame();
      await ticks(tester, game, 4.2);
      expect(game.gameState.bosses, 1);
      expect(game.gameState.pendingCores, 1);
      expect(game.bossWinCounts, {'walker': 1});
      expect(game.activeBoss, isNull);
      final score = game.gameState.score;
      await ticks(tester, game, .5);
      expect(game.gameState.score, score);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'old active Mirror Saint checkpoint continues as Walker without losing the build',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var game = await mount(tester);
      await tester.runAsync(() async {
        game.spawnBoss(BossKind.shadow);
        await game.ready();
      });
      await ticks(tester, game, 3);
      final saved = game.checkpoint();
      final enemy = (saved['enemies'] as List).first as Map;
      enemy['kind'] = 'saint';
      enemy['health'] = 100.0;
      enemy['maximum'] = 300.0;
      expect(RunCheckpoint.valid(saved), isTrue);
      game = await mount(tester, snapshot: saved);
      expect(game.activeBoss, isA<WalkerBoss>());
      expect((game.activeBoss as WalkerBoss).combatHealth.current, 100);
      expect((game.checkpoint()['enemies'] as List).first['kind'], 'walker');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
