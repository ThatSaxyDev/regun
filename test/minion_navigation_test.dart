import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/minion_navigation.dart';
import 'package:regun/systems/target_shape.dart';

void main() {
  test(
    'shared authority decisions are permutation invariant and speed bounded',
    () {
      final fixture = jsonDecode(
        File('test/fixtures/minion-navigation-v1.json').readAsStringSync(),
      ) as Map;
      for (final raw in fixture['cases'] as List) {
        final c = raw as Map;
        Offset point(dynamic p) =>
            Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
        final bodies = [
          for (final b in c['bodies'] as List)
            NavigationBody(
              id: b['id'] as int,
              position: point(b['position']),
              velocity: point(b['velocity']),
              radius: (b['radius'] as num).toDouble(),
              boss: b['boss'] == true,
              motion: b['motion'] == null
                  ? null
                  : NavigationMotion(
                      point(b['motion']['end']),
                      (b['motion']['delay'] as num).toDouble(),
                      (b['motion']['duration'] as num).toDouble(),
                    ),
              contact: b['contact'] == true,
              shapes: [
                for (final shape in b['shapes'] as List? ?? [])
                  if (shape['origin'] != null)
                    ClippedTargetCapsule(
                      point(shape['a']),
                      point(shape['b']),
                      (shape['radius'] as num).toDouble(),
                      origin: point(shape['origin']),
                      normal: point(shape['normal']),
                      limit: (shape['limit'] as num).toDouble(),
                    )
                  else
                    TargetCapsule(
                      point(shape['a']),
                      point(shape['b']),
                      (shape['radius'] as num).toDouble(),
                    ),
              ],
            ),
        ];
        for (final order in [bodies, bodies.reversed.toList()]) {
          final nav = MinionNavigation()..rebuild(order);
          final d = nav.steer(
            c['actor'] as int,
            point(c['at']),
            point(c['desired']),
            (c['speed'] as num).toDouble(),
            .05,
            target: point(c['target']),
          );
          expect(d.distance, lessThanOrEqualTo(1.000001), reason: c['name']);
          if (c['expected'] != null) {
            expect(
              (d - point(c['expected'])).distance,
              lessThan(.00001),
              reason: c['name'],
            );
          }
          if (c['clear'] == true) {
            expect(
              (d - point(c['desired'])).distance,
              lessThan(.00001),
              reason: c['name'],
            );
          }
          if (c['avoid'] == true) {
            expect(d.dy.abs(), greaterThan(.1), reason: c['name']);
          }
          expect(nav.candidates, lessThanOrEqualTo(32));
        }
      }
    },
  );
  test(
    'optional memory rejects malformed state and resets transient samples',
    () {
      final nav = MinionNavigation()
        ..rebuild([
          const NavigationBody(id: 1, position: Offset(20, 0), radius: 45),
        ]);
      nav.steer(1, const Offset(20, 0), const Offset(1, 0), 95, .05);
      final json = nav.memories[1]!.toJson();
      final restored = NavigationMemory.read(json);
      expect(restored, isNotNull);
      for (final invalid in [
        null,
        {},
        {...json, 'v': 2},
        {...json, 'remaining': double.infinity},
        {...json, 'side': 0},
        {...json, 'waiting': -1},
        {...json, 'blocker': -4},
        {
          ...json,
          'goal': [double.nan, 0],
        },
        {...json, 'pressure': -4},
      ]) {
        expect(NavigationMemory.read(invalid), isNull);
      }
      nav.memories[1] = restored!;
      nav.steer(1, const Offset(600, 0), const Offset(1, 0), 95, .05);
      expect(nav.memories[1]!.anchor, const Offset(600, 0));
      nav.rebuild([]);
      expect(nav.memories, isEmpty);
    },
  );
  test('a stationary boss outside the actual body path never creates corridor chatter', () {
    final nav = MinionNavigation();
    var at = const Offset(100, 125);
    var transitions = 0;
    String? last;
    for (var frame = 0; frame < 300; frame++) {
      nav.rebuild([
        NavigationBody(id: 1, position: at, radius: 45),
        const NavigationBody(
          id: 2,
          position: Offset.zero,
          radius: 68,
          boss: true,
        ),
      ]);
      final d = nav.steer(
        1,
        at,
        MinionNavigation.unit(const Offset(800, 0) - at),
        95,
        1 / 60,
        target: const Offset(800, 0),
      );
      at += d * (95 / 60);
      final mode = nav.memories[1]!.mode;
      if (last != null && mode != last) transitions++;
      last = mode;
    }
    expect(transitions, lessThanOrEqualTo(2));
    expect(at.dx, greaterThan(500));
  });
}
