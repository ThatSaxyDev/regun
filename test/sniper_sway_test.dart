import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/sniper_sway.dart';

void main() {
  test(
    'small initial sway rises smoothly to a bounded plateau and rests off',
    () {
      final sway = SniperSway()..advance(.01, aiming: true);
      expect(sway.angle.abs(), greaterThan(0));
      expect(sway.amplitude * 180 / math.pi, closeTo(.18, .002));
      var maxAngle = 0.0;
      for (var i = 0; i < 6000; i++) {
        sway.advance(.01, aiming: true);
        maxAngle = math.max(maxAngle, sway.angle.abs());
      }
      expect(sway.fatigue, 6);
      expect(sway.amplitude * 180 / math.pi, closeTo(.85, 1e-9));
      expect(maxAngle * 180 / math.pi, lessThanOrEqualTo(.85));
      sway.release();
      expect(sway.angle, 0);
      sway.advance(.1, aiming: false);
      expect(sway.fatigue, closeTo(5.8, 1e-9));
      sway.advance(3, aiming: false);
      expect(sway.fatigue, 0);
      expect(sway.phase, 0);
    },
  );
  test(
    'sway is simulation-step independent and saves fatigue without held intent',
    () {
      final a = SniperSway(), b = SniperSway();
      for (var i = 0; i < 120; i++) {
        a.advance(1 / 60, aiming: true);
      }
      for (var i = 0; i < 240; i++) {
        b.advance(1 / 120, aiming: true);
      }
      expect(a.angle, closeTo(b.angle, 1e-10));
      final restored = SniperSway()..restore(a.checkpoint());
      expect(restored.active, false);
      expect(restored.fatigue, a.fatigue);
      restored.advance(.01, aiming: true);
      a.advance(.01, aiming: true);
      expect(restored.angle, closeTo(a.angle, 1e-10));
      expect(
        () => SniperSway.validate({'fatigue': double.nan, 'phase': 0}),
        throwsFormatException,
      );
    },
  );
}
