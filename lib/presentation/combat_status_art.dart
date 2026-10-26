import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:regun/presentation/regun_art.dart';

/// One small shared status packet per game/online surface. Pending loads retire
/// safely; no dependence on an equipped flamethrower or gameplay-effect capacity.
class CombatStatusArt {
  CombatStatusArt({RegunArt? art}) : _art = art ?? RegunArt.shared;
  final RegunArt _art;
  static const flame = 'effects/status_flame';
  int _epoch = 0;
  bool _held = false, _pending = false, _wanted = false, _failed = false;
  void prewarmFire({bool retry = false}) {
    _wanted = true;
    if (retry) _failed = false;
    if (_held || _pending || _failed) return;
    final epoch = _epoch;
    _pending = true;
    unawaited(
      _art
          .acquire(flame)
          .then((_) {
            _pending = false;
            if (!_wanted || epoch != _epoch) {
              _art.release(flame);
              if (_wanted) prewarmFire();
            } else {
              _held = true;
            }
          })
          .catchError((Object _) {
            _pending = false;
            if (epoch == _epoch) _failed = true;
          }),
    );
  }

  void clear() {
    _wanted = false;
    _failed = false;
    _epoch++;
    if (_held) _art.release(flame);
    _held = false;
  }
}

/// Shared body-bound status rendering, independent from gameplay RNG/timers.
class CombatStatusPainter {
  // Small, staggered changes in flame luminance; the body and arena never flash.
  // Cached paints avoid allocating filters for every affected actor each frame.
  static final _flamePaints = List<Paint>.generate(8, (level) {
    final heat = level / 7;
    final gain = 1.12 + heat * .24;
    return Paint()
      ..filterQuality = FilterQuality.none
      ..color = Color.fromRGBO(255, 255, 255, .93 + heat * .07)
      ..colorFilter = ColorFilter.matrix([
        gain,
        0,
        0,
        0,
        10,
        0,
        gain,
        0,
        0,
        6,
        0,
        0,
        gain,
        0,
        1,
        0,
        0,
        0,
        1,
        0,
      ]);
  });

  static const burnTint = ColorFilter.matrix([
    .94,
    0,
    0,
    0,
    15,
    0,
    .78,
    0,
    0,
    5,
    0,
    0,
    .66,
    0,
    2,
    0,
    0,
    0,
    1,
    0,
  ]);

  static void fire(
    Canvas canvas,
    Rect body,
    double clock, {
    required bool reducedMotion,
    required bool front,
    int seed = 0,
  }) {
    if (!canvas.getLocalClipBounds().inflate(40).overlaps(body)) return;
    // Fire catches on the victim, never two floor fires flanking its body.
    if (!front) return;
    final art = RegunArt.shared;
    final width = body.width.clamp(24.0, 145.0);
    final foot = Offset(body.center.dx, body.bottom);
    const patches = [
      (x: -.24, y: .68, height: .34, width: .25),
      (x: .14, y: .58, height: .27, width: .20),
      (x: .23, y: .90, height: .32, width: .23),
    ];
    for (var i = 0; i < patches.length; i++) {
      final p = patches[i];
      final heat = reducedMotion
          ? .5
          : .5 +
                .5 *
                    math.sin(clock * math.pi * 2 * 1.65 + seed * .77 + i * 2.1);
      final flamePaint = _flamePaints[(heat * 7).round().clamp(0, 7)];
      final height = math.min(body.height * p.height, 45.0);
      final w = width * p.width;
      final frame = reducedMotion
          ? (i * 3 + seed) % 8
          : ((clock * 11).floor() + seed * 3 + i * 3) % 8;
      final origin = Offset(
        body.center.dx + p.x * width,
        body.top + p.y * body.height,
      );
      if (art.contains(CombatStatusArt.flame)) {
        art
            .rawSprite(CombatStatusArt.flame, frame)
            .render(
              canvas,
              position: Vector2(origin.dx, origin.dy),
              size: Vector2(w, height),
              anchor: Anchor.bottomCenter,
              overridePaint: flamePaint,
            );
      } else {
        final lick = Path()
          ..moveTo(origin.dx - w * .25, origin.dy)
          ..lineTo(origin.dx - w * .15, origin.dy - height * .45)
          ..lineTo(origin.dx + w * .2, origin.dy - height)
          ..lineTo(origin.dx + w * .12, origin.dy - height * .4)
          ..lineTo(origin.dx + w * .25, origin.dy)
          ..close();
        canvas.drawPath(
          lick,
          Paint()..color = Color.fromRGBO(218, 144, 67, .85 + heat * .12),
        );
      }
    }
    if (reducedMotion) return;
    // At most two deterministic motes per visible burning body.
    for (var i = 0; i < 2; i++) {
      final t = (clock * .65 + seed * .173 + i * .47) % 1;
      final x = foot.dx + (i == 0 ? -1 : 1) * width * .32;
      canvas.drawRect(
        Rect.fromLTWH(x, foot.dy - body.height * (.25 + t * .45), 2, 3),
        Paint()..color = Color.fromRGBO(232, 166, 88, (1 - t) * .6),
      );
    }
  }

