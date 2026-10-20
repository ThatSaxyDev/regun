import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/game.dart';

class Enemy3Projectile extends PositionComponent
    with HasGameReference<RegunGame>, CollisionCallbacks {
  Enemy3Projectile(
      {super.position,
      this.bulletRadius = 7,
      this.maxTravelDistance = 900,
      this.speed = 300,
      this.startPosition,
      super.angle})
      : super(
            size: Vector2.all(bulletRadius * 2),
            anchor: Anchor.center,
            priority: 20000) {
    startPosition = position.clone();
  }

  final double bulletRadius;
  final double speed;
  final double maxTravelDistance;
  Vector2? startPosition;
  final _velocity = Vector2.zero();

  @override
  Future<void> onLoad() async {
    if (!game.registerHostileProjectile(this)) {
      removeFromParent();
      return;
    }
    add(CircleHitbox(collisionType: CollisionType.passive));
    _velocity.setFrom((game.myPlayer.position - position).normalized() * speed);
  }

  @override
  void onRemove() {
    game.unregisterHostileProjectile(this);
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(atan2(_velocity.y, _velocity.x));
    paintDart(canvas);
    canvas.restore();
  }

  /// Iron fins, a pointed nose and a short ragged wake. Unlike the round brass
  /// pickups, this silhouette shows its committed direction even without color.
  static void paintDart(Canvas canvas) {
    final ink = Paint()..isAntiAlias = false;
    void block(double x, double y, double w, double h, int color) {
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), ink..color = Color(color));
    }

    block(-29, -2, 7, 4, 0x55784665);
    block(-20, -4, 9, 3, 0x99784665);
    block(-22, 2, 8, 3, 0x99784665);
    // Keep the painted iron/ember texture, but remove the brass pickup color
    // and stretch its two pointed ends into a long hostile silhouette.
    canvas.save();
    canvas.scale(1, .48);
    canvas.rotate(pi / 4);
    RegunArt.shared.rawSprite('items/items', 7).render(canvas,
        size: Vector2.all(30), anchor: Anchor.center,
        overridePaint: Paint()
          ..filterQuality = FilterQuality.none
          ..colorFilter = const ColorFilter.matrix([
            .60, .20, .10, 0, 12,
            .18, .33, .08, 0, 0,
            .45, .20, .25, 0, 12,
            0, 0, 0, 1, 0,
          ]));
    canvas.restore();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isRemoving || game.gameState.gameplayState != GameplayState.playing) {
      return;
    }
    final before = position.clone();
    position.addScaled(_velocity, dt);
    if (game.segmentBlocked(before, position) ||
        position.distanceToSquared(startPosition!) >
            maxTravelDistance * maxTravelDistance ||
        !game.map.bounds.rect.contains(position.toOffset())) {
      removeFromParent();
    }
  }
}
