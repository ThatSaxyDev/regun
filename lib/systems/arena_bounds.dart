import 'dart:ui';

import 'package:flame/components.dart';

/// Authored outer floor plus the usable interior of the rendered fence.
class ArenaBounds {
  const ArenaBounds(this.rect, {this.wallThickness = 32});

  // WallArt uses these same dimensions for the inside perimeter.
  static const fenceThickness = 24.0, wallVisualRise = 32.0;

  final Rect rect;
  final double wallThickness;

  Rect get floor => rect.deflate(wallThickness);

  // The south wall face rises into the floor; its visible top is the stopping
  // edge. Other faces rise away from their interior contact edge.
  Rect get interior => Rect.fromLTRB(
    floor.left + fenceThickness,
    floor.top + fenceThickness,
    floor.right - fenceThickness,
    floor.bottom - fenceThickness - wallVisualRise,
  );

  void constrainPlayer(
    Vector2 position,
    double radius, {
    double? bottomExtent,
  }) {
    final playable = interior.deflate(radius);
    position.setValues(
      position.x.clamp(playable.left, playable.right),
      position.y.clamp(
        playable.top,
        interior.bottom -
            (bottomExtent ?? radius).clamp(radius, double.infinity),
      ),
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