  /// Faceted one-hit envelope. Rear shell and front joins retain body/gun clarity.
  static void ward(
    Canvas canvas,
    Rect body, {
    required bool ready,
    required bool front,
    required bool reducedMotion,
    double breakAge = -1,
    double reformAge = -1,
  }) {
    if (!ready && (breakAge < 0 || breakAge >= .36)) return;
    final breaking = !ready && breakAge >= 0;
    final t = breaking ? (breakAge / .36).clamp(0.0, 1.0) : 0.0;
    final alpha = breaking
        ? 1 - t
        : reformAge >= 0 && reformAge < .35
        ? .5 + .5 * reformAge / .35
        : 1.0;
    final c = body.center;
    final rx = body.width * .69 + 6, ry = body.height * .58 + 5;
    final points = <Offset>[
      Offset(-rx * .55, -ry),
      Offset(rx * .55, -ry),
      Offset(rx, -ry * .45),
      Offset(rx, ry * .46),
      Offset(rx * .5, ry),
      Offset(-rx * .5, ry),
      Offset(-rx, ry * .46),
      Offset(-rx, -ry * .45),
    ];
    for (var i = 0; i < 8; i++) {
      final isFront = i >= 2 && i <= 5;
      if (isFront != front) continue;
      final a = points[i], b = points[(i + 1) % 8];
      final mid = (a + b) / 2;
      final outward = breaking && !reducedMotion
          ? mid * (t * .28)
          : Offset.zero;
      final p0 = c + a + outward, p1 = c + b + outward;
      final inner0 = c + a * .88 + outward, inner1 = c + b * .88 + outward;
      final panel = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(inner1.dx, inner1.dy)
        ..lineTo(inner0.dx, inner0.dy)
        ..close();
      canvas.drawPath(
        panel,
        Paint()
          ..color = Color.fromRGBO(105, 139, 123, alpha * (front ? .24 : .35)),
      );
      // Three substantial stepped metal/energy segments with small dark seams.
      for (var segment = 0; segment < 3; segment++) {
        final from = Offset.lerp(p0, p1, segment / 3 + .025)!;
        final to = Offset.lerp(p0, p1, (segment + 1) / 3 - .025)!;
        final line = Path()
          ..moveTo(from.dx.roundToDouble(), from.dy.roundToDouble())
          ..lineTo(to.dx.roundToDouble(), to.dy.roundToDouble());
        canvas.drawPath(
          line,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = Color.fromRGBO(31, 47, 40, alpha * .95),
        );
        canvas.drawPath(
          line,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Color.fromRGBO(174, 198, 165, alpha * (front ? .9 : .72)),
        );
      }
      if (breaking && front) {
        final crack = Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(c.dx + mid.dx * .6, c.dy + mid.dy * .4)
          ..lineTo(c.dx + mid.dx * .36 + 5, c.dy + mid.dy * .55);
        canvas.drawPath(
          crack,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Color.fromRGBO(233, 216, 163, alpha * .8),
        );
      }
      canvas.drawRect(
        Rect.fromCenter(center: p0, width: 5, height: 5),
        Paint()..color = Color.fromRGBO(139, 131, 94, alpha * .95),
      );
    }
  }
}
