import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';

class DemonBossComponent extends SpriteAnimationComponent
    with
        HasGameReference<RegunGame>,
        CollisionCallbacks,
        RiverpodComponentMixin {
  DemonBossComponent({super.position})
      : super(
          priority: 60,
          size: Vector2(288, 160) * 3,
          anchor: Anchor.center,
        );
  static final _splashpaint = Paint()..color = Colors.red;
  static const enemySize = 500.0;
  late SpriteAnimation moveLeftAnimation;
  late SpriteAnimation moveRightAnimation;
  late SpriteAnimation attackLeftAnimation;
  late SpriteAnimation attackRightAnimation;
  // late SpriteAnimation deathLeftAnimation;
  // late SpriteAnimation deathRightAnimation;
  // late SpriteAnimation hurtLeftAnimation;
  // late SpriteAnimation hurtRightAnimation;
  bool isAttacking = false;
  bool isDying = false;
  int health = 2;
  double attackInterval = 0.6; // Time between health reductions in seconds
  double timeSinceLastAttack = 0.0; // Timer to track the interval

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    debugMode = true;
    final demonBossSpriteSheet = SpriteSheet(
      image: await game.images.load('demon_boss.png'),
      srcSize: Vector2(288, 160),
    );
    // final moveRightSpriteSheet = SpriteSheet(
    //   image: await game.images.load('Mummy_walk_right.png'),
    //   srcSize: Vector2(48, 48),
    // );
    // final attackLeftSpriteSheet = SpriteSheet(
    //   image: await game.images.load('Mummy_attack.png'),
    //   srcSize: Vector2(48, 48),
    // );
    // final attackRightSpriteSheet = SpriteSheet(
    //   image: await game.images.load('Mummy_attack_right.png'),
    //   srcSize: Vector2(48, 48),
    // );
    // final deathLeftSpriteSheet = SpriteSheet(
    //   image: await game.images.load('Mummy_death.png'),
    //   srcSize: Vector2(48, 48),
    // );
    // final deathRightSpriteSheet = SpriteSheet(
    //   image: await game.images.load('Mummy_death_right.png'),
    //   srcSize: Vector2(48, 48),
    // );
    // final hurtLeftSpriteSheet = SpriteSheet(
    //   image: await game.images.load('Mummy_hurt.png'),
    //   srcSize: Vector2(48, 48),
    // );
    // final hurtRightSpriteSheet = SpriteSheet(
    //   image: await game.images.load('Mummy_hurt_right.png'),
    //   srcSize: Vector2(48, 48),
    // );
    moveLeftAnimation = demonBossSpriteSheet.createAnimation(
      row: 1,
      stepTime: 0.1,
      to: 12,
    );
    moveRightAnimation = demonBossSpriteSheet.createAnimation(
      row: 1,
      stepTime: 0.1,
      to: 12,
    );
    attackLeftAnimation = demonBossSpriteSheet.createAnimation(
      row: 2,
      stepTime: 0.1,
      to: 15,
    );
    attackRightAnimation = demonBossSpriteSheet.createAnimation(
      row: 2,
      stepTime: 0.1,
      to: 15,
    );
    // deathLeftAnimation = deathLeftSpriteSheet.createAnimation(
    //   row: 0,
    //   stepTime: 0.1,
    //   to: 6,
    // );
    // deathRightAnimation = deathRightSpriteSheet.createAnimation(
    //   row: 0,
    //   stepTime: 0.1,
    //   to: 6,
    // );
    // hurtLeftAnimation = hurtLeftSpriteSheet.createAnimation(
    //   row: 0,
    //   stepTime: 0.1,
    //   to: 6,
    // );
    // hurtRightAnimation = hurtRightSpriteSheet.createAnimation(
    //   row: 0,
    //   stepTime: 0.1,
    //   to: 6,
    // );

    animation = moveLeftAnimation;
    add(
      CircleHitbox(
        radius: 40,
        anchor: const Anchor(-0.15, -0.3),
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

    if (isDying) {
      // Stop all actions if the enemy is dead
      return;
    }

    //! PLAYER POSITION
    final playerPosition = game.myPlayer.position + Vector2(0, -255);

    //! DIRECTION VECTOR FROM THE ENEMY TO THE PLAYER
    final direction = (playerPosition - position).normalized();

    //! CALCULATE DISTANCE BETWEEN ENEMY AND PLAYER
    final distanceToPlayer = (playerPosition - position).length;

    //! DEFINE A MINIMUM DISTANCE TO STOP BEFORE TOUCHING THE PLAYER
    const minimumDistance = 250.0; // Adjust this value as needed

    //! MOVE ENEMY TOWARDS PLAYER IF IT'S FARTHER THAN THE MINIMUM DISTANCE
    if (distanceToPlayer > minimumDistance) {
      isAttacking = false;
      timeSinceLastAttack = 0.0; // Reset the attack timer
      const speed = 150;
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
        // game.world.add(DemonBossAttackArea(
        //   position: game.myPlayer.position,
        // ));
        // ref.read(gameNotifierProvider.notifier).reduceHealth();
        // // FlameAudio.play('gameov.wav');
        // ref.read(soloudPlayProvider).play('gameov.wav');
        // if (ref.read(gameNotifierProvider).health == 0) {
        //   game.gameOver();
        // }
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
