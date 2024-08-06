import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/border_component.dart';
import 'package:regun/components/enemy_component.dart';
import 'package:regun/my_game.dart';

class BulletComponent extends PositionComponent
    with HasGameReference<RegunGame>, CollisionCallbacks {
  BulletComponent({
    super.position,
    this.bulletRadius = 15,
    this.maxTravelDistance = 500,
    required this.direction,
    this.speed = 400,
    this.startPosition,
  }) : super(
          size: Vector2.all(bulletRadius * 2),
          anchor: Anchor.center,
        ) {
    startPosition = position.clone();
  }

  final double bulletRadius;
  final Vector2 direction;
  final double speed;
  final double maxTravelDistance;
  Vector2? startPosition;
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
    if ((position - startPosition!).length > maxTravelDistance) {
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is EnemyComponent) {
      debugPrint('EnemyComponentCollision');
      game.increaseScore();
      other.showCollectEffect();
      removeFromParent();
      other.removeFromParent();
    } else if (other is BorderComponent) {
      removeFromParent();
    }
  }
}
