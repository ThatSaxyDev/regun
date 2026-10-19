import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/arena_bounds.dart';

void main() {
  const arena = ArenaBounds(Rect.fromLTWH(-2256, -2256, 4512, 4512));
  test('camera view stays inside the tile map at every edge and corner', () {
    for (final viewport in [Vector2(1500, 700), Vector2(1000, 900)]) {
      for (final x in [-5000.0, -2256.0, 0.0, 2256.0, 5000.0]) {
        for (final y in [-5000.0, -2256.0, 0.0, 2256.0, 5000.0]) {
          final center = arena.cameraPosition(Vector2(x, y), viewport);
          final view = Rect.fromCenter(
              center: center.toOffset(), width: viewport.x, height: viewport.y);
          expect(view.left, greaterThanOrEqualTo(arena.rect.left));
          expect(view.right, lessThanOrEqualTo(arena.rect.right));
          expect(view.top, greaterThanOrEqualTo(arena.rect.top));
          expect(view.bottom, lessThanOrEqualTo(arena.rect.bottom));
        }
      }
    }
  });
  test('player and dash cannot cross walls; moving along an edge still works',
      () {
    final position = Vector2(-9000, 60);
    arena.constrainPlayer(position, 30);
    expect(position.x, arena.floor.left + 30);
    expect(position.y, 60);
    position.add(Vector2(0, 80));
    arena.constrainPlayer(position, 30);
    expect(position.y, 140);
    position.setValues(9000, 9000);
    arena.constrainPlayer(position, 30);
    expect(position.x, arena.floor.right - 30);
    expect(position.y, arena.floor.bottom - 30);
  });
  test('oversized view centers on the map instead of invalid clamp ranges', () {
    expect(arena.cameraPosition(Vector2(9999, -9999), Vector2.all(6000)),
        Vector2.zero());
  });
}
