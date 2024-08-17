import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/ui/border_component.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/utils/soloud_play.dart';

class ShrapnelComponent extends PositionComponent
    with
        HasGameReference<RegunGame>,
        CollisionCallbacks,
        RiverpodComponentMixin {
  ShrapnelComponent({
    super.position,
    this.bulletRadius = 7,
    this.maxTravelDistance = 300,
    required this.direction,
    this.speed = 700,
    this.startPosition,
    super.angle,
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
  late Sprite _bulletSprite;
  bool hasSpread = false;
  final _velocity = Vector2.zero();
  final _gravity = 60;

  @override
  Future<void> onLoad() async {
    // debugMode = true;
    await super.onLoad();
    _bulletSprite = await Sprite.load('bulletR.png');
    add(
      RectangleHitbox(
        collisionType: CollisionType.active,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    // _bulletSprite.render(
    //   canvas,
    //   position: size / 2,
    //   size: size,
    //   anchor: Anchor.center,
    // );
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
    position += direction * 1000 * dt;

    if ((position - startPosition!).length > maxTravelDistance) {
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is EnemyComponent) {
      // FlameAudio.play('hit.wav');
      ref.read(soloudPlayProvider).play('hit.wav');
      // ref.read(gameNotifierProvider.notifier).updateScore();
      other.showDeathSplashEffect();
      if (ref.read(gameNotifierProvider).bulletsPhaseThrough == false) {
        removeFromParent();
      }

      other.removeFromParent();
    } else if (other is BorderComponent) {
      removeFromParent();
    } else if (other is Enemy2Component) {
      // FlameAudio.play('hit.wav');
      ref.read(soloudPlayProvider).play('hit.wav');
      // ref.read(gameNotifierProvider.notifier).updateScore();

      // stop enemy movement
      other.isDying = true;
      other.isAttacking = false;
      other.animation = switch (game.myPlayer.position.x > other.position.x) {
        true => other.deathRightAnimation,
        false => other.deathLeftAnimation,
      };

      // delay the removal to allow the death animation to play
      Future.delayed(const Duration(milliseconds: 500), () {
        other.removeFromParent();
      });

      if (ref.read(gameNotifierProvider).bulletsPhaseThrough == false) {
        removeFromParent();
      }
    }
  }
}
