import 'package:regun/systems/grenades.dart';
import 'package:flame/components.dart' show Vector2, Anchor;
import 'package:flutter/material.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/utils/constants.dart';

void paintGrenade(
  Canvas canvas,
  Offset point,
  double edge, {
  double angle = 0,
}) {
  final art = RegunArt.shared;
  if (!art.contains('items/grenade')) return;
  canvas.save();
  canvas.translate(point.dx, point.dy);
  canvas.rotate(angle);
  final sprite = art.rawSprite('items/grenade', 0);
  final ratio = sprite.srcSize.x / sprite.srcSize.y;
  sprite.render(
    canvas,
    size: Vector2(edge * ratio, edge),
    anchor: Anchor.center,
    overridePaint: Paint()..filterQuality = FilterQuality.none,
  );
  canvas.restore();
}

/// Shared between native Flame and the online Flutter control surface.
class GrenadeButtonPainter extends CustomPainter {
  const GrenadeButtonPainter({
    required this.charges,
    this.capacity = 2,
    required this.progress,
    required this.remaining,
    this.aim,
    this.cancelled = false,
    this.pressed = false,
    this.opacity = 1,
  });
  final Offset? aim;
  final int charges, capacity;
  final double progress, remaining, opacity;
  final bool pressed, cancelled;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    canvas.scale(size.width / 112, size.height / 112);
    Color tone(int value) {
      final c = Color(value);
      return c;
    }

    final available = charges > 0;
    final ink = tone(available ? 0xffd9b878 : 0xff736e71);
    final face = Rect.fromLTWH(12, pressed ? 5 : 2, 88, 84);
    canvas.drawPath(
      controlPlate(face.shift(const Offset(0, 3))),
      Paint()..color = tone(0xb3100d13),
    );
    canvas.drawPath(
      controlPlate(face),
      Paint()..color = tone(pressed ? 0xe348392d : 0xc3252028),
    );
    canvas.drawPath(
      controlPlate(face.deflate(1)),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (available) {
      paintGrenade(
        canvas,
        Offset(56, pressed ? 45 : 42) + (aim ?? Offset.zero) * 13,
        43,
      );
    } else {
      canvas.saveLayer(
        const Rect.fromLTWH(32, 16, 48, 45),
        Paint()..color = const Color(0x70666666),
      );
      paintGrenade(canvas, const Offset(56, 35), 30);
      canvas.restore();
      _text(canvas, '${remaining.ceil()}s', 15, ink, 53);
    }
    for (var i = 0; i < capacity; i++) {
      final r = Rect.fromLTWH(56 - capacity * 10 + i * 20.0, 73, 16, 8);
      canvas.drawRect(r, Paint()..color = tone(0xff100d13));
      canvas.drawRect(
        r.deflate(1),
        Paint()..color = i < charges ? ink : tone(0xff443e42),
      );
      if (i == charges && charges < capacity) {
        canvas.drawRect(
          Rect.fromLTWH(r.left + 1, r.top + 1, 14 * progress, 6),
          Paint()..color = tone(0xff9e8970),
        );
      }
    }
    _text(
      canvas,
      cancelled
          ? 'CANCEL'
          : pressed && aim != null
          ? 'RELEASE'
          : 'THROW',
      pressed ? 12 : 16,
      ink,
      96,
    );
    canvas.restore();
  }

  void _text(Canvas c, String value, double size, Color color, double y) {
    final p = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: FontFam.pressStart,
          fontSize: size,
          height: 1,
          color: color,
        ),
      ),
    )..layout();
    p.paint(c, Offset((112 - p.width) / 2, y));
  }

  @override
  bool shouldRepaint(GrenadeButtonPainter old) =>
      old.capacity != capacity ||
      old.cancelled != cancelled ||
      old.aim != aim ||
      old.charges != charges ||
      old.progress != progress ||
      old.remaining.ceil() != remaining.ceil() ||
      old.pressed != pressed ||
      old.opacity != opacity;
}

/// Pointer capture remains with the ordnance control outside its touch bounds.
class GrenadeAimButton extends StatefulWidget {
  const GrenadeAimButton({
    super.key,
    required this.size,
    required this.charges,
    this.capacity = 2,
    required this.progress,
    required this.remaining,
    required this.opacity,
    required this.input,
    required this.onChanged,
    this.onThrow,
  });
  final double size, progress, remaining, opacity;
  final int charges, capacity;
  final GrenadeAim input;
  final VoidCallback onChanged;
  final void Function(Offset?, double)? onThrow;
  @override
  State<GrenadeAimButton> createState() => _GrenadeAimButtonState();
}

class _GrenadeAimButtonState extends State<GrenadeAimButton> {
  @override
  void didUpdateWidget(covariant GrenadeAimButton old) {
    super.didUpdateWidget(old);
    if (widget.onThrow == null) widget.input.cancel();
  }

  @override
  void dispose() {
    widget.input.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (e) {
      if (widget.onThrow != null && widget.charges > 0) {
        widget.input.begin(e.pointer, e.position);
        widget.onChanged();
      }
    },
    onPointerMove: (e) {
      widget.input.move(e.pointer, e.position);
      widget.onChanged();
    },
    onPointerUp: (e) {
      if (widget.input.pointer != e.pointer) return;
      if (!widget.input.cancelled) {
        widget.onThrow?.call(
          widget.input.direction,
          widget.input.power(widget.size * .85),
        );
      }
      widget.input.cancel();
      widget.onChanged();
    },
    onPointerCancel: (e) {
      if (widget.input.pointer == e.pointer) {
        widget.input.cancel();
        widget.onChanged();
      }
    },
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: GrenadeButtonPainter(
        charges: widget.charges,
        capacity: widget.capacity,
        progress: widget.progress,
        remaining: widget.remaining,
        opacity: widget.opacity,
        pressed: widget.input.active,
        cancelled: widget.input.cancelled,
        aim: widget.input.direction,
      ),
    ),
  );
}

void paintGrenadeTrajectory(
  Canvas canvas,
  List<GrenadePreviewPoint> points, {
  bool reducedMotion = false,
}) {
  if (points.isEmpty) return;
  final ink = Paint()
    ..color = const Color(0xbccbbb9c)
    ..isAntiAlias = false;
  Offset? last;
  for (final sample in points) {
    final p = sample.ground - Offset(0, reducedMotion ? 0 : sample.height);
    if (last != null && (p - last).distance < 23) continue;
    canvas.drawRect(
      Rect.fromCenter(center: p + const Offset(0, 2), width: 7, height: 7),
      Paint()..color = const Color(0xb3101112),
    );
    canvas.drawRect(Rect.fromCenter(center: p, width: 4, height: 4), ink);
    last = p;
  }
  final end = points.last.ground;
  // Compact ground brackets mark the fuse position after the bounce, not a damage promise.
  for (final x in [-1.0, 1.0]) {
    for (final y in [-1.0, 1.0]) {
      final p = end + Offset(x * 16, y * 12);
      canvas.drawRect(Rect.fromCenter(center: p, width: 9, height: 3), ink);
      canvas.drawRect(
        Rect.fromCenter(center: p + Offset(x * 3, y * -3), width: 3, height: 8),
        ink,
      );
    }
  }
  paintGrenade(canvas, end, 18);
}
