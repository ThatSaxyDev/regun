import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/attack_vfx.dart';
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
    AttackVfx.disk(
      canvas,
      Offset.zero,
      38,
      ambient: BossArt.ambient(game.loadout.arena),
      warning: true,
      progress: (elapsed / .8).clamp(0, 1),
    );
  }
}
