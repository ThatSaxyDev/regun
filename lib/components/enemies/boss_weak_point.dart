import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/game.dart';
import 'package:regun/models/combat_health.dart';
import 'package:regun/notifiers/game_notifier.dart';

enum BossPropKind { clasp, mirror, valve, blade, bell }

/// Targetable boss apparatus; never an enemy population/reward entry. One
/// projectile shares its hit ledger with the owning boss, not each body part.
class BossWeakPoint extends PositionComponent
    with HasGameReference<RegunGame>
    implements Damageable {
  BossWeakPoint(
      {required this.owner,
      required super.position,
      required this.kind,
      required this.onBroken,
      double health = 5})
      : combatHealth = CombatHealth(health),
        super(size: Vector2.all(58), anchor: Anchor.center, priority: 20000);
  final PositionComponent owner;
  final BossPropKind kind;
  final VoidCallback onBroken;
  @override
  final CombatHealth combatHealth;
  bool _broken = false;
  @override
  Future<void> onLoad() async {
    add(CircleHitbox(
        radius: 26,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive));
  }

  @override
  void onMount() {
    super.onMount();
    game.weakPoints.add(this);
  }

  @override
  void onRemove() {
    game.weakPoints.remove(this);
    super.onRemove();
  }

  @override
  bool takeDamage(double amount) {
    if (_broken ||
        isRemoving ||
        game.gameState.gameplayState != GameplayState.playing ||
        (owner as CombatEnemy).combatHealth.isDead) {
      return false;
    }
    final result = combatHealth.damage(amount);
    if (result == DamageResult.ignored) return false;
    // A part hit transfers reduced damage, never a second full body hit.
    (owner as CombatEnemy).takeDamage(amount * .5);
    if (result == DamageResult.killed) {
      _broken = true;
      if (!(owner as CombatEnemy).combatHealth.isDead) onBroken();
      removeFromParent();
    }
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (owner.isRemoving || (owner as CombatEnemy).combatHealth.isDead) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final brass = Paint()
      ..color = const Color(0xffE5C27F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, 25, Paint()..color = const Color(0xff29232D));
    switch (kind) {
      case BossPropKind.mirror:
        canvas.drawRect(Rect.fromCenter(center: center, width: 28, height: 46),
            Paint()..color = const Color(0xffB1C4C5));
        canvas.drawLine(center + const Offset(-10, 17),
            center + const Offset(8, -16), brass);
      case BossPropKind.valve:
        canvas.drawCircle(center, 18, brass);
        for (final end in [const Offset(18, 0), const Offset(0, 18)]) {
          canvas.drawLine(center - end, center + end, brass);
        }
      case BossPropKind.blade:
        final blade = Path()
          ..moveTo(center.dx - 9, center.dy + 22)
          ..lineTo(center.dx + 3, center.dy - 24)
          ..lineTo(center.dx + 18, center.dy - 16)
          ..lineTo(center.dx + 9, center.dy - 8);
        canvas.drawPath(blade, brass..strokeWidth = 6);
      case BossPropKind.bell:
        canvas.drawArc(Rect.fromCenter(center: center, width: 32, height: 42),
            3.14, 3.14, false, brass);
        canvas.drawLine(
            center + const Offset(-20, 6), center + const Offset(20, 6), brass);
      case BossPropKind.clasp:
        canvas.drawRect(
            Rect.fromCenter(center: center, width: 24, height: 24), brass);
        canvas.drawLine(
            center + const Offset(-19, 0), center + const Offset(19, 0), brass);
    }
    canvas.drawArc(Rect.fromCircle(center: center, radius: 27), -1.57,
        6.28 * combatHealth.fraction, false, brass..strokeWidth = 2);
  }
}
