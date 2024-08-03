import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/my_game.dart';

class PlayerComponent extends PositionComponent
    with HasGameReference<RegunGame> {
  PlayerComponent({
    required super.position,
    this.playerRadius = 18,
  });

  final double playerRadius;
  static final _paint = Paint()..color = Colors.red;

  @override
  void onMount() {
    size = Vector2.all(playerRadius * 2);
    anchor = Anchor.center;
    super.onMount();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      (size / 2).toOffset(),
      playerRadius,
      _paint,
    );
  }

  void move(Vector2 delta) {
    position.add(delta);
  }

  void startShooting() {}

  void stopShooting() {}
}
