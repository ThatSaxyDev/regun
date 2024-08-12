import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/player_component.dart';
import 'package:regun/my_game.dart';
import 'package:regun/notifiers/game_notifier.dart';

class Enemy2Component extends SpriteAnimationComponent
    with
        HasGameReference<RegunGame>,
        CollisionCallbacks,
        RiverpodComponentMixin {
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
  late SpriteAnimation deathLeftAnimation;
  bool isAttacking = false;
  double attackInterval = 0.6; // Time between health reductions in seconds
  double timeSinceLastAttack = 0.0; // Timer to track the interval

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
    final deathLeftSpriteSheet = SpriteSheet(
      image: await game.images.load('Mummy_death.png'),
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
    deathLeftAnimation = deathLeftSpriteSheet.createAnimation(
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

    //! CALCULATE DISTANCE BETWEEN ENEMY AND PLAYER
    final distanceToPlayer = (playerPosition - position).length;

    //! DEFINE A MINIMUM DISTANCE TO STOP BEFORE TOUCHING THE PLAYER
    const minimumDistance = 40.0; // Adjust this value as needed

    //! MOVE ENEMY TOWARDS PLAYER IF IT'S FARTHER THAN THE MINIMUM DISTANCE
    if (distanceToPlayer > minimumDistance) {
      isAttacking = false;
      timeSinceLastAttack = 0.0; // Reset the attack timer
      const speed = 50;
      position += direction * (speed * dt);

      // Set move animation if not attacking
      if (playerPosition.x > position.x) {
        animation = moveRightAnimation;
      } else {
        animation = moveLeftAnimation;
      }
    } else {
      isAttacking = true;

      // Reduce health at regular intervals
      timeSinceLastAttack += dt;
      if (timeSinceLastAttack >= attackInterval) {
        timeSinceLastAttack = 0.0;
        ref.read(gameNotifierProvider.notifier).reduceHealth();
        FlameAudio.play('gameov.wav');
        if (ref.read(gameNotifierProvider).health == 0) {
          game.gameOver();
        }
      }

      // Set attack animation
      if (playerPosition.x > position.x) {
        animation = attackRightAnimation;
      } else {
        animation = attackLeftAnimation;
      }
    }
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
