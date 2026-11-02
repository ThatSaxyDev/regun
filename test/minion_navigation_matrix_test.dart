import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/crowd_occupancy.dart';
import 'package:regun/systems/minion_navigation.dart';

void main() {
  test('ten seeded slow-body bypasses at 30/60/120Hz preserve safe progress', () async {
    final results = <Map<String, dynamic>>[];
    for (final hz in [30, 60, 120]) {
      for (var seed = 1; seed <= 10; seed++) {
        final random = math.Random(seed),
            nav = MinionNavigation(),
            crowd = CrowdOccupancy();
        final blocker = PositionComponent(
          position: Vector2.zero(),
          size: Vector2.all(85),
        );
        final movers = <PositionComponent>[];
        for (var i = 0; i < 6; i++) {
          Vector2 p;
          do {
            p = Vector2(
              -300 - random.nextDouble() * 300,
              -220 + random.nextDouble() * 440,
            );
          } while (movers.any((a) => a.position.distanceTo(p) < 100));
          movers.add(PositionComponent(position: p, size: Vector2.all(100)));
        }
        final actors = [blocker, ...movers];
        final velocities = {for (final a in actors) a: Offset.zero};
        double radius(PositionComponent a) => a == blocker ? 38.25 : 45;
        final samples = <int>[];
        final clock = Stopwatch();
        var peakCandidates = 0;
        for (var frame = 0; frame < hz * 16; frame++) {
          nav.rebuild([
            for (var i = 0; i < actors.length; i++)
              NavigationBody(
                id: i + 1,
                position: actors[i].position.toOffset(),
                velocity: velocities[actors[i]]!,
                radius: radius(actors[i]),
              ),
          ]);
          crowd.rebuild(actors, radius);
          clock
            ..reset()
            ..start();
          for (var i = 0; i < movers.length; i++) {
            final a = movers[i], before = a.position.clone();
            final intent = MinionNavigation.unit(
              const Offset(1200, 0) - a.position.toOffset(),
            );
            final d = nav.steer(
              i + 2,
              a.position.toOffset(),
              intent,
              95,
              1 / hz,
              target: const Offset(1200, 0),
            );
            crowd.move(
              a,
              Vector2(d.dx, d.dy) * (95 / hz),
              radius: 45,
              constrain: (_) {},
              side: MinionNavigation.sideFor(i + 2),
            );
            velocities[a] =
                (a.position.toOffset() - before.toOffset()) * hz.toDouble();
            expect(
              a.position.distanceTo(before),
              lessThanOrEqualTo(95 / hz + .001),
            );
          }
          clock.stop();
          samples.add(clock.elapsedMicroseconds);
          peakCandidates = math.max(peakCandidates, nav.candidates);
          if (frame % hz == 0) {
            for (var a = 0; a < actors.length; a++) {
              for (var b = a + 1; b < actors.length; b++) {
                expect(
                  actors[a].position.distanceTo(actors[b].position),
                  greaterThanOrEqualTo(
                    radius(actors[a]) + radius(actors[b]) + 3.98,
                  ),
                );
              }
            }
          }
        }
        expect(
          movers.where((a) => a.position.x > 200).length,
          6,
          reason:
              'seed=$seed hz=$hz: every actor has a witnessed free detour around the fixed slower body',
        );
        samples.sort();
        results.add({
          'seed': seed,
          'hz': hz,
          'passed': 6,
          'peakCandidates': peakCandidates,
          'p95Microseconds': samples[(samples.length * .95).floor()],
          'meanFinalX':
              movers.fold<double>(0, (sum, a) => sum + a.position.x) /
              movers.length,
        });
        expect(peakCandidates, lessThanOrEqualTo(6 * 32));
      }
    }
    await Directory('build/diagnostics').create(recursive: true);
    await File('build/diagnostics/navigation-matrix.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(results));
  });
}
