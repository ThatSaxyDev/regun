import 'dart:convert';
import 'dart:io';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/boss_attack_shape.dart';
import 'package:regun/systems/player_hurt_geometry.dart';

void main() {
  test('shared player hurt footprint and combined legacy reaches agree', () {
    final fixture = jsonDecode(
      File('test/fixtures/player-hurt-geometry.json').readAsStringSync(),
    );
    expect(PlayerHurtGeometry.radius, fixture['radius']);
    for (final row in fixture['contacts']) {
      expect(
        PlayerHurtGeometry.reach((row['oldReach'] as num).toDouble()),
        row['reach'],
      );
    }
  });
  test('circle, line and swept ring use the same hurt boundary and preserve inside pockets', () {
    const body = PlayerHurtGeometry.radius;
    final circle = BossAttackShape.circle(Vector2.zero(), 100);
    expect(circle.hits(Vector2(125.9, 0), 1, body: body), isTrue);
    expect(circle.hits(Vector2(126.1, 0), 1, body: body), isFalse);
    final line = BossAttackShape.line([
      Vector2(-200, 0),
      Vector2(200, 0),
    ], width: 10);
    expect(line.hits(Vector2(0, 35.9), 1, body: body), isTrue);
    expect(line.hits(Vector2(0, 36.1), 1, body: body), isFalse);
    final ring = BossAttackShape.ring(Vector2.zero(), 200, angle: 0, width: 10);
    expect(ring.hits(Vector2(-235.9, 0), 1, previous: .9, body: body), isTrue);
    expect(ring.hits(Vector2(-236.1, 0), 1, previous: .9, body: body), isFalse);
    expect(ring.hits(Vector2.zero(), 1, previous: .9, body: body), isFalse);
  });
}
