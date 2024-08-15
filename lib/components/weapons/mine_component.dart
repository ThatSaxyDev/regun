import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/game_utils/empty_component.dart';
import 'package:regun/components/ui/border_component.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/components/weapons/shrapnel_component.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

class MineComponent extends SpriteAnimationComponent
    with
        HasGameReference<RegunGame>,
        CollisionCallbacks,
        RiverpodComponentMixin {
  MineComponent({
    super.position,
    this.radius = 50,
    this.maxTravelDistance = 450,
    //  this.direction,
    this.speed = 700,
    this.startPosition,
    super.angle,
  }) : super(
          priority: 10,
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
        ) {
    startPosition = position.clone();
  }

  final double radius;
  // final Vector2 direction;
  final double speed;
  final double maxTravelDistance;
  Vector2? startPosition;
  static final _paint = Paint()..color = Colors.red.withOpacity(0.1);
  // late Sprite _bulletSprite;
  late SpriteAnimation mineAnimation;
  late SpriteAnimation mineExplodeAnimation;
  final explosionRadius = 200;
  late SpawnComponent shrapnelSpawner;

  @override
  Future<void> onLoad() async {
    // debugMode = true;
    await super.onLoad();
    // _bulletSprite = await Sprite.load('bulletR.png');
    final mineSpriteSheet = SpriteSheet(
      image: await game.images.load('mine.png'),
      srcSize: Vector2(64, 64),
    );
    final mineExplodeSpriteSheet = SpriteSheet(
      image: await game.images.load('mine_explode.png'),
      srcSize: Vector2(64, 64),
    );
    mineAnimation = mineSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 2,
    );
    mineExplodeAnimation = mineExplodeSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 3,
    );
    animation = mineAnimation;
    add(
      CircleHitbox(
        anchor: const Anchor(-0.12, -0.22),
        radius: radius - 10,
        collisionType: CollisionType.active,
      ),
    );
  }

  // @override
  // void render(Canvas canvas) {
  //   // _bulletSprite.render(
  //   //   canvas,
  //   //   position: size / 2,
  //   //   size: size,
  //   //   anchor: Anchor.center,
  //   // );
  //   canvas.drawCircle(
  //     (size / 2).toOffset(),
  //     radius * 3,
  //     _paint,
  //   );
  // }

  @override
  void update(double dt) {
    //
    super.update(dt);
    // if (!direction.isZero()) {
    //   position += direction * speed * dt;
    // } else {
    //   removeFromParent();
    // }
    // if ((position - startPosition!).length >
    //     (ref.read(gameNotifierProvider).bulletRange)) {
    //   removeFromParent();
    // }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is EnemyComponent) {
      animation = mineExplodeAnimation;
      // FlameAudio.play('hit.wav');
      // ref.read(gameNotifierProvider.notifier).updateScore();
      other.showDeathSplashEffect();

      other.removeFromParent();

      Future.delayed(const Duration(milliseconds: 500), () {
        removeFromParent();
      });
      game.world.add(shrapnelSpawner = SpawnComponent(
        period: 0.5,
        selfPositioning: true,
        factory: (amount) {
          spawnShrapnel();
          return EmptyComponent();
        },
        autoStart: true,
      ));
      Future.delayed(const Duration(milliseconds: 500)).whenComplete(
        () {
          game.world.remove(shrapnelSpawner);
        },
      );
    } else if (other is Enemy2Component) {
      // FlameAudio.play('hit.wav');
      // ref.read(gameNotifierProvider.notifier).updateScore();

      // stop enemy movement
      animation = mineExplodeAnimation;
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

      Future.delayed(const Duration(milliseconds: 500), () {
        removeFromParent();
      });
      // parent!.add(ShrapnelComponent(
      //   position: position.clone(),
      // ));
    }
  }

  void spawnShrapnel() {
    const spreadAngle = pi / 10;
    for (int i = -10; i <= 10; i++) {
      final angle = i * spreadAngle;
      final direction = Vector2(0.9, 0.1)..rotate(angle);
      final shrapnel = ShrapnelComponent(
        position: position.clone(),
        direction: direction,
      );

      game.world.add(shrapnel);
    }
  }
}
