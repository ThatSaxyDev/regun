import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/multiplayer/movement_prediction.dart';
import 'package:regun/multiplayer/remote_motion.dart';

final map = MotionMap({
  'bounds': [-2000, -1000, 2000, 1000],
  'obstacles': [],
});
void sample(
  RemoteMotion p,
  int tick,
  double x, {
  double? arrival,
  bool moving = true,
  String epoch = 'room:1:alive',
  double limit = .08,
}) => p.add(
  epoch: epoch,
  tick: tick,
  serverTime: tick * .05,
  arrival: arrival ?? tick * .05 + .1,
  position: Offset(x, 0),
  moving: moving,
  maxSpeed: 300,
  extrapolationLimit: limit,
);
void main() {
  test(
    '20Hz timestamp track trails less than old ease-to-latest under jitter',
    () {
      final p = RemoteMotion();
      var old = Offset.zero, latest = Offset.zero;
      var tick = 0, freshError = 0.0, oldError = 0.0, frames = 0;
      final deliveries = <(double, int)>[
        for (var i = 0; i < 60; i++) (i * .05 + .1 + (i % 4 == 0 ? .02 : 0), i),
      ];
      for (var frame = 0; frame < 180; frame++) {
        final now = frame / 60;
        while (tick < deliveries.length && deliveries[tick].$1 <= now + 1e-9) {
          final item = deliveries[tick++];
          latest = Offset(item.$2 * 15.0, 0);
          sample(p, item.$2, latest.dx, arrival: item.$1);
        }
        old = Offset.lerp(old, latest, 1 - math.exp(-18 / 60))!;
        final current = p.render(now, map);
        if (frame > 30 && current != null) {
          final baseline = (now - .1) * 300;
          freshError += (baseline - current.dx).abs();
          oldError += (baseline - old.dx).abs();
          frames++;
        }
      }
      expect(freshError / frames, lessThan(oldError / frames * .65));
      expect(p.interpolationDelay, inInclusiveRange(.02, .07));
      expect(p.sampleCount, lessThanOrEqualTo(24));
    },
  );
  test('missing updates extrapolate at most 80ms then stay planted', () {
    final p = RemoteMotion();
    sample(p, 0, 0);
    sample(p, 1, 15);
    expect(p.render(.3, map)!.dx, closeTo(39, 1e-9));
    expect(p.render(10, map)!.dx, closeTo(39, 1e-9));
    expect(p.extrapolatedSeconds, .08);
    expect(p.underRuns, greaterThan(0));
  });
  test(
    'stops, turns, epochs, death and large relocations discard old velocity',
    () {
      final p = RemoteMotion();
      sample(p, 0, 0);
      sample(p, 1, 15);
      sample(p, 2, 15, moving: false);
      expect(p.render(.4, map), const Offset(15, 0));
      sample(p, 3, 0); // A reversal predicts the new direction.
      expect(p.render(.45, map)!.dx, lessThanOrEqualTo(0));
      sample(p, 0, 700, epoch: 'room:2:alive');
      expect(p.render(.5, map), const Offset(700, 0));
      sample(p, 1, 700, epoch: 'room:2:dead', moving: false);
      expect(p.render(.6, map), const Offset(700, 0));
      sample(p, 2, -700, epoch: 'room:2:dead', moving: false);
      expect(p.render(.7, map), const Offset(-700, 0));
      sample(
        p,
        1,
        0,
        epoch: 'room:2:dead',
      ); // old tick cannot rewind an epoch's track
      expect(p.render(.8, map), const Offset(-700, 0));
    },
  );
  test(
    'extrapolation respects cover, current dash duration and reduced motion',
    () {
      final wall = MotionMap({
        'bounds': [-2000, -1000, 2000, 1000],
        'obstacles': [
          [80, -100, 100, 100],
        ],
      });
      final p = RemoteMotion();
      sample(p, 0, 30);
      sample(p, 1, 45);
      expect(p.render(.3, wall)!.dx, 50);
      final short = RemoteMotion();
      sample(short, 0, 0);
      sample(short, 1, 15, limit: .01);
      expect(short.render(.3, map)!.dx, closeTo(18, 1e-8));
      expect(short.render(.31, map, reducedMotion: true), const Offset(15, 0));
    },
  );
}
