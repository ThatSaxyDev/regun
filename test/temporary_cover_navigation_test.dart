import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/systems/arena_bounds.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/systems/enemy_tactics.dart';
import 'package:regun/systems/obstacle_router.dart';
import 'package:regun/systems/supply_drops.dart';
import 'package:regun/systems/crowd_occupancy.dart';

void main() {
  for (final cover in <String, List<Rect>>{
    'pod': [const Rect.fromLTWH(-46, -52, 92, 52)],
    'sentry footprint': [const Rect.fromLTWH(-35, -44, 70, 44)],
    'adjacent temporary cover': [
      const Rect.fromLTWH(-46, -52, 92, 52),
      const Rect.fromLTWH(120, -44, 70, 44),
    ],
  }.entries) {
    test('crowded pursuit clears ${cover.key} with body-safe detours', () {
      for (final kind in [EnemyKind.scorpion, EnemyKind.mummy]) {
        final geometry = ArenaGeometry(
          const ArenaBounds(Rect.fromLTWH(-1000, -1000, 2000, 2000)),
          obstacles: cover.value,
        );
        final pack = [
          for (var y = 0; y < 4; y++)
            for (var x = 0; x < 4; x++)
              PositionComponent(
                position: Vector2(-100 - x * 105, -180 + y * 105),
                size: Vector2.all(100),
              ),
        ];
        final tactics = EnemyTactics(),
            crowd = CrowdOccupancy(),
            router = ObstacleRouter();
        final target = Vector2(320, -26);
        for (var frame = 0; frame < 2400; frame++) {
          tactics.rebuild(pack);
          crowd.rebuild(pack, (_) => 45);
          for (final actor in pack) {
            final desired = EnemyTactics.intent(
              kind,
              actor.position,
              target,
              Vector2.zero(),
              tactics.side(actor),
            );
            final direction = tactics.spaced(
              actor,
              router.steer(
                actor,
                desired,
                target,
                geometry,
                radius: 45,
                side: tactics.side(actor),
              ),
            );
            crowd.move(
              actor,
              direction * 1.5,
              radius: 45,
              constrain: (p) => geometry.constrain(p, 45),
              side: tactics.side(actor),
            );
          }
        }
        expect(
          pack
              .where((a) => a.position.x < -90)
              .map((a) => a.position.toString())
              .toList(),
          isEmpty,
          reason:
              '$kind trapped behind ${cover.key}; crowd=${pack.map((a) => a.position).toList()}',
        );
      }
    });
  }
  test(
    'sentry exact-contact pursuit escapes every face toward opposite targets',
    () {
      const base = Rect.fromLTWH(-35, -44, 70, 44);
      final geometry = ArenaGeometry(
        const ArenaBounds(Rect.fromLTWH(-1000, -1000, 2000, 2000)),
        obstacles: [],
        dynamicObstacles: () => [base],
      );
      final failures = <String>[];
      for (final kind in [
        EnemyKind.scorpion,
        EnemyKind.mummy,
        EnemyKind.runner,
      ]) {
        for (var a = 0; a < 32; a++) {
          final axis = Vector2(
            math.cos(a * math.pi / 16),
            math.sin(a * math.pi / 16),
          );
          final center = Vector2(0, -22);
          final actor = PositionComponent(position: center + axis * 20);
          geometry.constrain(actor.position, 45);
          final target = center - axis * 220;
          final router = ObstacleRouter();
          var lateTravel = 0.0;
          for (var frame = 0; frame < 900; frame++) {
            final before = actor.position.clone();
            final desired = EnemyTactics.intent(
              kind,
              before,
              target,
              Vector2.zero(),
              1,
            );
            final direction = router.steer(
              actor,
              desired,
              target,
              geometry,
              radius: 45,
              side: 1,
            );
            geometry.move(actor.position, direction * 1.5, 45);
            if (frame > 780) lateTravel += actor.position.distanceTo(before);
          }
          if (actor.position.distanceTo(target) > 100 && lateTravel < 2) {
            failures.add('$kind $a at ${actor.position}');
          }
        }
      }
      expect(failures, isEmpty);
    },
  );
  test('a tight crowd touching the sentry can escape toward the survivor', () {
    const base = Rect.fromLTWH(-35, -44, 70, 44);
    for (final radius in [30.0, 45.0, 52.0]) {
      final geometry = ArenaGeometry(
        const ArenaBounds(Rect.fromLTWH(-1000, -1000, 2000, 2000)),
        obstacles: [],
        dynamicObstacles: () => [base],
      );
      final pack = [
        for (var i = 0; i < 16; i++)
          PositionComponent(
            position:
                Vector2(0, -22) +
                Vector2(math.cos(i * math.pi / 8), math.sin(i * math.pi / 8)) *
                    80,
            size: Vector2.all(radius * 2),
          ),
      ];
      for (final actor in pack) {
        geometry.constrain(actor.position, radius);
      }
      final tactics = EnemyTactics(),
          crowd = CrowdOccupancy(),
          router = ObstacleRouter();
      // Match spawn/landing occupancy: actors cannot begin overlapping each other.
      for (final actor in pack) {
        expect(
          crowd.place(actor, radius, (p) => geometry.constrain(p, radius)),
          true,
        );
      }
      final target = Vector2(320, -22);
      final lateTravel = {for (final actor in pack) actor: 0.0};
      for (var frame = 0; frame < 720; frame++) {
        tactics.rebuild(pack);
        crowd.rebuild(pack, (_) => radius);
        for (final actor in pack) {
          final before = actor.position.clone();
          final direction = tactics.spaced(
            actor,
            router.steer(
              actor,
              (target - actor.position).normalized(),
              target,
              geometry,
              radius: radius,
              side: tactics.side(actor),
            ),
          );
          crowd.move(
            actor,
            direction * 1.5,
            radius: radius,
            constrain: (p) => geometry.constrain(p, radius),
            side: tactics.side(actor),
          );
          if (frame >= 600) {
            lateTravel[actor] =
                lateTravel[actor]! + actor.position.distanceTo(before);
          }
        }
      }
      expect(
        pack
            .where((a) => a.position.x < -90)
            .map((a) => '${a.position}, moved=${lateTravel[a]}')
            .toList(),
        isEmpty,
        reason: 'body $radius',
      );
    }
  });
  test(
    'pursuer chooses another side when living bodies block a sentry corner',
    () {
      const base = Rect.fromLTWH(-35, -44, 70, 44);
      final geometry = ArenaGeometry(
        const ArenaBounds(Rect.fromLTWH(-1000, -1000, 2000, 2000)),
        obstacles: [],
        dynamicObstacles: () => [base],
      );
      final blockers = [
        for (final x in [-150.0, -40.0, 70.0])
          PositionComponent(position: Vector2(x, -120), size: Vector2.all(116)),
      ];
      final actor = PositionComponent(
        position: Vector2(-200, -22),
        size: Vector2.all(100),
      );
      final target = Vector2(320, -22),
          crowd = CrowdOccupancy(),
          router = ObstacleRouter();
      for (var frame = 0; frame < 1200; frame++) {
        crowd.rebuild([...blockers, actor], (a) => a == actor ? 45 : 52);
        final direction = router.steer(
          actor,
          (target - actor.position).normalized(),
          target,
          geometry,
          radius: 45,
          side: 1,
        );
        crowd.move(
          actor,
          direction * 1.5,
          radius: 45,
          constrain: (p) => geometry.constrain(p, 45),
        );
      }
      expect(
        actor.position.distanceTo(target),
        lessThan(70),
        reason: 'stranded at ${actor.position}',
      );
    },
  );
  test(
    'flanking direction is checked even when the player sightline is clear',
    () {
      const rect = Rect.fromLTWH(-46, -52, 92, 52);
      final geometry = ArenaGeometry(
        const ArenaBounds(Rect.fromLTWH(-1000, -1000, 2000, 2000)),
        obstacles: [rect],
      );
      final actor = PositionComponent(position: Vector2(-100, 120));
      final target = Vector2(320, -26);
      final desired = EnemyTactics.intent(
        EnemyKind.scorpion,
        actor.position,
        target,
        Vector2.zero(),
        -1,
      );
      expect(
        ArenaGeometry.crosses(actor.position, target, rect.inflate(44.99)),
        isFalse,
      );
      expect(
        ArenaGeometry.crosses(
          actor.position,
          actor.position + desired.normalized() * 104,
          rect.inflate(44.99),
        ),
        isTrue,
      );
      final direction = ObstacleRouter().steer(
        actor,
        desired,
        target,
        geometry,
        radius: 45,
        side: -1,
      );
      expect(
        ArenaGeometry.crosses(
          actor.position,
          actor.position + direction.normalized() * 104,
          rect.inflate(44.99),
        ),
        isFalse,
      );
    },
  );
  test('all approach angles keep moving or reach melee range', () {
    final pod = SupplyDrop(Offset.zero)..phase = SupplyPhase.active;
    final geometry = ArenaGeometry(
      const ArenaBounds(Rect.fromLTWH(-1000, -1000, 2000, 2000)),
      obstacles: [pod.footprint],
    );
    final failures = <String>[];
    for (final kind in [
      EnemyKind.scorpion,
      EnemyKind.mummy,
      EnemyKind.ranged,
      EnemyKind.runner,
    ]) {
      for (var a = 0; a < 16; a++) {
        for (var b = 0; b < 16; b++) {
          final center = Vector2(0, -26);
          final actor = PositionComponent(
            position:
                center +
                Vector2(math.cos(a * math.pi / 8), math.sin(a * math.pi / 8)) *
                    130,
          );
          final target =
              center +
              Vector2(math.cos(b * math.pi / 8), math.sin(b * math.pi / 8)) *
                  220;
          geometry.constrain(actor.position, 45);
          final router = ObstacleRouter();
          var distance = 0.0;
          for (var frame = 0; frame < 1200; frame++) {
            final before = actor.position.clone();
            final desired = EnemyTactics.intent(
              kind,
              actor.position,
              target,
              Vector2.zero(),
              1,
            );
            final direction = router.steer(
              actor,
              desired,
              target,
              geometry,
              radius: 45,
              side: 1,
            );
            geometry.move(actor.position, direction * 1.5, 45);
            if (frame >= 1080) distance += actor.position.distanceTo(before);
          }
          if (distance < 2 && actor.position.distanceTo(target) > 100) {
            failures.add(
              '$kind $a $b moved=$distance at=${actor.position} target=$target',
            );
          }
        }
      }
    }
    expect(
      failures.take(12).toList(),
      isEmpty,
      reason: '${failures.length} stuck cases',
    );
  });
}
