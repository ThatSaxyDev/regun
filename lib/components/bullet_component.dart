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
    required this.direction,
    this.speed = 500,
  }) : super(
          size: Vector2.all(bulletRadius * 2),
          anchor: Anchor.center,
        );

  final double bulletRadius;
  final Vector2 direction;
  final double speed;
  static final _paint = Paint()..color = Colors.red;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(
      RectangleHitbox(
        collisionType: CollisionType.active,
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
    if (!direction.isZero()) {
      position += direction * speed * dt;
    } else {
      removeFromParent();
    }
    // position += direction * speed * dt;
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
