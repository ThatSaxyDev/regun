import 'package:flutter/painting.dart';

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/systems/support_rewards.dart';
import 'package:regun/systems/support_runtime.dart';
import 'package:regun/systems/support_aim.dart';
import 'package:regun/presentation/aura_energy.dart';

/// Shared native/co-op painters: all timing and geometry come from simulation.
class SupportArt {
  static const atlases = [
    'support/base',
    'support/carbine',
    'support/burstRifle',
    'support/aura',
    'support/emitter',
  ];
  static bool get ready => atlases.every(RegunArt.shared.contains);
  static void sprite(
    Canvas canvas,
    String id,
    Offset at,
    double width, {
    double alpha = 1,
    ColorFilter? ambient,
    Anchor anchor = Anchor.center,
  }) {
    if (!RegunArt.shared.contains(id)) return;
    final s = RegunArt.shared.rawSprite(id, 0);
    s.render(
      canvas,
      position: Vector2(at.dx, at.dy),
      size: Vector2(width, width * s.srcSize.y / s.srcSize.x),
      anchor: anchor,
      overridePaint: Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0))
        ..colorFilter = ambient,
    );
  }

  static void floor(
    Canvas canvas,
    SupportUnit u,
    SupportConfig c, {
    ColorFilter? ambient,
    bool reducedMotion = false,
  }) {
    if (u.card.family == SupportFamily.aura) {
      final radius = c.auraRadius(u.card.tier);
      final alpha = u.phase == 'activating'
          ? (u.elapsed / .35).clamp(0.0, 1.0)
          : u.phase == 'fading'
          ? (1 - u.elapsed / .35).clamp(0.0, 1.0)
          : 1.0;
      canvas.save();
      canvas.translate(u.position.dx, u.position.dy);
      if (!reducedMotion) canvas.rotate(u.life * .08);
      sprite(
        canvas,
        'support/aura',
        Offset.zero,
        radius * 2,
        alpha: alpha * .42,
        ambient: ambient,
      );
      canvas.restore();
      canvas.save();
      canvas.translate(u.position.dx, u.position.dy);
      // Canvas-positive rotation is clockwise; the inner seal counters the ring.
      if (!reducedMotion) canvas.rotate(-u.life * .20);
      AuraEnergy.paint(
        canvas,
        radius,
        u.life,
        alpha,
        reducedMotion: reducedMotion,
      );
      canvas.restore();
      return;
    }
    final p = u.position;
    final fade = u.phase == 'breaking'
        ? (1 - u.elapsed / 1.3).clamp(0.0, 1.0)
        : 1.0;
    canvas.drawOval(
      Rect.fromCenter(center: p + const Offset(0, -12), width: 76, height: 22),
      Paint()..color = Color.fromRGBO(7, 10, 8, .55 * fade),
    );
    if (['following', 'finding', 'warning', 'falling'].contains(u.phase)) {
      sprite(
        canvas,
        'support/base',
        p,
        96,
        alpha: .32,
        ambient: ambient,
        anchor: Anchor.bottomCenter,
      );
      final ink = Paint()
        ..color = const Color(0xffC4B587)
        ..isAntiAlias = false;
      for (final x in [-1.0, 1.0]) {
        for (final y in [-1.0, 1.0]) {
          final a = p + Offset(x * 52.0, y * 32.0 - 20);
          canvas.drawRect(Rect.fromLTWH(a.dx, a.dy, 12 * x, 3), ink);
          canvas.drawRect(Rect.fromLTWH(a.dx, a.dy, 3, 10 * y), ink);
        }
      }
      final until = switch (u.phase) {
        'following' => c.incoming - u.elapsed,
        'warning' => 2.45 - u.elapsed,
        'falling' => .65 - u.elapsed,
        _ => 0.0,
      };
      label(
        canvas,
        p + const Offset(0, -110),
        u.phase == 'finding'
            ? 'FINDING DROP ZONE'
            : 'SENTRY INCOMING ${until.ceil()}',
      );
    }
  }

  static void body(
    Canvas canvas,
    SupportUnit u,
    SupportConfig c, {
    ColorFilter? ambient,
    bool reducedMotion = false,
  }) {
    if (u.card.family == SupportFamily.aura) {
      // A small physical emitter accompanies the field without covering the body.
      final p = u.position + const Offset(20, -10);
      sprite(canvas, 'support/emitter', p, 18, alpha: .8, ambient: ambient);
      final phase = reducedMotion ? 0 : (u.life * 10).floor();
      for (var i = 0; i < 3; i++) {
        final tip = p + AuraEnergy.point(i * math.pi * 2 / 3, 6);
        canvas.drawRect(
          Rect.fromCenter(center: tip, width: 2, height: 2),
          Paint()
            ..color = Color.fromRGBO(
              211,
              220,
              175,
              reducedMotion || (phase + i) % 3 != 0 ? .6 : .95,
            ),
        );
      }
      return;
    }
    if (['following', 'finding', 'warning'].contains(u.phase)) return;
    final falling = u.phase == 'falling';
    final q = (u.elapsed / .65).clamp(0.0, 1.0);
    final descent = falling && !reducedMotion ? 220 * (1 - q * q) : 0.0;
    final deploying = u.phase == 'deploying';
    final unfold = deploying ? (u.elapsed / .55).clamp(0.0, 1.0) : 1.0;
    final breaking = u.phase == 'breaking';
    final fade = breaking
        ? (1 - u.elapsed / 1.3).clamp(0.0, 1.0)
        : falling && reducedMotion
        ? q
        : 1.0;
    canvas.save();
    canvas.translate(u.position.dx, u.position.dy - descent);
    final deployEase = 1 - math.pow(1 - unfold, 3).toDouble();
    final collapse = breaking && !reducedMotion
        ? (u.elapsed / 1.3).clamp(0.0, 1.0)
        : 0.0;
    if ((deploying || breaking) && !reducedMotion) {
      // Separate authored leg panels fold from the receiver and collapse outwards.
      for (final side in [-1.0, 1.0]) {
        for (final rear in [true, false]) {
          canvas.save();
          canvas.translate(
            side * (-12 * (1 - deployEase) + collapse * 14),
            8 * (1 - deployEase) + collapse * collapse * 16,
          );
          canvas.clipRect(
            Rect.fromLTRB(
              side < 0 ? -52 : 18,
              rear ? -64 : -30,
              side < 0 ? -18 : 52,
              rear ? -30 : 2,
            ),
          );
          sprite(
            canvas,
            'support/base',
            Offset.zero,
            100,
            alpha: fade,
            ambient: ambient,
            anchor: Anchor.bottomCenter,
          );
          canvas.restore();
        }
      }
      canvas.save();
      canvas.clipRect(const Rect.fromLTRB(-18, -64, 18, 2));
      sprite(
        canvas,
        'support/base',
        Offset.zero,
        100,
        alpha: fade,
        ambient: ambient,
        anchor: Anchor.bottomCenter,
      );
      canvas.restore();
    } else {
      sprite(
        canvas,
        'support/base',
        Offset.zero,
        100,
        alpha: fade,
        ambient: ambient,
        anchor: Anchor.bottomCenter,
      );
    }
    canvas.save();
    canvas.translate(
      0,
      -42 - (deploying && !reducedMotion ? 8 * deployEase - 8 : 0),
    );
    canvas.rotate(u.heading);
    final width = u.card.mount == 'carbine' ? 75.0 : 87.5;
    final pivot = u.card.mount == 'carbine' ? .25 : .36;
    final s = RegunArt.shared.contains('support/${u.card.mount}')
        ? RegunArt.shared.rawSprite('support/${u.card.mount}', 0)
        : null;
    if (s != null) {
      final h = width * s.srcSize.y / s.srcSize.x;
      final recoil = reducedMotion ? 0.0 : u.recoil / .1 * 3;
      sprite(
        canvas,
        'support/${u.card.mount}',
        Offset(
          width * (.5 - pivot) - recoil,
          h * (.5 - (u.card.mount == 'carbine' ? .64 : .5)),
        ),
        width,
        alpha: fade,
        ambient: ambient,
      );
      if (u.recoil > .055) {
        canvas.drawRect(
          const Rect.fromLTWH(56, -2, 8, 4),
          Paint()
            ..isAntiAlias = false
            ..color = const Color(0xffE3C08A),
        );
      }
      if (u.reload > 0 && !reducedMotion) {
        canvas.drawRect(
          Rect.fromLTWH(-12, h / 2 + 2, 8, 4),
          Paint()..color = const Color(0xff9F8C65),
        );
      }
    }
    canvas.restore();
    if (u.phase == 'active' && u.reload > 0) {
      label(canvas, const Offset(0, -112), 'RELOAD');
    }
    if (u.phase == 'active') {
      for (var i = 0; i < 3; i++) {
        canvas.drawRect(
          Rect.fromLTWH(-12 + i * 9, -18, 6, 3),
          Paint()
            ..color = u.life / c.sentryLife(u.card.tier) < (3 - i) / 3
                ? const Color(0xffD1B078)
                : const Color(0xff443F32),
        );
      }
    }
    canvas.restore();
  }

  static void label(Canvas canvas, Offset p, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 12,
          color: Color(0xffE0C799),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, p - Offset(painter.width / 2, 0));
  }

  static void trace(Canvas canvas, SupportTrace trace) {
    final delta = trace.to - trace.from;
    final direction = delta.distance > .001
        ? delta / delta.distance
        : trace.direction;
    final tail = math.min(30.0, math.max(5.0, delta.distance));
    roundAt(
      canvas,
      trace.to,
      direction,
      length: tail,
      alpha: (1 - trace.age / SupportTrace.duration).clamp(0.0, 1.0),
    );
  }

  static void round(Canvas canvas, SupportRound r) =>
      roundAt(canvas, r.position, r.direction);

  static void roundAt(
    Canvas canvas,
    Offset position,
    Offset direction, {
    double length = 22,
    double alpha = 1,
  }) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(math.atan2(direction.dy, direction.dx));
    canvas.drawRect(
      Rect.fromLTWH(-length - 2, -3.5, length + 4, 7),
      Paint()
        ..isAntiAlias = false
        ..color = Color.fromRGBO(48, 40, 27, alpha * .8),
    );
    canvas.drawRect(
      Rect.fromLTWH(-length, -2.5, length, 5),
      Paint()
        ..isAntiAlias = false
        ..color = Color.fromRGBO(200, 156, 86, alpha),
    );
    canvas.drawRect(
      Rect.fromLTWH(-length * .62, -1, length * .62 + 2, 2),
      Paint()
        ..isAntiAlias = false
        ..color = Color.fromRGBO(249, 225, 172, alpha),
    );
    canvas.restore();
  }
}
