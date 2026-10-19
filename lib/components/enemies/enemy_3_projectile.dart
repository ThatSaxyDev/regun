import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/game.dart';

class Enemy3Projectile extends PositionComponent
    with HasGameReference<RegunGame>, CollisionCallbacks {
  Enemy3Projectile(
      {super.position,
      this.bulletRadius = 7,
      this.maxTravelDistance = 900,
      this.speed = 300,
      this.startPosition,
      super.angle})
      : super(
            size: Vector2.all(bulletRadius * 2),
            anchor: Anchor.center,
            priority: 20000) {
    startPosition = position.clone();
  }

  final double bulletRadius;
  final double speed;
  final double maxTravelDistance;
  Vector2? startPosition;
  final _velocity = Vector2.zero();

  @override
  Future<void> onLoad() async {
    if (!game.registerHostileProjectile(this)) {
      removeFromParent();
      return;
    }
    add(CircleHitbox(collisionType: CollisionType.passive));
    _velocity.setFrom((game.myPlayer.position - position).normalized() * speed);
  }

  @override
  void onRemove() {
    game.unregisterHostileProjectile(this);
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(atan2(_velocity.y, _velocity.x) - pi * 3 / 4);
    RegunArt.shared
        .rawSprite('items/items', 7)
        .render(canvas, size: size * 1.6, anchor: Anchor.center);
    canvas.restore();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final before = position.clone();
    position.addScaled(_velocity, dt);
    if (game.segmentBlocked(before, position) ||
        position.distanceToSquared(startPosition!) >
            maxTravelDistance * maxTravelDistance ||
        !game.map.bounds.rect.contains(position.toOffset())) {
      removeFromParent();
    }
  }
}
