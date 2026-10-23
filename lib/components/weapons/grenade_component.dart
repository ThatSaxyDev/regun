import 'package:regun/components/enemies/ground_projection.dart';

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
  GroundProjection? _shadow;
  @override
  void onMount() {
    super.onMount();
    _shadow = GroundProjection(this, (canvas) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 24, height: 9),
        Paint()..color = const Color(0x700c1012),
      );
    });
    game.world.add(_shadow!);
  }

  @override
  void onRemove() {
    _shadow?.removeFromParent();
    super.onRemove();
  }

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
          game.geometry.solids.any(
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
      game.combat.explode(
        position,
        radius: blastRadius,
        damage: damage,
        grenade: true,
      );
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
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
    with TapCallbacks, DragCallbacks, HasGameReference<RegunGame> {
  GrenadeButtonComponent()
    : super(size: Vector2.all(112), anchor: Anchor.center);
  double flash = 0;
  final aim = GrenadeAim();
  int? _dragPointer;
  bool get available =>
      game.grenades.ready &&
      game.gameState.gameplayState == GameplayState.playing &&
      !game.playerEntrance.active;
  void cancelAim() {
    aim.cancel();
    _dragPointer = null;
  }

  void release(int pointer) {
    if (aim.pointer != pointer) return;
    final direction = aim.direction;
    if (!aim.cancelled &&
        available &&
        game.throwGrenade(
          aim: direction == null ? null : Vector2(direction.dx, direction.dy),
          power: aim.power(game.controlButtonSize * .85),
        )) {
      flash = .14;
    }
    aim.cancel();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (available) aim.begin(event.pointerId, event.canvasPosition.toOffset());
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (_dragPointer == null) release(event.pointerId);
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    Future.microtask(() {
      if (_dragPointer == null && aim.pointer == event.pointerId) aim.cancel();
    });
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (_dragPointer != null) return;
    super.onDragStart(event);
    if (available) {
      _dragPointer = event.pointerId;
      if (!aim.active) {
        aim.begin(event.pointerId, event.canvasPosition.toOffset());
      }
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dragPointer == event.pointerId && aim.pointer != null) {
      aim.move(
        aim.pointer!,
        aim.origin + aim.delta + event.canvasDelta.toOffset(),
      );
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (_dragPointer != null && _dragPointer != event.pointerId) return;
    super.onDragEnd(event);
    if (_dragPointer == event.pointerId) {
      if (aim.pointer != null) release(aim.pointer!);
      _dragPointer = null;
    }
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    if (_dragPointer != null && _dragPointer != event.pointerId) return;
    aim.cancel();
    super.onDragCancel(event);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!available) aim.cancel();
    if (game.gameState.gameplayState == GameplayState.playing) {
      flash = (flash - dt).clamp(0, .14);
    }
  }

  @override
  void render(Canvas canvas) {
    final g = game.grenades;
    GrenadeButtonPainter(
      charges: g.charges,
      capacity: g.capacity,
      progress: g.progress,
      remaining: g.remaining,
      pressed: flash > 0 || aim.active,
      aim: aim.direction,
      cancelled: aim.cancelled,
      opacity: game.controls.opacity,
    ).paint(canvas, Size(size.x, size.y));
  }
}

class GrenadeAimPreview extends PositionComponent
    with HasGameReference<RegunGame> {
  GrenadeAimPreview() : super(priority: -5);
  @override
  void render(Canvas canvas) {
    final input = game.grenadeButtonComponent.aim;
    if (!input.active ||
        input.cancelled ||
        !game.grenadeButtonComponent.available) {
      return;
    }
    final direction = input.direction;
    final flight = game.grenadeFlight(
      direction == null
          ? game.quickGrenadeDirection
          : Vector2(direction.dx, direction.dy),
      input.power(game.controlButtonSize * .85),
    );
    final points = grenadePreview(
      flight,
      blocked: (a, b) =>
          !game.geometry.bounds.floor.deflate(8).contains(b) ||
          game.geometry.solids.any(
            (r) => ArenaGeometry.crosses(
              Vector2(a.dx, a.dy),
              Vector2(b.dx, b.dy),
              r.inflate(8),
            ),
          ),
      contact: (a, b) => game.liveEnemies.any(
        (e) => grenadeSegmentContact(
          a,
          b,
          e.position.toOffset(),
          game.crowdRadius(e) + 8,
        ),
      ),
    );
    paintGrenadeTrajectory(
      canvas,
      points,
      reducedMotion: game.preferences.reducedMotion,
    );
  }
}
