import 'dart:ui';

import 'package:flame/components.dart';

/// One world-space rectangle drives the camera, movement and spawning.
class ArenaBounds {
  const ArenaBounds(this.rect, {this.wallThickness = 32});

  final Rect rect;
  final double wallThickness;

  Rect get floor => rect.deflate(wallThickness);

  void constrainPlayer(Vector2 position, double radius) {
    final playable = floor.deflate(radius);
    position.setValues(
      position.x.clamp(playable.left, playable.right),
      position.y.clamp(playable.top, playable.bottom),
    );
  }

  Vector2 cameraPosition(Vector2 target, Vector2 visibleSize) {
    double constrain(double value, double start, double end, double extent) {
      if (extent >= end - start) return (start + end) / 2;
      return value.clamp(start + extent / 2, end - extent / 2);
    }

    return Vector2(
      constrain(target.x, rect.left, rect.right, visibleSize.x),
      constrain(target.y, rect.top, rect.bottom, visibleSize.y),
    );
  }
}
