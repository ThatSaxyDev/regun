import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/bullet_component.dart';
import 'package:regun/my_game.dart';

class PlayerComponent extends PositionComponent
    with HasGameReference<RegunGame> {
  PlayerComponent({
    super.position,
    this.playerRadius = 20,
  }) : super(
          priority: 20,
        );

  final double playerRadius;
  static final _paint = Paint()..color = Colors.red;
  late final SpawnComponent _bulletSpawner;
  double maxSpeed = 300.0;
  late final Vector2 _lastSize = size.clone();
  late final Transform2D _lastTransform = transform.clone();

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // _bulletSpawner = SpawnComponent(
    //   period: 0.2,
    //   selfPositioning: true,
    //   factory: (amount) {
    //     return BulletComponent(
    //       position: position + Vector2(0, -height / 2),
    //     );
    //   },
    //   autoStart: false,
    // );

    // game.world.add(_bulletSpawner);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!game.movementJoystick.delta.isZero()) {
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

  void move(Vector2 delta) {
    position.add(delta);
  }

  void startShooting() {
    _bulletSpawner.timer.start();
  }

  void stopShooting() {
    _bulletSpawner.timer.stop();
  }
}
