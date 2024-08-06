import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/grid_component.dart';

class BorderComponent extends PositionComponent {
  BorderComponent({super.size}) : super();

  static final _paint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10;

  static final gridPaint = Paint()
    ..color = Colors.grey
    ..style = PaintingStyle.stroke;

  double gridSize = 50;

  @override
  void onLoad() {
    super.onLoad();
    add(RectangleHitbox(
      size: Vector2(size.x, size.x),
      anchor: Anchor.center,
      collisionType: CollisionType.passive,
    ));

    // add(GridComponent(
    //   gridSize: 50, // Adjust the grid size as needed
    //   size: size,
    // ));
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromCenter(
        center: Vector2.zero().toOffset(),
        width: size.x,
        height: size.x,
      ),
      _paint,
    );

    //! for grids
    for (double x = 0; x < size.x; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.y),
        gridPaint,
      );
    }
  }
}
