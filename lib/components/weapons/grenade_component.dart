import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/grenade_art.dart';
import 'package:regun/systems/grenades.dart';
import 'package:regun/systems/arena_geometry.dart';

class GrenadeComponent extends PositionComponent
    with HasGameReference<RegunGame> {
  GrenadeComponent(
    this.flight, {
    required this.damage,
    required this.blastRadius,
  }) : super(
         position: Vector2(flight.position.dx, flight.position.dy),
         priority: 20000,
       );
  final GrenadeFlight flight;
  final double damage, blastRadius;
  @override
  void update(double dt) {
    super.update(dt);
    if (isRemoving || flight.spent) return;
    if (game.gameState.gameplayState != GameplayState.playing ||
        game.playerEntrance.active) {
      return;
    }
    flight.advance(
      dt,
      blocked: (a, b) =>
          !game.geometry.bounds.floor.deflate(8).contains(b) ||
          game.geometry.obstacles.any(
            (r) => ArenaGeometry.crosses(
              Vector2(a.dx, a.dy),
              Vector2(b.dx, b.dy),
              r.inflate(8),
            ),
          ),
      contact: (a, b) => game.liveEnemies.any((e) {
        final p = Offset(e.position.x, e.position.y), ab = b - a;
        final t = ab.distanceSquared <= 1e-9
            ? 0.0
            : (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) /
                      ab.distanceSquared)
                  .clamp(0.0, 1.0);
        return (p - (a + ab * t)).distance <= game.crowdRadius(e) + 8;
      }),
    );
    position.setValues(flight.position.dx, flight.position.dy);
    if (flight.spent) {
      game.explode(position, radius: blastRadius, damage: damage);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 24, height: 9),
      Paint()..color = const Color(0x700c1012),
    );
    paintGrenade(
      canvas,
      Offset(0, game.preferences.reducedMotion ? 0 : -flight.height),
      28,
      angle: game.preferences.reducedMotion ? 0 : flight.spin,
    );
  }

  Map<String, dynamic> checkpoint() => {
    ...flight.toJson(),
    'damage': damage,
    'radius': blastRadius,
  };
}

class GrenadeButtonComponent extends PositionComponent
    with TapCallbacks, HasGameReference<RegunGame> {
  GrenadeButtonComponent()
    : super(size: Vector2.all(112), anchor: Anchor.center);
  double flash = 0;
  @override
  void onTapDown(TapDownEvent event) {
    if (game.throwGrenade()) flash = .14;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.gameState.gameplayState == GameplayState.playing) {
      flash = (flash - dt).clamp(0, .14);
    }
  }

  @override
  void render(Canvas canvas) {
    final g = game.grenades;
    GrenadeButtonPainter(
      charges: g.charges,
      progress: g.progress,
      remaining: g.remaining,
      pressed: flash > 0,
      opacity: game.controls.opacity,
    ).paint(canvas, Size(size.x, size.y));
  }
}
