import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/border_component.dart';
import 'package:regun/components/bullet_component.dart';
import 'package:regun/components/enemy_component.dart';
import 'package:regun/my_game.dart';

class PlayerComponent extends PositionComponent
    with HasGameReference<RegunGame>, CollisionCallbacks {
  PlayerComponent({
    super.position,
    this.playerRadius = 20,
  }) : super(
          priority: 20,
        );

  final double playerRadius;
  static final _paint = Paint()..color = Colors.red;
  // late final SpawnComponent _bulletSpawner;
  double maxSpeed = 300.0;
  late final Vector2 _lastSize = size.clone();
  late final Transform2D _lastTransform = transform.clone();

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(
      CircleHitbox(
        radius: playerRadius,
        anchor: anchor,
        collisionType: CollisionType.active,
      ),
    );
    // _bulletSpawner = SpawnComponent(
    //   period: 0.2,
    //   selfPositioning: true,
    //   factory: (amount) {
    //     return BulletComponent(
    //       position: position,
    //       direction: game.weaponJoystick.relativeDelta.normalized(),
    //     );
    //   },
    //   autoStart: false,
    // );

    // game.world.add(_bulletSpawner);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!game.movementJoystick.delta.isZero() && activeCollisions.isEmpty) {
      _lastSize.setFrom(size);
      _lastTransform.setFrom(transform);
      position.add(game.movementJoystick.relativeDelta * maxSpeed * dt);
      angle = game.movementJoystick.delta.screenAngle();
    }
  }

  @override
  void onMount() {
    size = Vector2.all(playerRadius * 2);
    anchor = Anchor.center;
    super.onMount();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      (size / 2).toOffset(),
      playerRadius,
      _paint,
    );
  }

  void startShooting() {
    // print('shooting');
    // _bulletSpawner.timer.start();
  }

  void stopShooting() {
    // _bulletSpawner.timer.stop();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is BorderComponent) {
      transform.setFrom(_lastTransform);
      size.setFrom(_lastSize);
    } else if (other is EnemyComponent) {
      game.gameOver();
    }
  }
}
