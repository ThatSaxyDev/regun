import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/flame_flow.dart';

void main() {
  test('fire is emitted, advances away from its nozzle, spreads and drains after stopping', () {
    final flow = FlameFlow();
    void step(bool active) => flow.advance(
      1 / 120,
      active: active,
      nozzle: Vector2.zero(),
      direction: Vector2(1, 0),
      range: 240,
      clip: (a, b) => b,
    );
    for (var i = 0; i < 15; i++) {
      step(true);
    }
    final first = flow.tongues.first;
    final before = first.position.clone();
    for (var i = 0; i < 12; i++) {
      step(true);
    }
    expect(first.position.x, greaterThan(before.x + 50));
    expect(
      flow.tongues.map((t) => t.position.y).toSet().length,
      greaterThan(2),
    );
    expect(flow.front(240), lessThan(240));
    for (var i = 0; i < 240; i++) {
      step(true);
      expect(flow.tongues.length, lessThanOrEqualTo(18));
    }
    expect(flow.front(240), 240);
    for (var i = 0; i < 90; i++) {
      step(false);
    }
    expect(flow.tongues, isEmpty);
  });
  test(
    'advected tongues stop at cover and do not turn toward a moving nozzle',
    () {
      final flow = FlameFlow();
      for (var i = 0; i < 120; i++) {
        flow.advance(
          1 / 120,
          active: true,
          nozzle: Vector2.zero(),
          direction: Vector2(1, 0),
          range: 240,
          clip: (a, b) => Vector2(b.x.clamp(0, 80), b.y),
        );
      }
      expect(flow.tongues.every((t) => t.position.x <= 80), true);
      final old = flow.tongues.first;
      final direction = old.direction.clone();
      flow.advance(
        1 / 120,
        active: true,
        nozzle: Vector2(20, 30),
        direction: Vector2(0, 1),
        range: 240,
        clip: (a, b) => b,
      );
      expect(old.direction, direction);
      expect(flow.front(240), lessThan(45));
    },
  );
}
