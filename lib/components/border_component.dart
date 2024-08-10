import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BorderComponent extends PositionComponent {
  BorderComponent({super.size}) : super();

  static final _paint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10;

  static final gridPaint = Paint()
    ..color = Colors.grey.withOpacity(0.2)
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

    //! grid lines
    //! vertical
    for (double x = -size.x / 2; x <= size.x / 2; x += gridSize) {
      canvas.drawLine(
        Offset(x, -size.x / 2),
        Offset(x, size.x / 2),
        gridPaint,
      );
    }

    //! Horizontal
    for (double y = -size.x / 2; y <= size.x / 2; y += gridSize) {
      canvas.drawLine(
        Offset(-size.x / 2, y),
        Offset(size.x / 2, y),
        gridPaint,
      );
    }
  }
}
