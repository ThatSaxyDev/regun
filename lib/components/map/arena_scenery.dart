import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/wall_art.dart';

/// Sparse authored landmarks and grounded props, sharing the actual collision
/// layout. Static prop depth is compared to the actors' ground/foot positions.
class ArenaScenery extends PositionComponent with HasGameReference<RegunGame> {
  ArenaScenery() : super(priority: -80);
  @override
  Future<void> onLoad() async {
    final foundry = game.loadout.arena == ArenaType.foundry;
    for (final rect in game.geometry.obstacles) {
      await game.world.add(_ArenaProp(rect, foundry ? 4 : 0));
    }
  }

  @override
  void render(Canvas canvas) {
    final visible = game.camera.visibleWorldRect;
    final foundry = game.loadout.arena == ArenaType.foundry;
    final floor = game.map.bounds.floor;
    canvas.save();
    canvas.clipRect(floor);
    final stencil = Paint()
      ..color = (foundry ? const Color(0xffB78243) : const Color(0xffB3AD87))
          .withValues(alpha: .24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    // Broken containment seals and short guide markings replace a full grid.
    for (final point in [
      Offset.zero,
      const Offset(-1300, 1000),
      const Offset(1250, -1100),
    ]) {
      if (!visible.inflate(300).contains(point)) continue;
      final ring = Rect.fromCircle(center: point, radius: 230);
      for (var i = 0; i < 8; i++) {
        canvas.drawArc(ring, i * pi / 4, .5, false, stencil);
      }
      for (final side in [-1.0, 1.0]) {
        canvas.drawLine(
          point + Offset(side * 280, -70),
          point + Offset(side * 460, -70),
          stencil,
        );
        canvas.drawLine(
          point + Offset(side * 280, 70),
          point + Offset(side * 460, 70),
          stencil,
        );
      }
    }
    if (foundry) {
      for (final vent in game.map.vents) {
        if (!visible.inflate(150).contains(vent.toOffset())) continue;
        final sprite = RegunArt.shared.rawSprite('arenas/props', 5);
        sprite.render(
          canvas,
          position: vent - Vector2(90, 42),
          size: Vector2(180, 84),
        );
      }
    }
    // Same existing 24px edge trim and collision bounds, now with material faces.
    WallArt.perimeter(canvas, floor, iron: foundry, inside: true);
    // A few low debris piles, never tall scenery with invisible collision.
    for (final point in [
      const Offset(-900, 450),
      const Offset(900, -450),
      const Offset(-1600, -1500),
      const Offset(1600, 1500),
    ]) {
      if (visible.inflate(90).contains(point)) {
        RegunArt.shared
            .rawSprite('arenas/props', 7)
            .render(
              canvas,
              position: Vector2(point.dx - 45, point.dy - 20),
              size: Vector2(90, 40),
            );
      }
    }
    canvas.restore();
  }
}

class _ArenaProp extends PositionComponent with HasGameReference<RegunGame> {
  _ArenaProp(this.footprint, this.frame)
    : super(
        position: Vector2(footprint.center.dx, footprint.bottom),
        priority: 10000 + footprint.bottom.round(),
      );
  final Rect footprint;
  final int frame;
  @override
  void render(Canvas canvas) {
    if (!game.camera.visibleWorldRect.inflate(240).overlaps(footprint)) return;
    final sprite = RegunArt.shared.rawSprite('arenas/props', frame);
    final width = footprint.width * 1.25;
    final height = width * sprite.srcSize.y / sprite.srcSize.x;
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(8, -10),
        width: width + 20,
        height: footprint.height * .65,
      ),
      Paint()..color = const Color(0x750A1114),
    );
    final body = Rect.fromLTWH(
      footprint.center.dx - width / 2,
      footprint.bottom - height,
      width,
      height,
    );
    final player = game.myPlayer;
    final obscures =
        player.position.y + player.size.y * .38 < footprint.bottom &&
        body.overlaps(
          Rect.fromCenter(
            center: player.position.toOffset(),
            width: player.size.x * .65,
            height: player.size.y * .8,
          ),
        );
    sprite.render(
      canvas,
      position: Vector2(-width / 2, -height),
      size: Vector2(width, height),
      overridePaint: Paint()
        ..color = Colors.white.withValues(alpha: obscures ? .4 : 1),
    );
  }
}
