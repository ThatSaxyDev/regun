import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/supply_pod_art.dart';
import 'package:regun/systems/supply_drops.dart';
import 'package:regun/theme/pixel_glyph.dart';

/// Explicit objective UI, separate from enemy attack warnings. Its segmented
/// brass floor stencil lights up underfoot; dust and shadows remain below actors.
class SupplyDropField extends PositionComponent
    with HasGameReference<RegunGame> {
  SupplyDropField() : super(priority: -20);
  @override
  void render(Canvas canvas) {
    final d = game.supplyDrops.drop;
    if (d == null ||
        game.bossRush ||
        !RegunArt.shared.contains('arenas/supply_pod') ||
        !RegunArt.shared.contains('effects/landing_dust') ||
        !game.camera.visibleWorldRect.inflate(300).contains(d.position)) {
      return;
    }
    canvas.save();
    canvas.translate(d.position.dx, d.position.dy);
    final breaking = d.phase == SupplyPhase.breaking;
    final fade = breaking ? (1 - d.elapsed / 1.3).clamp(0.0, 1.0) : 1.0;
    final active = d.phase == SupplyPhase.active;
    final lit = active && d.inside;
    final color = lit ? const Color(0xffE1BA78) : const Color(0xff827767);
    final ink = Paint()..isAntiAlias = false;
    if (lit) {
      final polygon = Path();
      for (var i = 0; i < 40; i++) {
        final angle = i * math.pi / 20;
        final p = AttackVfx.snap(
          Offset(math.cos(angle), math.sin(angle)) * SupplyDrop.radius,
        );
        if (i == 0) {
          polygon.moveTo(p.dx, p.dy);
        } else {
          polygon.lineTo(p.dx, p.dy);
        }
      }
      polygon.close();
      canvas.drawPath(polygon, ink..color = color.withValues(alpha: .065));
    }
    for (var i = 0; i < 32; i++) {
      final a = i * math.pi / 16;
      canvas.save();
      canvas.rotate(a);
      canvas.drawRect(
        const Rect.fromLTWH(SupplyDrop.radius - 9, -3, 15, 6),
        ink..color = const Color(0xff17141c).withValues(alpha: .8 * fade),
      );
      canvas.drawRect(
        const Rect.fromLTWH(SupplyDrop.radius - 7, -2, 11, 4),
        ink..color = color.withValues(alpha: (lit ? .95 : .48) * fade),
      );
      canvas.restore();
    }
    for (final x in [-1.0, 1.0]) {
      for (final y in [-1.0, 1.0]) {
        final p = Offset(
          x * SupplyDrop.radius * .69,
          y * SupplyDrop.radius * .69,
        );
        canvas.drawPath(
          controlPlate(
            Rect.fromCenter(center: p, width: 17, height: 17),
            cut: 3,
          ),
          ink..color = color.withValues(alpha: .65 * fade),
        );
      }
    }
    SupplyPodArt.ground(
      canvas,
      Offset.zero,
      landed: d.solid || breaking,
      opacity: fade,
    );
    if (d.phase == SupplyPhase.warning || d.phase == SupplyPhase.falling) {
      // The small central pad, rather than the capture perimeter, marks crush.
      AttackVfx.stamp(
        canvas,
        0,
        const Offset(0, 24),
        124,
        height: 92,
        alpha: .55,
        grading: BossArt.ambient(game.loadout.arena),
      );
      for (final side in [-1.0, 1.0]) {
        AttackVfx.stroke(
          canvas,
          [Offset(side * 62, -36), Offset(side * 62, 36)],
          const Color(0xffC58D66),
          5,
        );
      }
    }
    final dustAge = breaking
        ? d.elapsed
        : d.phase == SupplyPhase.active
        ? d.elapsed
        : 9.0;
    if (dustAge < 1.2) {
      final frame = game.preferences.reducedMotion
          ? 2
          : (dustAge / .3).floor().clamp(0, 3);
      final dust = RegunArt.shared.rawSprite('effects/landing_dust', frame);
      // Desaturate generated grit into the same stone ambient as the arena.
      dust.render(
        canvas,
        position: Vector2(0, 23),
        size: Vector2(290, 290 * dust.srcSize.y / dust.srcSize.x),
        anchor: Anchor.bottomCenter,
        overridePaint: Paint()
          ..filterQuality = FilterQuality.none
          ..color = Colors.white.withValues(
            alpha: (1 - dustAge / 1.2).clamp(0, 1) * .72,
          )
          ..colorFilter = const ColorFilter.matrix([
            .23,
            .46,
            .09,
            0,
            0,
            .22,
            .47,
            .10,
            0,
            0,
            .21,
            .43,
            .13,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
      );
    }
    canvas.restore();
  }
}

class SupplyDropBody extends PositionComponent
    with HasGameReference<RegunGame> {
  @override
  void update(double dt) {
    super.update(dt);
    priority = 10000 + (game.supplyDrops.drop?.position.dy.round() ?? 0);
  }

  @override
  void render(Canvas canvas) {
    final d = game.supplyDrops.drop;
    if (d == null ||
        game.bossRush ||
        !RegunArt.shared.contains('arenas/supply_pod') ||
        !RegunArt.shared.contains('effects/landing_dust') ||
        !game.camera.visibleWorldRect.inflate(350).contains(d.position)) {
      return;
    }
    canvas.save();
    canvas.translate(d.position.dx, d.position.dy);
    if (d.phase != SupplyPhase.warning) {
      final art = RegunArt.shared;
      final sprite = art.rawSprite('arenas/supply_pod', d.claimed ? 1 : 0);
      final reference = art.rawSprite('arenas/supply_pod', 0).srcSize.x;
      final size = sprite.srcSize * (SupplyPodArt.width / reference);
      final falling = d.phase == SupplyPhase.falling;
      final q = (d.elapsed / .65).clamp(0.0, 1.0);
      final height = falling && !game.preferences.reducedMotion
          ? 220 * (1 - q * q)
          : 0.0;
      final breaking = d.phase == SupplyPhase.breaking;
      final p = breaking ? (d.elapsed / 1.3).clamp(0.0, 1.0) : 0.0;
      final paint = Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = BossArt.ambient(game.loadout.arena)
        ..color = Colors.white.withValues(
          alpha: breaking
              ? 1 - p
              : falling && game.preferences.reducedMotion
              ? q
              : 1,
        );
      // Four heavy shell panels separate and settle; Reduced Motion fades the
      // complete object in place. This leaves no permanent collision/debris.
      for (
        var i = 0;
        i < (breaking && !game.preferences.reducedMotion ? 4 : 1);
        i++
      ) {
        canvas.save();
        if (breaking && !game.preferences.reducedMotion) {
          final side = i < 2 ? -1 : 1;
          canvas.translate(side * p * (8 + i * 3), p * p * 18);
          canvas.clipRect(
            Rect.fromLTWH(
              -size.x / 2 + i * size.x / 4 - 1,
              -size.y - 4,
              size.x / 4 + 2,
              size.y + 8,
            ),
          );
        }
        sprite.render(
          canvas,
          position: Vector2(0, -height),
          size: size,
          anchor: Anchor.bottomCenter,
          overridePaint: paint,
        );
        canvas.restore();
      }
    }
    _badge(canvas, d);
    canvas.restore();
  }

  void _badge(Canvas canvas, SupplyDrop d) {
    final waiting =
        d.phase == SupplyPhase.warning || d.phase == SupplyPhase.falling;
    final label = waiting
        ? 'INCOMING'
        : d.phase == SupplyPhase.opened
        ? 'SECURED'
        : d.phase == SupplyPhase.breaking
        ? 'OFFLINE'
        : d.inside
        ? 'SECURING'
        : 'AIRDROP';
    final tone = d.inside ? const Color(0xffE1BA78) : const Color(0xffB4A797);
    const rect = Rect.fromLTWH(-120, -174, 240, 64);
    canvas.drawPath(
      controlPlate(rect, cut: 8),
      Paint()..color = const Color(0xe6201b23),
    );
    canvas.drawPath(
      controlPlate(rect.deflate(1), cut: 7),
      Paint()
        ..color = tone
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final title = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontFamily: 'PressStart2P', fontSize: 16, color: tone),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(canvas, Offset(-title.width / 2, -163));
    if (d.phase == SupplyPhase.active && !d.inside) {
      final hint = TextPainter(
        text: const TextSpan(
          text: 'Hold for upgrade',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 14,
            color: Color(0xffB4A797),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      hint.paint(canvas, const Offset(-102, -145));
    }
    if (d.phase == SupplyPhase.active) {
      for (var i = 0; i < 16; i++) {
        canvas.drawRect(
          Rect.fromLTWH(-102 + i * 10, -132, 7, 7),
          Paint()
            ..color = i / 16 < d.capture / SupplyDrop.captureSeconds
                ? const Color(0xffE1BA78)
                : const Color(0xff4C4047),
        );
      }
      final time = TextPainter(
        text: TextSpan(
          text: '${(SupplyDrop.lifetime - d.life).ceil()}s',
          style: const TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 16,
            color: Color(0xffDED4C5),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      time.paint(canvas, const Offset(68, -139));
    }
  }
}

/// A quiet edge tag keeps a planted drop findable when the player retreats.
class SupplyDropLocator extends PositionComponent
    with HasGameReference<RegunGame> {
  SupplyDropLocator() : super(priority: 90000);
  @override
  void render(Canvas canvas) {
    final d = game.supplyDrops.drop;
    final view = game.camera.visibleWorldRect;
    if (d == null ||
        game.bossRush ||
        view.contains(d.position) ||
        d.phase == SupplyPhase.breaking ||
        d.phase == SupplyPhase.opened) {
      return;
    }
    final size = game.camera.viewport.virtualSize;
    final raw = Offset(
      (d.position.dx - view.left) / view.width * size.x,
      (d.position.dy - view.top) / view.height * size.y,
    );
    final point = Offset(
      raw.dx.clamp(180, size.x - 180),
      raw.dy.clamp(180, size.y - 220),
    );
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.drawPath(
      controlPlate(const Rect.fromLTWH(-72, -28, 144, 70), cut: 8),
      Paint()..color = const Color(0xdb201b23),
    );
    canvas.save();
    canvas.rotate(math.atan2(raw.dy - point.dy, raw.dx - point.dx));
    AttackVfx.stroke(
      canvas,
      const [Offset(-10, -9), Offset(3, 0), Offset(-10, 9)],
      const Color(0xffE1BA78),
      4,
    );
    canvas.restore();
    final text = TextPainter(
      text: const TextSpan(
        text: 'AIRDROP',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 14,
          color: Color(0xffE1BA78),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(-text.width / 2, 20));
    canvas.restore();
  }
}
