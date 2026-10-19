import 'package:flame/components.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/presentation/regun_art.dart';

/// Existing, inspected poses. Do not play the Queen's incomplete final tail/spit
/// cells or let attack-frame duration finish before the gameplay phase does.
class BossArt {
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
