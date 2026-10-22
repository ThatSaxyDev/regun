import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:regun/presentation/game_layout.dart';

/// Retains Flame's proven clipping/input transform, with a tablet aspect ratio.
class ArenaViewport extends FixedResolutionViewport {
  ArenaViewport() : super(resolution: Vector2(1500, 700));
  @override
  double get aspectRatio => resolution.x / resolution.y;
  @override
  void onGameResize(Vector2 size) {
    final world = GameLayout.world(size.toSize());
    resolution.setValues(world.width, world.height);
    super.onGameResize(size);
  }
}
