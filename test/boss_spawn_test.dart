import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/boss_spawn.dart';

void main() {
  test('every footprint retains clearance at center, walls and corners', () {
    const bounds = Rect.fromLTRB(-2400, -1600, 2400, 1600);
    for (final radius in [70.0, 130.0, 220.0, 230.0]) {
      for (final player in [
        Offset.zero,
        const Offset(2300, 0),
        const Offset(-2300, -1500),
        const Offset(2300, 1500),
      ]) {
        final point = BossSpawn.choose(
          player: player,
          bounds: bounds,
          footprint: radius,
          legal: (p, r) =>
              !const Rect.fromLTRB(800, -300, 1300, 300).inflate(r).contains(p),
        );
        expect(point, isNotNull);
        expect((point! - player).distance, greaterThanOrEqualTo(700));
        expect(bounds.deflate(radius).contains(point), isTrue);
        expect(
          const Rect.fromLTRB(
            800,
            -300,
            1300,
            300,
          ).inflate(radius).contains(point),
          isFalse,
        );
      }
    }
  });
  test('blocked and undersized arenas never fall back onto the player', () {
    expect(
      BossSpawn.choose(
        player: Offset.zero,
        bounds: const Rect.fromLTRB(-300, -300, 300, 300),
        footprint: 220,
        legal: (_, __) => true,
      ),
      isNull,
    );
    expect(
      BossSpawn.choose(
        player: Offset.zero,
        bounds: const Rect.fromLTRB(-100, -100, 100, 100),
        footprint: 220,
        legal: (_, __) => true,
      ),
      isNull,
    );
    expect(
      BossSpawn.choose(
        player: Offset.zero,
        bounds: const Rect.fromLTRB(-2000, -2000, 2000, 2000),
        footprint: 220,
        legal: (_, __) => false,
      ),
      isNull,
    );
  });
  test('a companion searches the opposite side first', () {
    Offset? choose(bool companion) => BossSpawn.choose(
      player: Offset.zero,
      bounds: const Rect.fromLTRB(-2000, -2000, 2000, 2000),
      footprint: 100,
      legal: (_, __) => true,
      companion: companion,
    );
    expect((choose(false)! - choose(true)!).distance, closeTo(2000, .001));
  });
}
