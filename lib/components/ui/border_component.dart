import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BorderComponent extends PositionComponent {
  BorderComponent({super.size}) : super(priority: 50);

  static final _paint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10;

  static final gridPaint = Paint()
    ..color = Colors.grey.withOpacity(0.2)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5;

  double gridSize = 100;
  // late Sprite _backgroundSprite;
  // late Sprite _backgroundSprite2;

  @override
  Future<void> onLoad() async {
    // debugMode = true;
    await super.onLoad();
    add(RectangleHitbox(
      size: Vector2(size.x, size.x - 30),
      anchor: const Anchor(0.5, 0.502),
      collisionType: CollisionType.passive,
    ));
  }

  // @override
  // void render(Canvas canvas) {
  //   canvas.drawRect(
  //     Rect.fromCenter(
  //       center: Vector2.zero().toOffset(),
  //       width: size.x,
  //       height: size.x + 10,
  //     ),
  //     _paint,
  //   );

  //   //! grid lines
  //   // ! vertical
  //   // for (double x = -size.x / 2; x <= size.x / 2; x += gridSize) {
  //   //   canvas.drawLine(
  //   //     Offset(x, -size.x / 2),
  //   //     Offset(x, size.x / 2),
  //   //     gridPaint,
  //   //   );
  //   // }

  //   // //! Horizontal
  //   // for (double y = -size.x / 2; y <= size.x / 2; y += gridSize) {
  //   //   canvas.drawLine(
  //   //     Offset(-size.x / 2, y),
  //   //     Offset(size.x / 2, y),
  //   //     gridPaint,
  //   //   );
  //   // }
  // }
}
