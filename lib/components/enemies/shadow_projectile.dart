import 'package:regun/models/combat_health.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';

/// Hostile, non-homing bolt. Aiming is snapshotted when the boss commits.
class ShadowProjectile extends PositionComponent
    with HasGameReference<RegunGame> {
  ShadowProjectile(
      {super.position, Vector2? direction, this.speed = 260, this.ownerHealth})
      : direction = direction?.normalized(),
        super(size: Vector2.all(22), anchor: Anchor.center, priority: 20000);

  final CombatHealth? ownerHealth;
  Vector2? direction;
  final double speed;
  double _distance = 0;

  @override
  Future<void> onLoad() async {
    if (!game.registerHostileProjectile(this)) {
      removeFromParent();
      return;
    }
    if (ownerHealth?.isDead ?? false) {
      removeFromParent();
      return;
    }
    direction ??= (game.myPlayer.position - position).normalized();
    add(CircleHitbox(radius: 11, collisionType: CollisionType.passive));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (ownerHealth?.isDead ?? false) {
      removeFromParent();
      return;
    }
    if (game.gameState.gameplayState != GameplayState.playing) return;
    final before = position.clone();
    position.addScaled(direction!, speed * dt);
    _distance += speed * dt;
    if (game.segmentBlocked(before, position) ||
        _distance > 1200 ||
        !game.map.bounds.floor.contains(position.toOffset())) {
      removeFromParent();
    }
  }

  @override
  void onRemove() {
    game.unregisterHostileProjectile(this);
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final path = Path()
      ..moveTo(11, 0)
      ..lineTo(22, 11)
      ..lineTo(11, 22)
      ..lineTo(0, 11)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xffBD7397));
    canvas.drawCircle(
        const Offset(11, 11), 4, Paint()..color = const Color(0xffFFF0CD));
  }
}
