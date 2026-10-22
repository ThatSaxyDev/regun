import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';

class DeathBurst extends ParticleSystemComponent
    with HasGameReference<RegunGame> {
  DeathBurst({required super.position, required Color color})
    : super(
        particle: Particle.generate(
          count: 8,
          lifespan: 0.35,
          generator: (i) {
            final angle = i * pi / 4;
            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * 60,
              acceleration: Vector2(0, 50),
              child: CircleParticle(radius: 2, paint: Paint()..color = color),
            );
          },
        ),
      );
  @override
  void onRemove() {
    game.unregisterBurst(this);
    super.onRemove();
  }
}
