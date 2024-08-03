import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/my_game.dart';

class BulletComponent extends PositionComponent
    with HasGameReference<RegunGame> {
  BulletComponent({
    super.position,
    this.bulletRadius = 10,
  }) : super(
          size: Vector2.all(20),
          anchor: Anchor.center,
        );

  final double bulletRadius;
  static final _paint = Paint()..color = Colors.white;

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      (size / 2).toOffset(),
      bulletRadius,
      _paint,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += dt * -500;

    if (position.y < -height) {
      removeFromParent();
    }
  }
}
