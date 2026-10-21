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
    required this.progress,
    required this.remaining,
    this.pressed = false,
    this.opacity = 1,
  });
  final int charges;
  final double progress, remaining, opacity;
  final bool pressed;
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
      paintGrenade(canvas, Offset(56, pressed ? 45 : 42), 43);
    } else {
      canvas.saveLayer(
        const Rect.fromLTWH(32, 16, 48, 45),
        Paint()..color = const Color(0x70666666),
      );
      paintGrenade(canvas, const Offset(56, 35), 30);
      canvas.restore();
      _text(canvas, '${remaining.ceil()}s', 15, ink, 53);
    }
    for (var i = 0; i < 2; i++) {
      final r = Rect.fromLTWH(35 + i * 24.0, 73, 18, 8);
      canvas.drawRect(r, Paint()..color = tone(0xff100d13));
      canvas.drawRect(
        r.deflate(1),
        Paint()..color = i < charges ? ink : tone(0xff443e42),
      );
      if (i == charges && charges < 2) {
        canvas.drawRect(
          Rect.fromLTWH(r.left + 1, r.top + 1, 16 * progress, 6),
          Paint()..color = tone(0xff9e8970),
        );
      }
    }
    _text(canvas, 'THROW', 16, ink, 96);
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
      old.charges != charges ||
      old.progress != progress ||
      old.remaining.ceil() != remaining.ceil() ||
      old.pressed != pressed ||
      old.opacity != opacity;
}

class GrenadeTapButton extends StatefulWidget {
  const GrenadeTapButton({
    super.key,
    required this.size,
    required this.charges,
    required this.progress,
    required this.remaining,
    required this.opacity,
    this.onTap,
  });
  final double size, progress, remaining, opacity;
  final int charges;
  final VoidCallback? onTap;
  @override
  State<GrenadeTapButton> createState() => _GrenadeTapButtonState();
}

class _GrenadeTapButtonState extends State<GrenadeTapButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.onTap == null
        ? null
        : (_) {
            setState(() => pressed = true);
            widget.onTap!();
          },
    onTapUp: (_) => setState(() => pressed = false),
    onTapCancel: () => setState(() => pressed = false),
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: GrenadeButtonPainter(
        charges: widget.charges,
        progress: widget.progress,
        remaining: widget.remaining,
        pressed: pressed && widget.charges > 0,
        opacity: widget.opacity,
      ),
    ),
  );
}
