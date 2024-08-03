import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/enemy_component.dart';
import 'package:regun/my_game.dart';

class BulletComponent extends PositionComponent
    with HasGameReference<RegunGame>, CollisionCallbacks {
  BulletComponent({
    super.position,
    this.bulletRadius = 5,
  }) : super(
          size: Vector2.all(20),
          anchor: Anchor.center,
        );

  final double bulletRadius;
  static final _paint = Paint()..color = Colors.white;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(
      RectangleHitbox(
        collisionType: CollisionType.passive,
      ),
    );
  }

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

    if (position.y > game.size.y) {
      debugPrint('removed');
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is EnemyComponent) {
      debugPrint('EnemyComponentCollision');
      other.showCollectEffect();
      removeFromParent();
      other.removeFromParent();
    }
  }
}
