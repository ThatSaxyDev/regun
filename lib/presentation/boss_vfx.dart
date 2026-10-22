import 'dart:math' as math;
import 'dart:ui';

import 'package:regun/data/enemies.dart';
import 'package:regun/presentation/attack_vfx.dart';

/// Chipped, arena-grounded geometry for boss attacks. No scaled texture stamps,
/// blur layers or per-frame randomness: warning footprints remain committed.
class BossVfx {
  const BossVfx({this.kind, this.reducedMotion = false, this.ambient});
  final BossKind? kind;
  final bool reducedMotion;
  final ColorFilter? ambient;
  static const _soil = Color(0xff1A1D1A);
  static const _cut = Color(0xff101511);
  static double _noise(int n) => ((n * 73 + 29) % 101) / 100;
  static Offset _polar(double a, double r) =>
      Offset(math.cos(a), math.sin(a)) * r;
  static Offset _snap(Offset p) =>
      Offset((p.dx / 3).round() * 3, (p.dy / 3).round() * 3);
  Color _edge(AttackMaterial m) => switch (kind) {
    BossKind.bellkeeper => const Color(0xffB49B6D),
    BossKind.marshal => const Color(0xffB1AA8B),
    _ => switch (m) {
      AttackMaterial.glass => const Color(0xffA4B5AD),
      AttackMaterial.chain => const Color(0xff9F9480),
      AttackMaterial.ember => const Color(0xffC68B57),
      AttackMaterial.poison => const Color(0xff929A60),
      AttackMaterial.shadow => const Color(0xff9E7F8B),
      _ => const Color(0xffB0A18A),
    },
  };
  Paint _paint(Color color, double alpha, {bool grade = false}) => Paint()
    ..color = color.withValues(alpha: alpha.clamp(0, 1))
    ..isAntiAlias = false
    ..colorFilter = grade ? ambient : null;
  Path _polygon(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  void _line(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width,
    double alpha,
  ) {
    if (points.length < 2) return;
    final path = Path()..moveTo(_snap(points.first).dx, _snap(points.first).dy);
    for (final p in points.skip(1)) {
      final q = _snap(p);
      path.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(
      path,
      _paint(color, alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.miter
        ..strokeCap = StrokeCap.square,
    );
  }

  static double _fade(bool warning, double p) =>
      warning ? .62 + p.clamp(0, 1) * .28 : 1 - .22 * p.clamp(0, 1);
  void _grain(Canvas canvas, Rect bounds, Color color, double alpha, int seed) {
    // A fixed set of chips is clipped to the real damage area; no expanding dirt halo.
    final clip = canvas.getLocalClipBounds();
    for (var i = 0; i < 44; i++) {
      final p = _snap(
        Offset(
          bounds.left + bounds.width * _noise(i * 7 + seed),
          bounds.top + bounds.height * _noise(i * 13 + seed + 4),
        ),
      );
      if (!clip.contains(p)) continue;
      canvas.drawRect(
        Rect.fromLTWH(p.dx, p.dy, 2 + i % 3, 2 + (i + 1) % 2),
        _paint(color, alpha * (.3 + _noise(i) * .5), grade: true),
      );
    }
  }

  void disk(
    Canvas canvas,
    Offset center,
    double radius, {
    required bool warning,
    required double progress,
    AttackMaterial material = AttackMaterial.stone,
    ColorFilter? ambient,
  }) {
    if (radius <= 0 ||
        !canvas.getLocalClipBounds().overlaps(
          Rect.fromCircle(center: center, radius: radius + 8),
        )) {
      return;
    }
    final fade = _fade(warning, progress), edge = _edge(material);
    final area = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.save();
    canvas.clipPath(area, doAntiAlias: false);
    canvas.drawPath(area, _paint(_soil, warning ? .25 : .50 * fade));
    _fractures(
      canvas,
      Rect.fromCircle(center: center, radius: radius),
      edge,
      fade * (warning ? .48 : .8),
      material.index * 13,
      glass: material == AttackMaterial.glass,
    );
    wave(
      canvas,
      center,
      radius - 5,
      0,
      math.pi * 2,
      warning: warning,
      progress: progress,
      material: material,
      width: warning ? 7 : 12,
    );
    _grain(
      canvas,
      Rect.fromCircle(center: center, radius: radius),
      edge,
      warning ? .13 : .32 * fade,
      material.index * 9,
    );
    if (material == AttackMaterial.poison && !warning) {
      for (var i = 0; i < 7; i++) {
        final p = center + _polar(i * 2.4, radius * (.17 + _noise(i) * .55));
        final size = radius * (.08 + _noise(i + 4) * .1);
        canvas.drawPath(
          _polygon([
            p + Offset(-size, 0),
            p + Offset(0, -size * .5),
            p + Offset(size, 0),
            p + Offset(size * .4, size * .45),
            p + Offset(-size * .7, size * .3),
          ]),
          _paint(edge, .13 * fade, grade: true),
        );
      }
    }
    canvas.restore();
  }

  void ribbon(
    Canvas canvas,
    Offset start,
    Offset end,
    double width, {
    required bool warning,
    required double progress,
    AttackMaterial material = AttackMaterial.stone,
    bool spent = false,
  }) {
    final delta = end - start, length = delta.distance;
    if (length < 1 || width <= 0) return;
    if (!canvas.getLocalClipBounds().overlaps(
      Rect.fromPoints(start, end).inflate(width + 10),
    )) {
      return;
    }
    final fade = _fade(warning, progress) * (spent ? .2 : 1),
        edge = _edge(material);
    canvas.save();
    canvas.translate(start.dx, start.dy);
    canvas.rotate(math.atan2(delta.dy, delta.dx));
    canvas.clipRect(
      Rect.fromLTWH(0, -width, length, width * 2),
      doAntiAlias: false,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, -width, length, width * 2),
      _paint(_soil, warning ? .27 : .6 * fade),
    );
    if (material == AttackMaterial.chain && !warning) {
      final count = (length / 24).ceil().clamp(1, 48), step = length / count;
      for (var i = 0; i < count; i++) {
        final x = (i + .5) * step,
            half = math.min(width * .7, 14.0),
            dx = step * .62;
        final outer = _polygon([
          Offset(x - dx, 0),
          Offset(x - dx * .6, -half),
          Offset(x + dx * .6, -half),
          Offset(x + dx, 0),
          Offset(x + dx * .6, half),
          Offset(x - dx * .6, half),
        ]);
        final inner = _polygon([
          Offset(x - dx * .6, 0),
          Offset(x - dx * .35, -half * .45),
          Offset(x + dx * .35, -half * .45),
          Offset(x + dx * .6, 0),
          Offset(x + dx * .35, half * .45),
          Offset(x - dx * .35, half * .45),
        ]);
        outer.addPath(inner, Offset.zero);
        outer.fillType = PathFillType.evenOdd;
        canvas.drawPath(outer, _paint(edge, .7 * fade, grade: true));
        _line(
          canvas,
          [Offset(x - dx * .5, -half + 3), Offset(x + dx * .4, -half + 3)],
          edge,
          3,
          .85 * fade,
        );
      }
    } else {
      final count = (length / 38).ceil().clamp(1, 48), step = length / count;
      for (var i = 0; i < count; i++) {
        final x = i * step,
            y = (_noise(i + material.index * 3) - .5) * width * .5;
        if (warning) {
          for (final side in [-1, 1]) {
            final a = Offset(x + 3, side * (width - 3)),
                b = Offset(x + step * .7, side * (width - 3));
            _line(canvas, [a, b], _cut, 7, fade);
            _line(canvas, [a, b], edge, 3, fade * .75);
          }
        } else {
          final shard = _polygon([
            Offset(x, y),
            Offset(x + step * .45, -width),
            Offset(x + step, y - 3),
            Offset(x + step * .6, width),
          ]);
          canvas.drawPath(shard, _paint(edge, .17 * fade, grade: true));
          _line(
            canvas,
            [
              Offset(x, y),
              Offset(x + step * .45, y - width * .25),
              Offset(x + step, y + 2),
            ],
            _cut,
            math.min(9, width * .5),
            .8 * fade,
          );
          _line(
            canvas,
            [Offset(x, y - 3), Offset(x + step * .45, y - width * .25 - 3)],
            edge,
            3,
            fade * .7,
          );
        }
      }
    }
    canvas.restore();
    if (material == AttackMaterial.chain && !warning) {
      anchor(canvas, end, math.atan2(delta.dy, delta.dx), .65, alpha: fade);
    }
  }

  void wave(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    double arc, {
    required bool warning,
    required double progress,
    AttackMaterial material = AttackMaterial.stone,
    double width = 18,
  }) {
    if (radius <= 0 || arc.abs() < .001) return;
    final edge = _edge(material), fade = _fade(warning, progress);
    final count = (radius * arc.abs() / 32).ceil().clamp(3, 96);
    final clip = canvas.getLocalClipBounds().inflate(width + 10);
    for (var i = 0; i < count; i++) {
      final a = angle + arc * i / count, b = angle + arc * (i + 1) / count;
      final middle = center + _polar((a + b) * .5, radius);
      final outer = radius + width, inner = math.max(0.0, radius - width);
      final points = [
        center + _polar(a, inner),
        center + _polar(a, outer),
        center + _polar(b, outer),
        center + _polar(b, inner),
      ];
      final segmentBounds = Rect.fromLTRB(
        points.map((p) => p.dx).reduce(math.min),
        points.map((p) => p.dy).reduce(math.min),
        points.map((p) => p.dx).reduce(math.max),
        points.map((p) => p.dy).reduce(math.max),
      );
      if (!clip.overlaps(segmentBounds)) continue;
      canvas.drawPath(
        _polygon(points),
        _paint(_soil, warning ? .35 : .65 * fade),
      );
      if (!warning) {
        canvas.drawPath(
          _polygon([points[0], middle, points[2], points[3]]),
          _paint(edge, .22 * fade, grade: true),
        );
      }
      final r = radius + (i.isEven ? width * .25 : -width * .2);
      final span = b - a;
      final p1 = center + _polar(a + span * .06, r - width * .15),
          kink =
              center +
              _polar(a + span * (.35 + _noise(i) * .25), r + width * .4),
          p2 =
              center +
              _polar(b - span * (.08 + _noise(i + 3) * .12), r - width * .3);
      final scar = [p1, kink, p2];
      _line(canvas, scar, _cut, warning ? 10 : 14, .9 * fade);
      _line(canvas, scar, edge, warning ? 4 : 6, fade * .85);
      if (i % 3 != 1) {
        _line(
          canvas,
          [kink, center + _polar(a + span * .7, radius - width * 1.2)],
          _cut,
          5,
          fade * .65,
        );
      }
    }
  }

  void fan(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    double arc, {
    required bool warning,
    required double progress,
    AttackMaterial material = AttackMaterial.stone,
    double innerRadius = 0,
  }) {
    if (radius <= innerRadius || arc.abs() < .001) return;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    if (!canvas.getLocalClipBounds().overlaps(bounds)) return;
    var sector = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(bounds, angle, arc, false)
      ..close();
    if (innerRadius > 0) {
      sector = Path.combine(
        PathOperation.difference,
        sector,
        Path()..addOval(Rect.fromCircle(center: center, radius: innerRadius)),
      );
    }
    final fade = _fade(warning, progress), edge = _edge(material);
    canvas.save();
    canvas.clipPath(sector, doAntiAlias: false);
    canvas.drawRect(bounds, _paint(_soil, warning ? .27 : .56 * fade));
    _fractures(
      canvas,
      bounds,
      edge,
      fade * (warning ? .5 : .85),
      material.index * 17 + 3,
      glass: material == AttackMaterial.glass,
    );
    if (!warning) {
      for (var band = 1; band <= 3; band++) {
        final r = innerRadius + (radius - innerRadius) * band / 4;
        wave(
          canvas,
          center,
          r,
          angle,
          arc,
          warning: false,
          progress: progress,
          material: material,
          width: 7,
        );
      }
    }
    _grain(canvas, bounds, edge, warning ? .3 : .4 * fade, 13);
    canvas.restore();
    wave(
      canvas,
      center,
      radius,
      angle,
      arc,
      warning: warning,
      progress: progress,
      material: material,
      width: 5,
    );
    if (innerRadius > 0) {
      wave(
        canvas,
        center,
        innerRadius,
        angle,
        arc,
        warning: warning,
        progress: progress,
        material: material,
        width: 3,
      );
    }
    for (final a in [angle, angle + arc]) {
      final direction = _polar(a, 1), normal = _polar(a + math.pi / 2, 1);
      final count = ((radius - innerRadius) / 38).ceil().clamp(1, 24);
      for (var i = 0; i < count; i++) {
        final r = innerRadius + (radius - innerRadius) * i / count;
        final points = [
          center + direction * (r + 3),
          center + direction * (r + 14) + normal * (_noise(i) * 8 - 4),
          center + direction * (r + 27),
        ];
        _line(canvas, points, _cut, 8, fade * .85);
        _line(canvas, points, edge, 3, fade * .8);
      }
    }
  }

  // Fixed, locally broken scars: no radial spokes or repeating texture stamps.
  void _fractures(
    Canvas canvas,
    Rect bounds,
    Color edge,
    double alpha,
    int seed, {
    bool glass = false,
  }) {
    for (var i = 0; i < 38; i++) {
      final p = Offset(
        bounds.left + bounds.width * _noise(seed + i * 7),
        bounds.top + bounds.height * _noise(seed + i * 19 + 5),
      );
      final a = _noise(seed + i * 11) * math.pi * 2;
      final direction = _polar(a, 1), side = _polar(a + 1.57, 1);
      final length = 14 + _noise(i + seed) * (glass ? 38 : 25);
      final points = [
        p - direction * length * .45,
        p + side * (3 + _noise(i) * 7),
        p + direction * length * .55,
      ];
      canvas.drawPath(
        _polygon([
          points[0],
          points[1] + side * 8,
          points[2],
          points[1] - side * 6,
        ]),
        _paint(edge, alpha * .24, grade: true),
      );
      _line(canvas, points, _cut, 7, alpha);
      _line(
        canvas,
        [points[0] + side * 3, points[1] + side * 3, points[2]],
        edge,
        3,
        alpha * .65,
      );
      if (glass && i % 3 == 0) {
        canvas.drawPath(
          _polygon([p, p - direction * 8 + side * 6, p + side * 35]),
          _paint(edge, alpha * .38, grade: true),
        );
      }
    }
  }

  void anchor(
    Canvas canvas,
    Offset point,
    double angle,
    double scale, {
    double alpha = 1,
  }) {
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate(angle);
    final edge = _edge(AttackMaterial.chain);
    final path = _polygon(
      [
        const Offset(-15, -13),
        const Offset(9, -13),
        const Offset(22, 0),
        const Offset(9, 13),
        const Offset(-15, 13),
        const Offset(-7, 0),
      ].map((p) => p * scale).toList(),
    );
    canvas.drawPath(path.shift(const Offset(3, 4)), _paint(_cut, .8 * alpha));
    canvas.drawPath(path, _paint(edge, .6 * alpha, grade: true));
    _line(
      canvas,
      [
        const Offset(-10, -8) * scale,
        const Offset(7, -8) * scale,
        const Offset(15, 0) * scale,
      ],
      edge,
      3,
      alpha,
    );
    canvas.restore();
  }

  void shard(
    Canvas canvas,
    Offset foot,
    double size,
    Color color, {
    double lean = 0,
  }) {
    final edge = _edge(AttackMaterial.glass);
    final points = [
      foot + Offset(-size * .35, 0),
      foot + Offset(-size * .2, -size * .72),
      foot + Offset(size * .1, -size),
      foot + Offset(size * .35, -size * .48),
      foot + Offset(size * .2, 0),
    ];
    canvas.drawPath(
      _polygon(points).shift(const Offset(3, 3)),
      _paint(_cut, .8),
    );
    canvas.drawPath(_polygon(points), _paint(edge, .3, grade: true));
    _line(canvas, [points[0], points[2], points[3]], edge, 3, .85);
    _line(
      canvas,
      [points[1], foot + Offset(size * .12, -size * .3), points[4]],
      _cut,
      3,
      .7,
    );
  }

  void armour(
    Canvas canvas,
    Offset center,
    double radius, {
    double facing = 0,
    bool full = true,
  }) {
    wave(
      canvas,
      center,
      radius,
      facing - (full ? math.pi : .9),
      full ? math.pi * 2 : 1.8,
      warning: false,
      progress: .35,
      material: AttackMaterial.chain,
      width: 9,
    );
  }

  void chip(Canvas canvas, Offset p, double size, Color color) =>
      canvas.drawRect(
        Rect.fromCenter(center: _snap(p), width: size, height: size),
        _paint(color, .8),
      );
  void laser(
    Canvas canvas,
    Offset start,
    Offset end,
    double width, {
    required bool warning,
    required double progress,
    bool reducedMotion = false,
  }) => AttackVfx.laser(
    canvas,
    start,
    end,
    width,
    warning: warning,
    progress: progress,
    reducedMotion: reducedMotion,
  );
}
