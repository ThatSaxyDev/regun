import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:regun/my_game.dart';

class Enemy2Component extends SpriteAnimationComponent
    with HasGameReference<RegunGame>, CollisionCallbacks {
  Enemy2Component({super.position})
      : super(
          size: Vector2.all(enemySize),
          anchor: Anchor.center,
        );
  static final _splashpaint = Paint()..color = Colors.red;
  static const enemySize = 100.0;
  late SpriteAnimation moveLeftAnimation;
  late SpriteAnimation moveRightAnimation;
  late SpriteAnimation attackLeftAnimation;
  late SpriteAnimation attackRightAnimation;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // debugMode = true;
    final moveLeftSpriteSheet = SpriteSheet(
      image: await game.images.load('Mummy_walk.png'),
      srcSize: Vector2(48, 48),
    );
    final moveRightSpriteSheet = SpriteSheet(
      image: await game.images.load('Mummy_walk_right.png'),
      srcSize: Vector2(48, 48),
    );
    final attackLeftSpriteSheet = SpriteSheet(
      image: await game.images.load('Mummy_attack.png'),
      srcSize: Vector2(48, 48),
    );
    final attackRightSpriteSheet = SpriteSheet(
      image: await game.images.load('Mummy_attack_right.png'),
      srcSize: Vector2(48, 48),
    );
    moveLeftAnimation = moveLeftSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 6,
    );
    moveRightAnimation = moveRightSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 6,
    );
    attackLeftAnimation = attackLeftSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 6,
    );
    attackRightAnimation = attackRightSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 6,
    );
    animation = moveLeftAnimation;
    add(
      RectangleHitbox(
        size: Vector2(40, 70),
        anchor: const Anchor(-0.3, -0.4),
        collisionType: CollisionType.passive,
      ),
    );
  }

  // @override
  // void render(Canvas canvas) {
  //   canvas.drawRect(size.toRect(), _paint);
  // }

  @override
  void update(double dt) {
    super.update(dt);

    //! PLAYER POSITION
    final playerPosition = game.myPlayer.position;

    //! DIRECTION VECTOR FROM THE ENEMY TO THE PLAYER
    final direction = (playerPosition - position).normalized();

    //! MOVE ENEMY TOWARDS PLAYER
    const speed = 80;
    position += direction * (speed * dt);

    if (playerPosition.x > position.x) {
      animation = moveRightAnimation;
    } else {
      animation = moveLeftAnimation;
    }

    //! DELETE ENEMY WHEN IT TOUCHES THE PLAYER
    // if ((position - center).length < 1) {
    //   removeFromParent();
    // }
  }

  void showCollectEffect() {
    final rnd = Random();
    Vector2 randomVector2() => (Vector2.random(rnd) - Vector2.random(rnd)) * 80;
    parent!.add(
      ParticleSystemComponent(
        position: position,
        particle: Particle.generate(
            count: 30,
            lifespan: 0.8,
            generator: (i) {
              return AcceleratedParticle(
                speed: randomVector2(),
                acceleration: randomVector2(),
                child: CircleParticle(
                  radius: 2,
                  lifespan: 0.5,
                  paint: _splashpaint,
                ),
              );
            }),
      ),
    );

    removeFromParent();
  }
}
