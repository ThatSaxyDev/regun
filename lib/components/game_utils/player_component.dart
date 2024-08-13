import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/game_utils/coin_component.dart';
import 'package:regun/components/ui/border_component.dart';
import 'package:regun/components/game_utils/bullet_component.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

class PlayerComponent extends SpriteAnimationComponent
    with
        HasGameReference<RegunGame>,
        CollisionCallbacks,
        RiverpodComponentMixin {
  PlayerComponent({
    super.position,
    this.playerRadius = 25,
  }) : super(
        // priority: 20,
        );

  final double playerRadius;
  // static final _paint = Paint()
  //   ..color = Colors.white
  //   ..style = PaintingStyle.stroke
  //   ..strokeCap = StrokeCap.round
  //   ..strokeWidth = 10;
  double maxSpeed = 300.0;
  late final Vector2 _lastSize = size.clone();
  late final Transform2D _lastTransform = transform.clone();
  late SpriteAnimation idleRightAnimation;
  late SpriteAnimation idleLeftAnimation;
  late SpriteAnimation runRightAnimation;
  late SpriteAnimation runLeftAnimation;

  //!
  Random random = Random();
  Tween<double> noise = Tween(begin: -1, end: 1);
  ColorTween colorTweenn = ColorTween(begin: Colors.red, end: Colors.blue);

  //!
  LastDirection lastDirection = LastDirection.right;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final idleRightSpriteSheet = SpriteSheet(
      image: await game.images.load('player_idle.png'),
      srcSize: Vector2(48, 48),
    );
    final idleLeftSpriteSheet = SpriteSheet(
      image: await game.images.load('player_idle_left.png'),
      srcSize: Vector2(48, 48),
    );
    final runRightSpriteSheet = SpriteSheet(
      image: await game.images.load('player_run.png'),
      srcSize: Vector2(48, 48),
    );
    final runLeftSpriteSheet = SpriteSheet(
      image: await game.images.load('player_run_left.png'),
      srcSize: Vector2(48, 48),
    );
    idleRightAnimation = idleRightSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 5,
    );
    idleLeftAnimation = idleLeftSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 5,
    );
    runRightAnimation = runRightSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 6,
    );
    runLeftAnimation = runLeftSpriteSheet.createAnimation(
      row: 0,
      stepTime: 0.1,
      to: 6,
    );
    animation = idleRightAnimation;
    add(
      RectangleHitbox(
        size: Vector2(40, 70),
        anchor: const Anchor(-0.75, -0.18),
        collisionType: CollisionType.active,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.boostButtonComponent.tapped) {
      position.add(game.movementJoystick.relativeDelta * 1000 * dt);
    }
    Set<PositionComponent> filteredComponents =
        getFilteredComponents(activeCollisions);
    if (!game.weaponJoystick.delta.isZero() &&
        game.movementJoystick.delta.isZero()) {
      switch (game.weaponJoystick.direction) {
        case JoystickDirection.left ||
              JoystickDirection.upLeft ||
              JoystickDirection.downLeft ||
              JoystickDirection.down:
          animation = idleLeftAnimation;
          lastDirection = LastDirection.left;

        case JoystickDirection.right ||
              JoystickDirection.upRight ||
              JoystickDirection.downRight ||
              JoystickDirection.up:
          animation = idleRightAnimation;
          lastDirection = LastDirection.right;
        default:
          animation = switch (lastDirection) {
            LastDirection.left => idleLeftAnimation,
            LastDirection.right => idleRightAnimation
          };
      }
    }
    if (!game.movementJoystick.delta.isZero() && filteredComponents.isEmpty) {
      switch (game.movementJoystick.direction) {
        case JoystickDirection.left ||
              JoystickDirection.upLeft ||
              JoystickDirection.downLeft ||
              JoystickDirection.down:
          if (game.weaponJoystick.direction == JoystickDirection.right ||
              game.weaponJoystick.direction == JoystickDirection.downRight ||
              game.weaponJoystick.direction == JoystickDirection.upRight) {
            animation = runRightAnimation;
            lastDirection = LastDirection.right;
          } else {
            animation = runLeftAnimation;
            lastDirection = LastDirection.left;
          }

        case JoystickDirection.right ||
              JoystickDirection.upRight ||
              JoystickDirection.downRight ||
              JoystickDirection.up:
          if (game.weaponJoystick.direction == JoystickDirection.left ||
              game.weaponJoystick.direction == JoystickDirection.downLeft ||
              game.weaponJoystick.direction == JoystickDirection.upLeft) {
            animation = runLeftAnimation;
            lastDirection = LastDirection.left;
          } else {
            animation = runRightAnimation;
            lastDirection = LastDirection.right;
          }
        default:
          animation = switch (lastDirection) {
            LastDirection.left => idleLeftAnimation,
            LastDirection.right => idleRightAnimation
          };
      }
      _lastSize.setFrom(size);
      _lastTransform.setFrom(transform);
      position.add(game.movementJoystick.relativeDelta * maxSpeed * dt);
      // angle = game.movementJoystick.delta.screenAngle();
    } else {
      animation = switch (lastDirection) {
        LastDirection.left => idleLeftAnimation,
        LastDirection.right => idleRightAnimation
      };
    }
  }

  Set<PositionComponent> getFilteredComponents(
      Set<PositionComponent> components) {
    return components
        .where((component) =>
            component is! BulletComponent &&
            component is! Enemy2Component &&
            component is! CoinComponent)
        .toSet();
  }

  @override
  void onMount() {
    // debugMode = true;
    size = Vector2.all(playerRadius * 4);
    anchor = Anchor.center;
    super.onMount();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is BorderComponent) {
      transform.setFrom(_lastTransform);
      size.setFrom(_lastSize);
    } else if (other is EnemyComponent) {
      ref.read(gameNotifierProvider.notifier).reduceHealth();
      other.showDeathSplashEffect();
      other.removeFromParent();
      FlameAudio.play('gameov.wav');
      if (ref.read(gameNotifierProvider).health == 0) {
        game.gameOver();
      }
    } else if (other is CoinComponent) {
      FlameAudio.play('coinSound2.wav');
      ref.read(gameNotifierProvider.notifier).updateScore();
      ref.read(gameNotifierProvider.notifier).increaseXP();
      other.removeFromParent();
    }
  }
}

enum LastDirection {
  left,
  right,
}
