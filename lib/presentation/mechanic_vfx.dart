import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/presentation/attack_vfx.dart';

/// Read-only material accents. Inputs are committed mechanic state, not ranks
/// alone, random rolls or timers invented by the renderer.
class MechanicVfx {
  static void frost(
    Canvas canvas,
    Rect body, {
    required bool frozen,
    required double recovery,
    required bool reducedMotion,
  }) {
    if (!frozen && recovery <= 0) return;
    final fade = frozen ? 1.0 : (recovery / .2).clamp(0.0, 1.0);
    // Small body-clinging crusts leave the head, weapon and central pose clear.
    for (final p in [(-.38, .49, 1.0), (.34, .63, .85), (-.17, .91, 1.1)]) {
      final c = Offset(
        body.center.dx + body.width * p.$1,
        body.top + body.height * p.$2,
      );
      final w = (body.width * .24).clamp(7.0, 27.0) * p.$3;
      final h = (body.height * .25).clamp(10.0, 35.0) * p.$3;
      final crust = Path()
        ..moveTo(c.dx - w * .5, c.dy)
        ..lineTo(c.dx - w * .6, c.dy - h * .5)
        ..lineTo(c.dx - w * .25, c.dy - h * .4)
        ..lineTo(c.dx - w * .08, c.dy - h)
        ..lineTo(c.dx + w * .15, c.dy - h * .65)
        ..lineTo(c.dx + w * .45, c.dy - h * .8)
        ..lineTo(c.dx + w * .5, c.dy - h * .2)
        ..lineTo(c.dx + w * .25, c.dy)
        ..close();
      canvas.drawPath(
        crust,
        Paint()..color = Color.fromRGBO(56, 80, 83, fade * .88),
      );
      canvas.drawPath(
        crust,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Color.fromRGBO(170, 209, 210, fade * .9),
      );
      AttackVfx.stroke(
        canvas,
        [
          c + Offset(-w * .2, -h * .1),
          c + Offset(w * .1, -h * .45),
          c + Offset(-w * .1, -h * .72),
        ],
        Color.fromRGBO(222, 235, 220, fade * .85),
        2,
      );
      if (!frozen && !reducedMotion) {
        final thaw = 1 - fade;
        AttackVfx.chip(
          canvas,
          c + Offset(w * .5 + thaw * 8, thaw * 10),
          3,
          Color.fromRGBO(164, 200, 202, fade * .7),
        );
      }
    }
  }

  static void mark(Canvas canvas, Rect body) {
    final r = body.inflate(8);
    const ink = Color(0xffcdb57c), shadow = Color(0xff252b24);
    // Four worn metal corners frame the real target; no filled reticle over it.
    for (final x in [-1, 1]) {
      for (final y in [-1, 1]) {
        final c = Offset(x < 0 ? r.left : r.right, y < 0 ? r.top : r.bottom);
        final points = [c + Offset(-x * 9, 0), c, c + Offset(0, -y * 8)];
        AttackVfx.stroke(canvas, points, shadow, 6);
        AttackVfx.stroke(canvas, points, ink, 2.5);
      }
    }
    final top = Offset(body.center.dx, r.top - 4);
    AttackVfx.stroke(
      canvas,
      [
        top + const Offset(-5, 0),
        top + const Offset(0, -5),
        top + const Offset(5, 0),
        top + const Offset(0, 5),
        top + const Offset(-5, 0),
      ],
      shadow,
      6,
    );
    AttackVfx.stroke(
      canvas,
      [
        top + const Offset(-5, 0),
        top + const Offset(0, -5),
        top + const Offset(5, 0),
        top + const Offset(0, 5),
        top + const Offset(-5, 0),
      ],
      ink,
      2.5,
    );
  }

  static void discharge(
    Canvas canvas,
    Offset end,
    Offset direction,
    double fade, {
    bool perk = false,
    bool reducedMotion = false,
  }) {
    final length = direction.distance;
    final d = length > .001 ? direction / length : const Offset(1, 0);
    final n = Offset(-d.dy, d.dx);
    final reach = reducedMotion ? 11.0 : 11 + (1 - fade) * 8;
    for (final sign in [-1, 1]) {
      final points = [
        end - d * 6,
        end + n * (sign * reach * .5) - d * 3,
        end + n * (sign * reach) + d * 4,
      ];
      AttackVfx.stroke(
        canvas,
        points,
        const Color(0xff1e2a29).withValues(alpha: fade),
        6,
      );
      AttackVfx.stroke(
        canvas,
        points,
        (perk ? const Color(0xffd8ce98) : const Color(0xffb9d9d5)).withValues(
          alpha: fade,
        ),
        2.5,
      );
    }
  }

