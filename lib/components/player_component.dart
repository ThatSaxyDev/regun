import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/border_component.dart';
import 'package:regun/components/bullet_component.dart';
import 'package:regun/components/enemy_component.dart';
import 'package:regun/my_game.dart';

class PlayerComponent extends PositionComponent
    with HasGameReference<RegunGame>, CollisionCallbacks {
  PlayerComponent({
    super.position,
    this.playerRadius = 25,
  }) : super(
          priority: 20,
        );

  final double playerRadius;
  static final _paint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 10;
  static final _trailPaint = Paint()
    ..color = Colors.red.withOpacity(0.5)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;
  // late final SpawnComponent _bulletSpawner;
  double maxSpeed = 300.0;
  late final Vector2 _lastSize = size.clone();
  late final Transform2D _lastTransform = transform.clone();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      CircleHitbox(
        radius: playerRadius,
        anchor: anchor,
        collisionType: CollisionType.active,
      ),
    );
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
    // canvas.drawCircle(
    //   (size / 2).toOffset(),
    //   playerRadius,
    //   _paint,
    // );
    final halfSize = playerRadius;

    // define the path for a centered triangle
    final path = Path()
      ..moveTo(0, -halfSize) // top vertex
      ..lineTo(-halfSize, halfSize) // Bottom-left vertex
      ..lineTo(0, halfSize - 12) // center vertex
      ..lineTo(halfSize, halfSize) // Bottom-right vertex
      ..close();

    // translate canvas to center the triangle
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    // Draw the triangle
    canvas.drawPath(
      path,
      _paint,
    );

    // Restore the canvas to its original state
    canvas.restore();
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is BorderComponent) {
      transform.setFrom(_lastTransform);
      size.setFrom(_lastSize);
    } else if (other is EnemyComponent) {
      FlameAudio.play('gameov.wav');
      game.gameOver();
    }
  }
}
