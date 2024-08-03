import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:regun/my_game.dart';

class EnemyComponent extends PositionComponent
    with HasGameReference<RegunGame> {
  EnemyComponent({super.position})
      : super(
          size: Vector2.all(enemySize),
          anchor: Anchor.center,
        );
  static final _paint = Paint()..color = Colors.white;
  static const enemySize = 30.0;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(
      RectangleHitbox(),
    );
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _paint);
  }

  // @override
  // void update(double dt) {
  //   super.update(dt);

  //   position.y += dt * 250;

  //   if (position.y > game.size.y) {
  //     removeFromParent();
  //   }
  // }

  @override
  void update(double dt) {
    super.update(dt);

    //! CENTER OF THE SCREEN
    final center = Vector2.zero();

    //! DIRECTION VECTOR FROM THE ENEMY TO THE CENTER
    final direction = (center - position).normalized();

    //! MOVE ENEMY TOWARDS CENTER
    const speed = 100; // Adjust the speed as needed
    position += direction * (speed * dt);

    //! DELETE ENEMY WHEN IT TOUCHES THE CENTER
    if ((position - center).length < 1) {
      removeFromParent();
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
                  paint: _paint,
                ),
              );
            }),
      ),
    );

    removeFromParent();
  }
}
