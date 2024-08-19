import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';

class DemonBossAttackArea extends PositionComponent
    with
        HasGameReference<RegunGame>,
        CollisionCallbacks,
        RiverpodComponentMixin {
  DemonBossAttackArea({
    super.position,
    this.bulletRadius = 100,
    this.maxTravelDistance = 900,
    this.speed = 300,
    this.startPosition,
    super.angle,
  }) : super(
          size: Vector2.all(bulletRadius * 2),
          anchor: Anchor.center,
        ) {
    startPosition = position.clone();
  }

  final double bulletRadius;
  final double speed;
  final double maxTravelDistance;
  Vector2? startPosition;
  static final _paint = Paint()..color = Colors.red;
  late Sprite _bulletSprite;
  final Vector2 _velocity = Vector2.zero();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _bulletSprite = await Sprite.load('bulletR.png');
    // add(
    //   RectangleHitbox(
    //     collisionType: CollisionType.active,
    //   ),
    // );

    //! set the direction towards the player's current position
    final playerPosition = game.myPlayer.position;
    final direction = (playerPosition - position).normalized();

    //! set the velocity based on the direction and speed
    _velocity.setFrom(direction * speed);
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
    //
    super.update(dt);

    // //! update position based on the velocity
    // position += _velocity * dt;

    // //! remove the projectile if it has traveled beyond the max distance
    // if ((position - startPosition!).length > maxTravelDistance) {
    //   removeFromParent();
    // }
  }

  // @override
  // void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
  //   super.onCollision(intersectionPoints, other);

  //   if (other is EnemyComponent) {
  //     ref.read(soloudPlayProvider).play('hit.wav');
  //     other.showDeathSplashEffect();
  //     if (!ref.read(gameNotifierProvider).bulletsPhaseThrough) {
  //       removeFromParent();
  //     }

  //     other.removeFromParent();
  //   } else if (other is BorderComponent) {
  //     removeFromParent();
  //   } else if (other is Enemy2Component) {
  //     ref.read(soloudPlayProvider).play('hit.wav');

  //     other.isDying = true;
  //     other.isAttacking = false;
  //     other.animation = switch (game.myPlayer.position.x > other.position.x) {
  //       true => other.deathRightAnimation,
  //       false => other.deathLeftAnimation,
  //     };

  //     Future.delayed(const Duration(milliseconds: 500), () {
  //       other.removeFromParent();
  //     });

  //     if (!ref.read(gameNotifierProvider).bulletsPhaseThrough) {
  //       removeFromParent();
  //     }
  //   }
  // }
}
