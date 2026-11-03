import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/systems/foundry_rail.dart';

class FoundryCartView extends PositionComponent
    with HasGameReference<RegunGame> {
  FoundryCartView(this.rail);

  final FoundryRail rail;

  @override
  void update(double dt) {
    super.update(dt);
    priority = 10000 + rail.bodyAt(game.director.elapsed).bottom.round();
  }

  @override
  void render(Canvas canvas) {
    if (!game.foundryRailActive) return;
    final clock = game.director.elapsed;
    final body = rail.bodyAt(clock);
    if (!game.camera.visibleWorldRect.overlaps(body.inflate(100))) return;
    final moving = rail.moving(clock);
    final liveLamps = moving || rail.warning(clock);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        body.shift(const Offset(5, 8)),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0x990b0c0d),
    );
    final paint = Paint()..filterQuality = FilterQuality.none;
    void sprite(String key) {
      final image = RegunArt.shared.image('arenas/$key');
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        body,
        paint,
      );
    }

    sprite('foundry_cart');
    if (liveLamps) {
      sprite('foundry_cart_lamps');
      final nose = Offset(
        body.center.dx,
        rail.southbound(clock) ? body.bottom - 11 : body.top + 11,
      );
      canvas.drawOval(
        Rect.fromCenter(center: nose, width: 110, height: 92),
        Paint()
          ..shader = ui.Gradient.radial(nose, 55, [
            const Color(0x42ffad42),
            const Color(0x00ffad42),
          ]),
      );
    }
    if (!moving || game.preferences.reducedMotion) return;
    final phase = ((clock + rail.offset) * 2.4) % 1;
    if (phase > .31) return;
    final direction = rail.southbound(clock) ? -1 : 1;
    final side = ((clock + rail.offset) * 2.4).floor().isEven ? -1 : 1;
    for (var i = 0; i < 4; i++) {
      final x = body.center.dx + side * (43 + phase * (20 + i * 16));
      final y = body.center.dy + direction * (51 + phase * (28 + i * 22));
      final color = i == 0 ? const Color(0xffffd784) : const Color(0xffb66d38);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: 2 + i % 2, height: 3),
        paint..color = color.withValues(alpha: 1 - phase * 3),
      );
    }
  }
}
