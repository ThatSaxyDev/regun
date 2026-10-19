import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

class SpawnWarning extends PositionComponent {
  SpawnWarning({required this.game, required this.enemy})
      : super(position: enemy.position.clone(), priority: -5);
  final RegunGame game;
  final PositionComponent enemy;
  double elapsed = 0;
  bool _spawned = false;
  @override
  void update(double dt) {
    super.update(dt);
    if (parent != game.world) {
      removeFromParent();
      return;
    }
    if (game.gameState.gameplayState != GameplayState.playing) return;
    elapsed += dt;
    if (elapsed >= 0.8) {
      _spawned = true;
      game.world.add(enemy);
      removeFromParent();
    }
  }

  @override
  void onRemove() {
    if (!_spawned) game.unregisterEnemy(enemy);
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xffB4A17D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, 38, paint);
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: 30), -pi / 2,
        (elapsed / 0.8).clamp(0, 1) * pi * 2, false, paint);
    canvas.drawLine(const Offset(-8, 0), const Offset(8, 0), paint);
    canvas.drawLine(const Offset(0, -8), const Offset(0, 8), paint);
  }
}
