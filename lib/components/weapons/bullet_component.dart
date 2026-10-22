import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/weapon_feel.dart';
import 'package:regun/components/weapons/weapon_impact.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/systems/weapon_ballistics.dart';

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
  BulletComponent({
    super.position,
    this.bulletRadius = 5,
    double initialDelay = 0,
    this.damage = 1,
    this.maxTravelDistance = 450,
    required Vector2 direction,
    this.speed = 700,
    Vector2? startPosition,
    super.angle,
    this.pierce = 0,
    this.bounces = 0,
    this.primary = true,
    this.weapon = WeaponType.shotgun,
  })
    // The public named delay describes a release within the current frame.
    // ignore: prefer_initializing_formals
    : _initialDelay = initialDelay,
       _baseDamage = damage,
       direction = direction.normalized(),
       super(
         size: Vector2.all(bulletRadius * 2),
         anchor: Anchor.center,
         priority: 20000,
       );
  final double bulletRadius, speed, maxTravelDistance;
  double damage;
  final double _baseDamage;
  final Vector2 direction;
  final bool primary;
  final WeaponType weapon;
  int pierce, bounces;
  double _travelled = 0;
  double _initialDelay;
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
      AttackVfx.lightning(
        canvas,
        center - Offset(length, 0),
        center,
        1,
        heavy: true,
      );
      AttackVfx.chip(canvas, center, 7, const Color(0xffDCE5C7));
      for (final side in [-1, 1]) {
        AttackVfx.chip(
          canvas,
          center + Offset(-18, side * 9),
          4,
          const Color(0xff8EA99B),
        );
      }
    } else {
      final round = WeaponFeel.round(weapon);
      ink
        ..color = (primary ? feel.color : const Color(0xffB9D5C5)).withValues(
          alpha: .5,
        )
        ..strokeWidth = primary ? round.trailWidth : 2;
      canvas.drawLine(Offset(center.dx - length, center.dy), center, ink);
      final l = primary ? round.length : 7.0;
      final h = primary ? round.thickness : 3.0;
      final left = center.dx - l / 2, right = center.dx + l / 2;
      final body = Path()
        ..addPolygon([
          Offset(left, center.dy - h / 2),
          Offset(right - 3, center.dy - h / 2),
          Offset(right, center.dy - h / 2 + 2),
          Offset(right, center.dy + h / 2 - 2),
          Offset(right - 3, center.dy + h / 2),
          Offset(left, center.dy + h / 2),
        ], true);
      canvas.drawPath(
        body.shift(const Offset(0, 2)),
        Paint()..color = const Color(0xff5C4431),
      );
      canvas.drawPath(body, Paint()..color = feel.color);
      canvas.drawRect(
        Rect.fromLTWH(left + 2, center.dy - 1, l - 4, 2),
        Paint()..color = const Color(0xffFFF1C9),
      );
    }
  }

  static double segmentDistanceSquared(
    Vector2 point,
    Vector2 start,
    Vector2 end,
  ) {
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
    if (_initialDelay > 0) {
      final waiting = min(dt, _initialDelay);
      _initialDelay -= waiting;
      dt -= waiting;
      if (dt <= 0) return;
    }
    final before = position.clone();
    final travelBefore = _travelled;
    final step = min(speed * dt, max(0.0, maxTravelDistance - _travelled));
    position.addScaled(direction, step);
    _travelled += step;
    // Sweep in travel order and stop at walls; callback order must not let a
    // fast round hit a farther body or a target behind a column first.
    _bouncedThisFrame = false;
    final targets =
        game.projectileTargets.where((enemy) {
          if (_hitEnemies.contains(game.projectileOwner(enemy))) return false;
          final radius = game.enemyRadius(enemy) + bulletRadius;
          return segmentDistanceSquared(enemy.position, before, position) <=
                  radius * radius &&
              !game.segmentBlocked(before, enemy.position);
        }).toList()..sort(
          (a, b) =>
              contactDistance(
                a.position,
                before,
                position,
                game.enemyRadius(a) + bulletRadius,
              ).compareTo(
                contactDistance(
                  b.position,
                  before,
                  position,
                  game.enemyRadius(b) + bulletRadius,
                ),
              ),
        );
    for (final enemy in targets) {
      if (isRemoving) break;
      final radius = game.enemyRadius(enemy) + bulletRadius;
      final contact = contactDistance(enemy.position, before, position, radius);
      _hit(
        enemy,
        travelled: travelBefore + contact,
        contactPoint: before + direction * contact,
      );
      if (_bouncedThisFrame) break;
    }
    if (direction.isZero() ||
        _travelled >= maxTravelDistance ||
        !game.map.bounds.floor.contains(position.toOffset()) ||
        game.segmentBlocked(before, position)) {
      removeFromParent();
    }
  }

  /// First entry into the same body circle used by swept collision. Sampling
  /// the end of a long frame would incorrectly weaken a nearby hit.
  static double contactDistance(
    Vector2 point,
    Vector2 start,
    Vector2 end,
    double radius,
  ) {
    final delta = end - start;
    final length = delta.length;
    if (length == 0) return 0;
    final relative = point - start;
    final along = relative.dot(delta / length);
    final acrossSquared = max(0.0, relative.length2 - along * along);
    return (along - sqrt(max(0.0, radius * radius - acrossSquared))).clamp(
      0.0,
      length,
    );
  }

  void _hit(
    PositionComponent other, {
    double? travelled,
    Vector2? contactPoint,
  }) {
    final distance = travelled ?? _travelled;
    final factor = primary
        ? WeaponBallistics.of(weapon).multiplier(distance)
        : 1.0;
    // Preserve the existing hard Bank Shot ceiling after the close bonus too.
    final amount = min(_baseDamage * 2, damage * factor);
    final owner = game.projectileOwner(other);
    if (_hitEnemies.contains(owner) ||
        !game.hitEnemy(
          other,
          amount,
          primary: primary,
          direction: direction,
          armorPiercing: weapon == WeaponType.longwatchSniper,
        )) {
      return;
    }
    _hitEnemies.add(owner);
    if (primary && owner is CombatEnemy) {
      if (weapon == WeaponType.frostShotgun) owner.freeze();
      if (weapon == WeaponType.rivetDriver) game.arsenal?.lodge(owner);
    }
    if (primary && game.claimWeaponImpact()) {
      game.addCombatEffect(
        WeaponImpact(
          position: other.position.clone(),
          weapon: weapon,
          direction: direction,
        ),
      );
      game.audio.play('impact_${weapon.name}.wav');
    }
    if (bounces > 0) {
      final next = game.nearestEnemy(
        other.position,
        excluding: _hitEnemies,
        range: 500,
      );
      if (next != null) {
        bounces--;
        _bouncedThisFrame = true;
        damage = min(
          _baseDamage * 2,
          damage *
              min(
                1.4,
                0.7 + game.gameState.effectRank(PowerUp.bankShot) * 0.15,
              ),
        );
        // A ricochet keeps its cumulative path; turning never refreshes the
        // close bonus or the projectile's remaining range.
        _travelled =
            distance + (contactPoint ?? position).distanceTo(other.position);
        position.setFrom(other.position);
        direction.setFrom((next.position - position).normalized());
        angle = atan2(direction.y, direction.x);
        return;
      }
    }
    if (pierce > 0) {
      pierce--;
      if (weapon == WeaponType.railLance) damage *= .65;
    } else {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
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