  /// A short accepted-contact accent, bounded per victim. It adds neither force
  /// nor damage. Precision is pale, penetration/ricochet use weathered brass.
  static void contact(
    Canvas canvas,
    Rect body,
    int flags,
    double age, {
    required bool reducedMotion,
  }) {
    if (flags == 0 || age < 0 || age >= .18) return;
    final fade = 1 - age / .18;
    final r = (body.width * .3).clamp(8.0, 24.0);
    final c = body.center;
    final color = (flags & 4) != 0
        ? const Color(0xffb4d2d4)
        : const Color(0xffd8b77e);
    for (final side in [-1, 1]) {
      final drift = reducedMotion ? 0.0 : age * 35;
      final at = c + Offset(side * (r + drift), r * .3 + drift * .4);
      AttackVfx.stroke(
        canvas,
        [at + Offset(-side * 5, -4), at, at + Offset(-side * 2, 4)],
        const Color(0xff242b26).withValues(alpha: fade),
        6,
      );
      AttackVfx.stroke(
        canvas,
        [at + Offset(-side * 5, -4), at, at + Offset(-side * 2, 4)],
        color.withValues(alpha: fade),
        2.5,
      );
    }
  }

  /// Bit 1 final round, 2 post-reload, 4 measured shot. All share one compact
  /// weapon-local mechanism instead of stacking three surrounding player auras.
  static void weapon(
    Canvas canvas, {
    required int ready,
    int spent = 0,
    double spentAge = 1,
    required bool reducedMotion,
    double muzzle = 36,
  }) {
    const colors = [Color(0xffdfbd78), Color(0xffd9a27e), Color(0xffb6d0ca)];
    for (var i = 0; i < 3; i++) {
      if ((ready & (1 << i)) == 0) continue;
      final y = -12.0 - i * 4;
      canvas.drawRect(
        Rect.fromLTWH(4, y - 1, 15, 5),
        Paint()..color = const Color(0xff25302b),
      );
      canvas.drawRect(Rect.fromLTWH(6, y, 11, 2), Paint()..color = colors[i]);
    }
    if (spent == 0 || spentAge < 0 || spentAge >= .24) return;
    final fade = 1 - spentAge / .24;
    final color =
        colors[(spent & 4) != 0
                ? 2
                : (spent & 2) != 0
                ? 1
                : 0]
            .withValues(alpha: fade);
    final extent = reducedMotion ? 8.0 : 8 + spentAge * 45;
    AttackVfx.stroke(
      canvas,
      [
        Offset(muzzle, -extent),
        Offset(muzzle + 5, -4),
        Offset(muzzle + 8, 0),
        Offset(muzzle + 5, 4),
        Offset(muzzle, extent),
      ],
      color,
      3,
    );
  }

  static void healing(
    Canvas canvas,
    Rect body,
    double age, {
    required bool reducedMotion,
  }) {
    if (age < 0 || age >= .7) return;
    final fade = (1 - age / .7).clamp(0.0, 1.0);
    final c = Offset(
      body.center.dx,
      body.top - 10 - (reducedMotion ? 0 : age * 12),
    );
    final p = Paint()..color = Color.fromRGBO(184, 210, 164, fade);
    canvas.drawRect(
      Rect.fromCenter(center: c, width: 17, height: 7),
      Paint()..color = Color.fromRGBO(31, 48, 37, fade),
    );
    canvas.drawRect(
      Rect.fromCenter(center: c, width: 7, height: 17),
      Paint()..color = Color.fromRGBO(31, 48, 37, fade),
    );
    canvas.drawRect(Rect.fromCenter(center: c, width: 13, height: 3), p);
    canvas.drawRect(Rect.fromCenter(center: c, width: 3, height: 13), p);
    for (final side in [-1, 1]) {
      final t = reducedMotion ? .5 : (age / .7).clamp(0.0, 1.0);
      final at = Offset(
        body.center.dx + side * body.width * (.36 - t * .18),
        body.center.dy + body.height * (.3 - t * .6),
      );
      AttackVfx.stroke(
        canvas,
        [at + const Offset(0, 6), at, at + Offset(side * 3, -4)],
        Color.fromRGBO(151, 185, 138, fade * .8),
        2,
      );
    }
  }
}

/// Ephemeral accepted-event readout; resets establish a watermark and never
/// celebrate historical healing or an old shot on Continue/reconnect.
class MechanicFeedback {
  int? _generation;
  int _recovered = 0, _shots = -1;
  double healAge = -1, spentAge = 1;
  int spent = 0;
  void sync(int generation, int recovered, double dt) {
    if (_generation != generation) {
      _generation = generation;
      _recovered = recovered;
      _shots = -1;
      healAge = -1;
      spentAge = 1;
      spent = 0;
      return;
    }
    if (healAge >= 0) healAge = math.min(1, healAge + dt);
    spentAge = math.min(1, spentAge + dt);
    if (recovered > _recovered) healAge = 0;
    _recovered = recovered;
  }

  void settle(int recovered) {
    _recovered = recovered;
    healAge = -1;
    spentAge = 1;
    spent = 0;
  }

  void release(int flags) {
    if (flags == 0) return;
    spent = spentAge == 0 ? spent | flags : flags;
    spentAge = 0;
  }

  void onlineShots(int shots, {int? acceptedPerks}) {
    if (shots > _shots && _shots >= 0) release((acceptedPerks ?? 0) & 3);
    _shots = shots;
  }
}
