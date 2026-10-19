import 'package:regun/presentation/weapon_feel.dart';
import 'package:regun/components/weapons/weapon_impact.dart';
import 'package:regun/data/loadout.dart';
import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/components/enemies/enemy_3_projectile.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/models/combat_health.dart';

class BulletComponent extends PositionComponent
    with HasGameReference<RegunGame>, CollisionCallbacks {
  BulletComponent(
      {super.position,
      this.bulletRadius = 5,
      this.damage = 1,
      this.maxTravelDistance = 450,
      required Vector2 direction,
      this.speed = 700,
      Vector2? startPosition,
      super.angle,
      this.pierce = 0,
      this.bounces = 0,
      this.primary = true,
      this.weapon = WeaponType.shotgun})
      : direction = direction.normalized(),
        super(
            size: Vector2.all(bulletRadius * 2),
            anchor: Anchor.center,
            priority: 20000);
  final double bulletRadius, speed, maxTravelDistance;
  double damage;
  final Vector2 direction;
  final bool primary;
  final WeaponType weapon;
  int pierce, bounces;
  double _travelled = 0;
  bool _bouncedThisFrame = false;
  final _hitEnemies = <PositionComponent>{};

  @override
  Future<void> onLoad() async {
    if (!game.registerProjectile(this)) {
      removeFromParent();
      return;
    }
    add(CircleHitbox(collisionType: CollisionType.active));
  }

  @override
  void onRemove() {
    game.unregisterProjectile(this);
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final feel = WeaponFeel.of(weapon);
    final center = Offset(size.x / 2, size.y / 2);
    final length = primary ? min(feel.trail, _travelled + 5) : 12.0;
    final ink = Paint()..strokeCap = StrokeCap.square;
    if (weapon == WeaponType.arcCaster && primary) {
      final path = Path()
        ..moveTo(center.dx - length, center.dy)
        ..lineTo(center.dx - length * .6, center.dy - 3)
        ..lineTo(center.dx - length * .25, center.dy + 3)
        ..lineTo(center.dx, center.dy);
      ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = feel.color.withValues(alpha: .65);
      canvas.drawPath(path, ink);
      canvas.drawCircle(center, 4, Paint()..color = const Color(0xffE7FFF3));
    } else {
      ink
        ..color = (primary ? feel.color : const Color(0xffB9D5C5))
            .withValues(alpha: .5)
        ..strokeWidth = weapon == WeaponType.revolver ? 3 : 2;
      canvas.drawLine(Offset(center.dx - length, center.dy), center, ink);
      canvas.drawRect(
          Rect.fromCenter(
              center: center,
              width: weapon == WeaponType.revolver ? 12 : 7,
              height: 3),
          Paint()..color = const Color(0xffFFF1C9));
    }
  }

  static double segmentDistanceSquared(
      Vector2 point, Vector2 start, Vector2 end) {
    final dx = end.x - start.x, dy = end.y - start.y;
    final denominator = dx * dx + dy * dy;
    final t = denominator == 0
        ? 0.0
        : (((point.x - start.x) * dx + (point.y - start.y) * dy) / denominator)
            .clamp(0, 1);
    final x = point.x - (start.x + dx * t), y = point.y - (start.y + dy * t);
    return x * x + y * y;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.gameState.gameplayState != GameplayState.playing || isRemoving) {
      return;
    }
    final before = position.clone();
    position.addScaled(direction, speed * dt);
    _travelled += speed * dt;
    // Sweep in travel order and stop at walls; callback order must not let a
    // fast round hit a farther body or a target behind a column first.
    _bouncedThisFrame = false;
    final targets = game.projectileTargets.where((enemy) {
      if (_hitEnemies.contains(game.projectileOwner(enemy))) return false;
      final radius = game.enemyRadius(enemy) + bulletRadius;
      return segmentDistanceSquared(enemy.position, before, position) <=
              radius * radius &&
          !game.segmentBlocked(before, enemy.position);
    }).toList()
      ..sort((a, b) => before
          .distanceToSquared(a.position)
          .compareTo(before.distanceToSquared(b.position)));
    for (final enemy in targets) {
      if (isRemoving) break;
      _hit(enemy);
      if (_bouncedThisFrame) break;
    }
    if (direction.isZero() ||
        _travelled > maxTravelDistance ||
        !game.map.bounds.floor.contains(position.toOffset()) ||
        game.segmentBlocked(before, position)) {
      removeFromParent();
    }
  }

  void _hit(PositionComponent other) {
    final owner = game.projectileOwner(other);
    if (_hitEnemies.contains(owner) ||
        !game.hitEnemy(other, damage, primary: primary, direction: direction)) {
      return;
    }
    _hitEnemies.add(owner);
    if (primary && game.claimWeaponImpact()) {
      game.addCombatEffect(WeaponImpact(
          position: other.position.clone(),
          weapon: weapon,
          direction: direction));
      game.audio.play('impact_${weapon.name}.wav');
    }
    if (bounces > 0) {
      final next =
          game.nearestEnemy(other.position, excluding: _hitEnemies, range: 500);
      if (next != null) {
        bounces--;
        _bouncedThisFrame = true;
        damage *= min(1.15, 0.7 + game.gameState.rank(PowerUp.bankShot) * 0.15);
        position.setFrom(other.position);
        direction.setFrom((next.position - position).normalized());
        angle = atan2(direction.y, direction.x);
        return;
      }
    }
    if (pierce > 0) {
      pierce--;
    } else {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (game.gameState.gameplayState != GameplayState.playing ||
        isRemoving ||
        !isMounted ||
        other.isRemoving) {
      return;
    }
    if (other is Enemy3Projectile) {
      other.removeFromParent();
      removeFromParent();
    } else if (other is Damageable) {
      _hit(other);
    }
  }
}
