// Diagnostic only: flutter test tool/crowd_movement_probe_test.dart
// Uses production steering/occupancy, without combat, walls, spawning or artwork.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/systems/crowd_occupancy.dart';
import 'package:regun/systems/enemy_tactics.dart';

void main() {
  test('record shared crowd formation diagnostics', () async {
    final results = <Map<String, dynamic>>[];
    for (final kind in [EnemyKind.mummy, EnemyKind.scorpion]) {
      for (final seed in [7, 19, 43]) {
        for (final count in [12, 48]) {
          final random = math.Random(seed);
          final tactics = EnemyTactics(), crowd = CrowdOccupancy();
          final size = kind == EnemyKind.mummy ? 100.0 : 85.0;
          final radius = size * .45, hardGap = radius * 2 + 4;
          final speed = kind == EnemyKind.mummy ? 95.0 : 60.0;
          final velocity = Vector2(-speed * .72, -speed * .18);
          final target = Vector2.zero();
          final actors = [
            for (var i = 0; i < count; i++)
              PositionComponent(
                position: Vector2(
                  450 + random.nextDouble() * 650,
                  -350 + random.nextDouble() * 700,
                ),
                size: Vector2.all(size),
              ),
          ];
          void constrain(Vector2 p) {}
          for (final a in actors) {
            expect(crowd.place(a, radius, constrain), isTrue);
          }
          final samples = <Map<String, dynamic>>[];
          final initial = [
            for (final a in actors) [a.position.x, a.position.y],
          ];
          final displacements = {for (final a in actors) a: Vector2.zero()};
          var aligned = 0.0, observations = 0, stopped = 0;
          for (var frame = 0; frame < 2400; frame++) {
            target.addScaled(velocity, 1 / 60);
            tactics.rebuild(actors);
            crowd.rebuild(actors, (_) => radius);
            // CombatEnemy priority follows world Y. Approximate Flame's previous
            // frame depth order; no actor-specific combat phases are simulated.
            final order = [...actors]
              ..sort((a, b) => a.position.y.compareTo(b.position.y));
            final net = Vector2.zero();
            var moving = 0;
            for (final a in order) {
              final before = a.position.clone();
              if (kind != EnemyKind.mummy ||
                  a.position.distanceTo(target) > 36) {
                final intent = EnemyTactics.intent(
                  kind,
                  a.position,
                  target,
                  velocity,
                  tactics.side(a),
                );
                crowd.move(
                  a,
                  tactics.spaced(a, intent) * (speed / 60),
                  radius: radius,
                  constrain: constrain,
                  side: tactics.side(a),
                );
              }
              final step = a.position - before;
              if (frame >= 1800) displacements[a]!.add(step);
              if (step.length > .01) {
                net.add(step.normalized());
                moving++;
              } else if (frame >= 1800) {
                stopped++;
              }
            }
            if (frame >= 1800) {
              aligned += moving == 0 ? 0 : net.length / moving;
              observations++;
            }
            if (frame == 599 || frame == 1199 || frame == 2399) {
              var re = 0.0, im = 0.0, bonds = 0;
              final nearest = <double>[];
              for (final a in actors) {
                var closest = double.infinity;
                for (final b in actors) {
                  if (a == b) continue;
                  final d = b.position - a.position;
                  closest = math.min(closest, d.length);
                  if (d.length <= hardGap * 1.25) {
                    final angle = math.atan2(d.y, d.x) * 6;
                    re += math.cos(angle);
                    im += math.sin(angle);
                    bonds++;
                  }
                }
                nearest.add(closest);
              }
              nearest.sort();
              samples.add({
                'seconds': (frame + 1) / 60,
                'nearestMedian': nearest[nearest.length ~/ 2],
                'sixfoldBondOrder': bonds == 0
                    ? 0
                    : math.sqrt(re * re + im * im) / bonds,
                'bonds': bonds,
                'positions': [
                  for (final a in actors) [a.position.x, a.position.y],
                ],
                'target': [target.x, target.y],
              });
            }
          }
          results.add({
            'kind': kind.name,
            'seed': seed,
            'count': count,
            'hardGap': hardGap,
            'speed': speed,
            'targetVelocity': [velocity.x, velocity.y],
            'initial': initial,
            'samples': samples,
            'last10sHeadingAlignment': aligned / observations,
            'last10sStoppedFraction': stopped / (600 * count),
            'last10sDisplacement': [
              for (final a in actors)
                [displacements[a]!.x, displacements[a]!.y],
            ],
          });
        }
      }
    }
    const path = 'build/diagnostics/crowd-movement-probe-2026-10-29.json';
    await Directory('build/diagnostics').create(recursive: true);
    await File(path)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    // This records current behavior; it intentionally does not assert that a
    // regular formation is desirable or certify player-reported footage.
    stdout.writeln('Crowd diagnostic written to $path');
    for (final r in results) {
      final s = (r['samples'] as List).last as Map;
      stdout.writeln(
        '${r['kind']} seed=${r['seed']} n=${r['count']} nearest=${(s['nearestMedian'] as double).toStringAsFixed(1)} sixfold=${(s['sixfoldBondOrder'] as double).toStringAsFixed(3)} alignment=${(r['last10sHeadingAlignment'] as double).toStringAsFixed(3)}',
      );
    }
  });
  test('record fixed-boss yield boundary behavior', () async {
    final p = Vector2(100, 125),
        boss = Vector2.zero(),
        target = Vector2(800, 0);
    var switches = 0, yields = 0;
    bool? last;
    for (var frame = 0; frame < 300; frame++) {
      final yieldingDirection = EnemyTactics.yieldToBoss(p, boss, target, 1);
      final yielding = yieldingDirection != null;
      if (last != null && last != yielding) switches++;
      last = yielding;
      if (yielding) yields++;
      p.addScaled(yieldingDirection ?? (target - p).normalized(), 95 / 60);
    }
    final result = {
      'seconds': 5,
      'bossStationary': true,
      'start': [100, 125],
      'end': [p.x, p.y],
      'yieldFrames': yields,
      'yieldPursuitSwitches': switches,
      'unconstrainedTravel': 475,
    };
    await Directory('build/diagnostics').create(recursive: true);
    await File('build/diagnostics/crowd-boss-yield-2026-10-29.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(result));
    stdout.writeln('Fixed-boss yield: $result');
  });
}
