import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/systems/arena_bounds.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/systems/obstacle_router.dart';
import 'package:regun/systems/supply_drops.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Quiet extends SoloudPlay {
  final sounds = <String>[];
  @override
  Future<void> play(String asset) async {
    sounds.add(asset);
  }

  @override
  Future<void> playMusic(String theme) async {}
  @override
  void pauseMusic(bool paused) {}
}

void main() {
  for (final radius in [30.0, 45.0, 52.0]) {
    test(
      'body radius $radius routes from each pod face without crossing or teleporting',
      () {
        final pod = SupplyDrop(Offset.zero)..phase = SupplyPhase.active;
        final geometry = ArenaGeometry(
          const ArenaBounds(Rect.fromLTWH(-1000, -1000, 2000, 2000)),
          obstacles: [],
          dynamicObstacles: () => [pod.footprint],
        );
        for (final axis in [
          Vector2(1, 0),
          Vector2(-1, 0),
          Vector2(0, 1),
          Vector2(0, -1),
        ]) {
          for (final side in [-1.0, 1.0]) {
            final center = Vector2(0, -26);
            final body = PositionComponent(
              position: center - axis * 100,
              size: Vector2.all(100),
            );
            geometry.constrain(body.position, radius);
            final target = center + axis * 300;
            final router = ObstacleRouter();
            for (
              var frame = 0;
              frame < 600 && body.position.distanceTo(target) > 4;
              frame++
            ) {
              final before = body.position.clone();
              final desired = (target - before).normalized();
              final direction = router.steer(
                body,
                desired,
                target,
                geometry,
                radius: radius,
                side: side,
              );
              geometry.move(body.position, direction * (90 / 60), radius);
              expect(
                body.position.distanceTo(before),
                lessThanOrEqualTo(1.501),
              );
              expect(
                pod.footprint
                    .inflate(radius - .01)
                    .contains(body.position.toOffset()),
                isFalse,
              );
            }
            expect(
              body.position.distanceTo(target),
              lessThan(5),
              reason: '$axis / $side',
            );
          }
        }
      },
    );
  }

  test('routing uses the open side near a fence and releases after a pod disappears', () {
    final pod = SupplyDrop(const Offset(-840, 0))..phase = SupplyPhase.active;
    var solid = true;
    final geometry = ArenaGeometry(
      const ArenaBounds(Rect.fromLTWH(-1000, -1000, 2000, 2000)),
      obstacles: [],
      dynamicObstacles: () => solid ? [pod.footprint] : [],
    );
    final body = PositionComponent(position: Vector2(-840, -250));
    final target = Vector2(-840, 250), router = ObstacleRouter();
    for (
      var frame = 0;
      frame < 600 && body.position.distanceTo(target) > 4;
      frame++
    ) {
      final desired = (target - body.position).normalized();
      geometry.move(
        body.position,
        router.steer(body, desired, target, geometry, radius: 52, side: -1) *
            (90 / 60),
        52,
      );
    }
    expect(body.position.distanceTo(target), lessThan(5));
    body.position.setValues(-840, -250);
    router.steer(body, Vector2(0, 1), target, geometry, radius: 52, side: -1);
    solid = false;
    expect(
      router.steer(body, Vector2(0, 1), target, geometry, radius: 52, side: -1),
      Vector2(0, 1),
    );
  });

  for (final axis in [
    Vector2(1, 0),
    Vector2(-1, 0),
    Vector2(0, 1),
    Vector2(0, -1),
  ]) {
    test('pod detour can reach a player standing against the $axis fence', () {
      final pod = SupplyDrop(Offset.zero)..phase = SupplyPhase.active;
      final geometry = ArenaGeometry(
        const ArenaBounds(Rect.fromLTWH(-1000, -1000, 2000, 2000)),
        obstacles: [],
        dynamicObstacles: () => [pod.footprint],
      );
      final target = axis * 2000;
      geometry.constrain(target, 30);
      final body = PositionComponent(position: -axis * 250);
      final router = ObstacleRouter();
      for (
        var frame = 0;
        frame < 1200 && body.position.distanceTo(target) > 25;
        frame++
      ) {
        final desired = (target - body.position).normalized();
        geometry.move(
          body.position,
          router.steer(body, desired, target, geometry, radius: 52, side: 1) *
              (90 / 60),
          52,
        );
      }
      expect(body.position.distanceTo(target), lessThanOrEqualTo(25));
    });
  }

  testWidgets(
    'real Mummy pursuit rounds a solid pod; committed movement still stops at it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
            child: const MaterialApp(
              home: BaseView(loadout: Loadout(training: true)),
            ),
          ),
        );
        final game =
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
        game.supplyDrops.drop = SupplyDrop(Offset.zero)
          ..phase = SupplyPhase.active;
        game.myPlayer.position.setValues(320, -26);
        final enemy = Enemy2Component(position: Vector2(-320, -26));
        await game.world.add(enemy);
        await game.ready();
        for (var frame = 0; frame < 1200 && enemy.position.x < 180; frame++) {
          game.enemyTactics.rebuild([enemy]);
          game.crowdOccupancy.rebuild([enemy], game.crowdRadius);
          enemy.update(1 / 60);
          expect(
            game.supplyDrops.drop!.footprint
                .inflate(game.crowdRadius(enemy) - .01)
                .contains(enemy.position.toOffset()),
            isFalse,
          );
        }
        expect(enemy.position.x, greaterThan(180));
        enemy.position.setValues(-320, -26);
        game.crowdOccupancy.rebuild([enemy], game.crowdRadius);
        game.moveActor(enemy, Vector2(1, 0), 1050, 1, avoidCrowd: false);
        expect(enemy.position.x, lessThanOrEqualTo(-91));
        expect(
          enemy.position.y,
          -26,
          reason: 'Committed attacks do not steer around cover',
        );
        enemy.position.setValues(-100, -180);
        // Leave room beyond cover for sixteen non-overlapping bodies to gather
        // around the player; this tests passage rather than crowd compression.
        game.myPlayer.position.setValues(650, -26);
        final pack = <PositionComponent>[
          enemy,
          for (var i = 1; i < 16; i++)
            EnemyComponent(
              position: Vector2(-100 - (i % 4) * 105, -180 + (i ~/ 4) * 105),
            ),
        ];
        await game.world.addAll(pack.skip(1));
        await game.ready();
        for (var frame = 0; frame < 2400; frame++) {
          game.enemyTactics.rebuild(pack);
          game.crowdOccupancy.rebuild(pack, game.crowdRadius);
          for (final body in pack) {
            body.update(1 / 60);
            expect(
              game.supplyDrops.drop!.footprint
                  .inflate(game.crowdRadius(body) - .01)
                  .contains(body.position.toOffset()),
              isFalse,
            );
          }
        }
        expect(
          pack.every((body) => body.position.x > 91),
          isTrue,
          reason:
              'A pursuing pack must pass the pod, not queue against its face: ${pack.map((body) => body.position).toList()}',
        );
        await tester.pumpWidget(const SizedBox());
      });
      expect(tester.takeException(), isNull);
    },
  );
  for (final claimed in [false, true]) {
    testWidgets(
      'real ${claimed ? 'claimed' : 'expired'} breakdown blasts once and spares the player',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final audio = _Quiet();
        await tester.runAsync(() async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [soloudPlayProvider.overrideWithValue(audio)],
              child: const MaterialApp(
                home: BaseView(loadout: Loadout(training: true)),
              ),
            ),
          );
          final game =
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
          game.myPlayer.position.setValues(0, 160);
          game.supplyDrops.drop = SupplyDrop(Offset.zero);
          game.update(0);
          await Future<void>.delayed(const Duration(milliseconds: 150));
          await game.ready();
          final targets = [
            Enemy2Component(position: Vector2(0, 55))
              ..restoreHealth(30, maximum: 30),
            Enemy2Component(position: Vector2(180, 0))
              ..restoreHealth(30, maximum: 30),
            Enemy2Component(position: Vector2(300, 0))
              ..restoreHealth(30, maximum: 30),
            Enemy2Component(position: Vector2(450, 0))
              ..restoreHealth(30, maximum: 30),
          ];
          await game.world.addAll(targets);
          await game.ready();
          final hp = game.gameState.health;
          final drop = game.supplyDrops.drop!;
          drop.phase = claimed ? SupplyPhase.opened : SupplyPhase.active;
          drop.claimed = claimed;
          drop.elapsed = claimed ? 2.99 : 0;
          drop.life = claimed ? 8 : 49.99;
          game.pauseGame();
          game.update(4);
          expect(drop.phase, claimed ? SupplyPhase.opened : SupplyPhase.active);
          game.resumeGame();
          game.update(.02);
          await game.ready();
          expect(drop.phase, SupplyPhase.breaking);
          expect(targets[0].combatHealth.isDead, isTrue);
          expect(targets[1].combatHealth.current, 22);
          expect(targets[2].combatHealth.current, 30);
          expect(targets[3].combatHealth.current, 30);
          expect(game.gameState.health, hp);
          expect(audio.sounds.where((s) => s == 'blast.wav'), hasLength(1));
          final pressureX = targets[2].position.x;
          game.supplyDrops.restore(game.supplyDrops.toJson());
          game.update(.1);
          expect(targets[2].position.x, greaterThan(pressureX));
          expect(targets[1].combatHealth.current, 22);
          expect(audio.sounds.where((s) => s == 'blast.wav'), hasLength(1));
          expect(game.geometry.solids, isEmpty);
          await tester.pumpWidget(const SizedBox());
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}
