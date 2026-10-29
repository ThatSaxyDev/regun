import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/mechanical_arrival.dart';

void main() {
  for (final arrival in [2.6, 3.05]) {
    test('arrival $arrival pans, holds and returns with combat zoom', () {
      final a = MechanicalArrival(),
          player = Vector2.zero(),
          focus = Vector2(1000, 300);
      a.begin(
        PositionComponent(),
        player,
        1,
        targetZoom: .74,
        arrivalDuration: arrival,
        reducedMotion: false,
      );
      a.advance(10, ready: false);
      expect(a.elapsed, 0);
      a.advance(.325, ready: true);
      expect(a.camera(player, focus).x, closeTo(500, .01));
      a.advance(.325, ready: true);
      expect(a.camera(player, focus), focus);
      expect(a.zoom, .74);
      a.advance(arrival - .65, ready: true);
      expect(a.camera(player, focus), focus);
      expect(a.advance(.65, ready: true), isTrue);
      expect(a.camera(player, focus), player);
      expect(a.zoom, .74);
      a.reset();
      expect(a.active, isFalse);
    });
  }
  test(
    'Reduced Motion keeps the survivor centered and cancellation clears focus',
    () {
      final a = MechanicalArrival(), player = Vector2(20, 10);
      a.begin(
        PositionComponent(),
        Vector2.zero(),
        1,
        targetZoom: .8,
        arrivalDuration: 3.05,
        reducedMotion: true,
      );
      a.advance(1, ready: true);
      expect(a.camera(player, Vector2(1000, 0)), player);
      expect(a.zoom, .8);
      a.reset();
      expect(a.active, isFalse);
    },
  );
}
