import 'package:regun/presentation/boss_art.dart';
import 'package:regun/components/enemies/expedition_walker.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

class SpawnWarning extends PositionComponent {
  SpawnWarning({required this.game, required this.enemy})
    : super(position: enemy.position.clone(), priority: -5) {
    game.registerSpawnWarning(this);
  }
  final RegunGame game;
  final PositionComponent enemy;
  static const _duration = .8;
  double elapsed = 0;
  bool get _expedition => game.expeditionMode;
  bool _spawned = false, _cancelled = false;
  void cancel() {
    _cancelled = true;
    game.unregisterEnemy(enemy);
    game.unregisterSpawnWarning(this);
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_cancelled ||
        game.isRetiredActor(enemy) ||
        (game.loadout.training && game.bossRush) ||
        parent != game.world) {
      removeFromParent();
      return;
    }
    if (game.gameState.gameplayState != GameplayState.playing) return;
    if (_expedition && elapsed == 0 && dt > 0) {
      game.playEnemyMovement('enemy_arrival.wav', position, 1300);
    }
    elapsed += dt;
    if (elapsed >= _duration &&
        (enemy is! ExpeditionWalker ||
            game.expeditionMiniWalkerSiteClear(position))) {
      _spawned = true;
      game.world.add(enemy);
      removeFromParent();
    }
  }

  @override
  void onRemove() {
    game.unregisterSpawnWarning(this);
    if (!_spawned) game.unregisterEnemy(enemy);
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    if (_expedition) {
      _renderExpeditionWarning(canvas);
      return;
    }
    AttackVfx.disk(
      canvas,
      Offset.zero,
      38,
      ambient: BossArt.ambient(game.currentArena),
      warning: true,
      progress: (elapsed / _duration).clamp(0, 1),
    );
  }

  void _renderExpeditionWarning(Canvas canvas) {
    if (!canvas.getLocalClipBounds().inflate(70).contains(Offset.zero)) return;
    final reduced = game.preferences.reducedMotion;
    final progress = reduced ? .65 : (elapsed / _duration).clamp(0.0, 1.0);
    const brass = Color(0xffffb36a);
    AttackVfx.floorArea(
      canvas,
      2,
      Offset.zero,
      112,
      alpha: .66 + .30 * progress,
      ambient: const ColorFilter.mode(Color(0xffffad6d), BlendMode.modulate),
    );
    AttackVfx.floorArea(
      canvas,
      3,
      Offset.zero,
      78,
      alpha: .26 + .42 * progress,
    );
    for (final (point, height) in const [
      (Offset(-35, -12), 29.0),
      (Offset(-17, 26), 37.0),
      (Offset(29, 18), 42.0),
      (Offset(20, -29), 31.0),
    ]) {
      AttackVfx.chip(canvas, point, 6, brass);
      final spark = point.translate(0, -height * progress);
      AttackVfx.chip(
        canvas,
        spark,
        4,
        brass.withValues(alpha: 1 - .45 * progress),
      );
    }
  }
}
