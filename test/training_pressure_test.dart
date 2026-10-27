import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/components/enemies/spawn_warning.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/systems/training_pressure.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
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

class _DelayedEnemy extends EnemyComponent {
  _DelayedEnemy(this.gate, Vector2 point) : super(position: point);
  final Completer<void> gate;
  @override
  Future<void> onLoad() async {
    await gate.future;
    await super.onLoad();
  }
}

void main() {
  test(
    'training budgets are bounded and do not accumulate frame/pause backlogs',
    () {
      for (final mode in TrainingPressure.values) {
        final clock = TrainingPressureClock();
        expect(clock.advance(0, mode), 0);
        expect(clock.advance(double.nan, mode), 0);
        expect(clock.advance(100, mode), mode.batch);
        expect(clock.advance(.001, mode), 0);
        clock.reset();
        expect(clock.advance(mode.interval, mode), mode.batch);
        expect(mode.arenaLimit, lessThanOrEqualTo(54));
      }
    },
  );
  Future<RegunGame> mount(
    WidgetTester tester, {
    ArenaType arena = ArenaType.breach,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late RegunGame game;
    await tester.runAsync(() async {
      await LocalPreferences.shared.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: MaterialApp(
            home: BaseView(loadout: Loadout(training: true, arena: arena)),
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
    return game;
  }

  Future<void> advance(RegunGame game, double seconds) async {
    for (var frame = 0; frame < (seconds * 60).round(); frame++) {
      game.update(1 / 60);
      if (frame % 6 == 0) await game.ready();
    }
    await game.ready();
  }

  for (final arena in ArenaType.values) {
    testWidgets(
      'Normal promptly supplies nearby targets; Light/Horde respect limits in ${arena.name}',
      (tester) async {
        final game = await mount(tester, arena: arena);
        expect(game.trainingPressure, TrainingPressure.normal);
        final counts = <TrainingPressure, int>{};
        await tester.runAsync(() async {
          for (final mode in TrainingPressure.values) {
            game.setTrainingPressure(mode);
            game.restartGame();
            await game.ready();
            game.update(2);
            await game.ready();
            expect(game.trainingPressure, mode);
            await advance(game, 10);
            counts[mode] = game.trainingNearbyEnemies;
            if (mode == TrainingPressure.normal) {
              for (final enemy
                  in game.liveEnemies.whereType<CombatEnemy>().toList()) {
                enemy.takeDamage(100000);
              }
              game.myPlayer.position.add(Vector2(1200, 0));
              game.constrainActor(game.myPlayer.position, 40);
              await game.ready();
              await advance(game, 8);
              expect(
                game.trainingNearbyEnemies,
                greaterThanOrEqualTo(16),
                reason:
                    'Normal refills targets near a moving player after a clear',
              );
            }

            expect(
              game.trainingNearbyEnemies,
              greaterThanOrEqualTo(
                mode == TrainingPressure.light
                    ? 6
                    : mode == TrainingPressure.normal
                    ? 16
                    : 28,
              ),
            );
            expect(
              game.runtimeCounts['enemies'],
              lessThanOrEqualTo(mode.arenaLimit),
            );
            game.pauseGame();
            if (mode == TrainingPressure.horde) {
              final kills = game.gameState.kills;
              game.setTrainingPressure(TrainingPressure.light);
              expect(game.runtimeCounts['enemies'], lessThanOrEqualTo(8));
              expect(
                game.gameState.kills,
                kills,
                reason: 'Lowering practice pressure is not a kill reward',
              );
              game.setTrainingPressure(mode);
            }
            final before = game.runtimeCounts['enemies'];
            await advance(game, 3);
            expect(game.runtimeCounts['enemies'], before);
            game.resumeGame();
          }
        });
        expect(
          counts[TrainingPressure.horde]!,
          greaterThan(counts[TrainingPressure.normal]!),
        );
        expect(
          counts[TrainingPressure.normal]!,
          greaterThan(counts[TrainingPressure.light]!),
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final arena in ArenaType.values) {
    testWidgets(
      'Training arrivals stay offscreen at center and arena corners in ${arena.name}',
      (tester) async {
        final game = await mount(tester, arena: arena);
        await tester.runAsync(() async {
          final floor = game.map.bounds.floor.deflate(100);
          final positions = [
            Vector2.zero(),
            Vector2(floor.left, floor.top),
            Vector2(floor.right, floor.top),
            Vector2(floor.left, floor.bottom),
            Vector2(floor.right, floor.bottom),
          ];
          for (final pressure in TrainingPressure.values) {
            for (final point in positions) {
              game.setTrainingPressure(pressure);
              game.restartGame();
              await game.ready();
              game.update(2);
              await game.ready();
              game.myPlayer.position.setFrom(point);
              game.constrainActor(game.myPlayer.position, 40);
              game.update(0);
              await game.ready();
              // This checks offscreen placement, not the probability of twelve
              // random candidate attempts succeeding in a one-second window.
              // Keep a reproducible non-vacuous sample at every corner/pressure.
              game.random.state = 61;
              final seen = game.liveEnemies.toSet();
              var arrivals = 0;
              for (var frame = 0; frame < 60; frame++) {
                game.update(1 / 60);
                await game.ready();
                for (final enemy in game.liveEnemies) {
                  if (!seen.add(enemy)) continue;
                  arrivals++;
                  expect(
                    game.camera.visibleWorldRect
                        .inflate(50)
                        .contains(enemy.position.toOffset()),
                    isFalse,
                    reason:
                        '${pressure.name} at $point must enter from offscreen',
                  );
                }
                expect(game.world.children.whereType<SpawnWarning>(), isEmpty);
              }
              expect(
                arrivals,
                greaterThan(0),
                reason:
                    'seed61 / ${pressure.name} at $point / ${game.enemyPopulation}',
              );
            }
          }
        });
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'individual boss preserves crowd; Rush clears enemies, pending arrivals and ordnance without rewards',
    (tester) async {
      final game = await mount(tester);
      await tester.runAsync(() async {
        game.setTrainingPressure(TrainingPressure.horde);
        await advance(game, 4);
        final crowd = game.liveEnemies.toSet();
        expect(crowd.length, greaterThan(20));
        game.practiceBoss(BossKind.shadow);
        await game.ready();
        expect(game.bosses.length, 1);
        expect(game.bossRush, isFalse);
        expect(game.liveEnemies.toSet().containsAll(crowd), isTrue);
        await advance(game, 1);
        final gate = Completer<void>();
        final delayed = _DelayedEnemy(
          gate,
          game.myPlayer.position + Vector2(600, 0),
        );
        game.world.add(delayed);
        final pending = EnemyComponent(
          position: game.myPlayer.position + Vector2(-450, 0),
        );
        game.registerEnemy(pending);
        final warning = SpawnWarning(game: game, enemy: pending);
        game.world.add(warning);
        game.addHostileArea(game.myPlayer.position + Vector2(500, 0));
        game.addMineAt(game.myPlayer.position + Vector2(400, 0));
        game.dropXP(game.myPlayer.position + Vector2(700, 0), 7);
        final kills = game.gameState.kills, xp = game.gameState.xP;
        game.startBossRush();
        gate.complete();
        await game.ready();
        await advance(game, 2);
        expect(game.bossRush, isTrue);
        expect(game.bosses, isNotEmpty);
        expect(game.trainingPressure, TrainingPressure.horde);
        expect(game.runtimeCounts['enemies'], 0);
        expect(game.runtimeCounts['xp'], 0);
        expect(game.runtimeCounts['mines'], 0);
        expect(game.world.children.whereType<SpawnWarning>(), isEmpty);
        expect(game.gameState.kills, kills);
        expect(game.gameState.xP, xp);
        game.setTrainingPressure(TrainingPressure.light);
        await advance(game, 1);
        expect(game.runtimeCounts['enemies'], 0);
        // Keep this pressure-recovery assertion independent of spawn-candidate luck.
        game.random.state = 61;
        game.practiceBoss(BossKind.demon);
        await game.ready();
        await advance(game, 10);
        expect(game.bossRush, isFalse);
        expect(game.bosses.length, 1);
        expect(game.trainingPressure, TrainingPressure.light);
        expect(game.trainingNearbyEnemies, greaterThanOrEqualTo(5));
        expect(
          game.liveEnemies.whereType<CombatEnemy>().where((e) => !e.isBoss),
          isNotEmpty,
        );
      });
      await tester.pumpWidget(const SizedBox());
    },
  );
}
