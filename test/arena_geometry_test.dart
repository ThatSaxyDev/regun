import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/arena_bounds.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/components/weapons/bullet_component.dart';

void main() {
  final geometry = ArenaGeometry(
      const ArenaBounds(Rect.fromLTWH(-2256, -2256, 4512, 4512)),
      obstacles: [
        for (final x in [-700.0, 700.0])
          for (final y in [-950.0, 0.0, 950.0])
            Rect.fromCenter(center: Offset(x, y), width: 130, height: 250)
      ]);
  test('a long dash cannot tunnel through a foundry column', () {
    final point = Vector2(500, 0);
    geometry.move(point, Vector2(500, 0), 30);
    expect(point.x, lessThanOrEqualTo(605));
    expect(point.y, 0);
  });
  test('diagonal movement slides along a solid obstacle', () {
    final point = Vector2(590, -80);
    geometry.move(point, Vector2(120, -250), 30);
    expect(point.y, lessThan(-200));
    expect(point.x,
        greaterThan(605)); // Once past the corner, forward motion resumes.
  });
  test('line of sight sees a wall crossing but permits a clear lane', () {
    expect(geometry.blocked(Vector2(500, 0), Vector2(900, 0)), isTrue);
    expect(geometry.blocked(Vector2(500, 300), Vector2(900, 300)), isFalse);
  });
  test('swept projectiles detect thin targets along a long frame step', () {
    expect(
        BulletComponent.segmentDistanceSquared(
            Vector2(50, 2), Vector2.zero(), Vector2(100, 0)),
        4);
    expect(
        BulletComponent.segmentDistanceSquared(
            Vector2(150, 0), Vector2.zero(), Vector2(100, 0)),
        2500);
  });
}
