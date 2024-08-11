import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BorderComponent extends PositionComponent {
  BorderComponent({super.size}) : super();

  static final _paint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10;

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
  }
}
