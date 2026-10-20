import 'package:flame/components.dart';
import 'dart:ui';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/regun_art.dart';

/// Existing, inspected poses. Do not play the Queen's incomplete final tail/spit
/// cells or let attack-frame duration finish before the gameplay phase does.
class BossArt {
  /// Shared ambient light softens source-atlas highlights into the arena.
  /// Preserve silhouettes and material colour; never tint warning geometry.
  static ColorFilter ambient(ArenaType arena) {
    final warm = arena == ArenaType.foundry;
    const s = .82;
    final r = warm ? .96 : .88, g = warm ? .87 : .94, b = warm ? .81 : .9;
    return ColorFilter.matrix([
      r * (.2126 * (1 - s) + s),
      r * .7152 * (1 - s),
      r * .0722 * (1 - s),
      0,
      0,
      g * .2126 * (1 - s),
      g * (.7152 * (1 - s) + s),
      g * .0722 * (1 - s),
      0,
      0,
      b * .2126 * (1 - s),
      b * .7152 * (1 - s),
      b * (.0722 * (1 - s) + s),
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  static void contactShadow(Canvas canvas, Offset feet, double radius) {
    // Layered contact occlusion without blur or a costly full-screen layer.
    for (final (scale, alpha) in [(1.25, .10), (1.0, .17), (.68, .24)]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: feet,
              width: radius * 2 * scale,
              height: radius * .45 * scale),
          Paint()..color = Color.fromRGBO(12, 14, 13, alpha));
    }
  }

  static List<int> impactFrames(BossKind kind, int pattern) {
    final start = 12 + (pattern % 3) * 8;
    return kind == BossKind.queen
        ? [start, start + 1, start]
        : [start, start + 1, start + 2, start + 3];
  }

  static SpriteAnimation clip(BossKind kind, List<int> frames, double duration,
          {bool loop = false}) =>
      SpriteAnimation.spriteList([
        for (final frame in frames)
          RegunArt.shared.sprite('bosses/${kind.name}', frame)
      ], stepTime: duration / frames.length, loop: loop);

  static SpriteAnimation walk(BossKind kind) =>
      clip(kind, const [4, 5, 6, 7], kind == BossKind.demon ? .64 : .56,
          loop: true);

  static SpriteAnimation idle(BossKind kind) =>
      clip(kind, const [0, 1, 2, 3], 1.2, loop: true);
}
