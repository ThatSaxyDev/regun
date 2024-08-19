import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/enemies/shadow_projectile.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/utils/soloud_play.dart';

class ShadowBossComponent extends SpriteAnimationComponent
    with
        HasGameReference<RegunGame>,
        CollisionCallbacks,
        RiverpodComponentMixin {
  ShadowBossComponent({super.position})
      : super(
          priority: 60,
          size: Vector2(272, 112) * 2,
          anchor: Anchor.center,
        );
  static final _splashpaint = Paint()..color = Colors.red;
  static const enemySize = 500.0;
  late SpriteAnimation moveRightAnimation;
  late SpriteAnimation attackRightAnimation;
  late SpriteAnimation idleRightAnimation;
  bool isAttacking = false;
  bool isDying = false;
  int health = 2;
  double attackInterval = 0.6;
  double timeSinceLastAttack = 0.0;
  double shotInterval = 0.2;
  double timeSinceLastShot = 0.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // debugMode = true;
    final moveRightSpriteSheet = SpriteSheet(
      image: await game.images.load('shadow_walk.png'),
      srcSize: Vector2(272, 112),
    );
    final attackRightSpriteSheet = SpriteSheet(
      image: await game.images.load('shadow_attack_1.png'),
      srcSize: Vector2(272, 112),
    );
    final idleRightSpriteSheet = SpriteSheet(
      image: await game.images.load('shadow_idle.png'),
      srcSize: Vector2(272, 112),
    );
    moveRightAnimation = moveRightSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 14,
    );
    attackRightAnimation = attackRightSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 11,
    );
    idleRightAnimation = idleRightSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 14,
    );

    animation = moveRightAnimation;
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

    // PLAYER POSITION
    final playerPosition = game.myPlayer.position;

    // DIRECTION VECTOR FROM THE ENEMY TO THE PLAYER
    final direction = (playerPosition - position).normalized();

    // CALCULATE DISTANCE BETWEEN ENEMY AND PLAYER
    final distanceToPlayer = (playerPosition - position).length;

    // DEFINE A MINIMUM DISTANCE TO STOP BEFORE TOUCHING THE PLAYER
    const minimumDistance = 400.0; // Adjust this value as needed
    const attackDistance = 170.0;

    if (distanceToPlayer > minimumDistance) {
      // If the player is far away, move towards the player
      isAttacking = false;
      timeSinceLastAttack = 0.0; // Reset the attack timer
      const speed = 150;
      position += direction * (speed * dt);

      // Set move animation
      animation = moveRightAnimation;
    } else if (distanceToPlayer > attackDistance &&
        distanceToPlayer <= minimumDistance) {
      // If the player is within the minimum distance, switch to idle animation
      isAttacking = false;
      animation = idleRightAnimation;
      timeSinceLastShot += dt;
      if (timeSinceLastShot >= shotInterval) {
        timeSinceLastShot = 0.0;
        ref.read(soloudPlayProvider).play('enemy3projectile.wav');
        game.world.add(ShadowProjectile(
          position: position,
        ));
      }
    } else if (distanceToPlayer <= attackDistance) {
      // If the player is very close, switch to attack animation
      isAttacking = true;

      // Reduce health at regular intervals
      timeSinceLastAttack += dt;
      if (timeSinceLastAttack >= attackInterval) {
        timeSinceLastAttack = 0.0;
        // game.world.add(DemonBossAttackArea(
        //   position: game.myPlayer.position,
        // ));
        ref.read(gameNotifierProvider.notifier).reduceHealth();
        ref.read(soloudPlayProvider).play('gameov.wav');
        if (ref.read(gameNotifierProvider).health == 0) {
          game.gameOver();
        }
      }

      // Set attack animation
      animation = attackRightAnimation;
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
