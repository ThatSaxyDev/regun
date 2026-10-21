import 'dart:ui';

import 'regun_art.dart';

/// A single authored solid is one draw, independent of its decorative seams.
/// Its intact base always shows the exact movement/projectile footprint.
class WallArt {
  static void perimeter(
    Canvas canvas,
    Rect bounds, {
    bool iron = false,
    bool inside = false,
  }) {
    final t = inside ? 24.0 : 48.0;
    final l = inside ? bounds.left : bounds.left - t,
        r = inside ? bounds.right : bounds.right + t;
    final top = inside ? bounds.top : bounds.top - t,
        bottom = inside ? bounds.bottom - t : bounds.bottom;
    for (var x = l; x < r; x += 256) {
      final right = (x + 256).clamp(l, r).toDouble();
      paint(canvas, Rect.fromLTRB(x, top, right, top + t), iron: iron);
      paint(canvas, Rect.fromLTRB(x, bottom, right, bottom + t), iron: iron);
    }
    for (var y = bounds.top; y < bounds.bottom; y += 192) {
      final end = (y + 192).clamp(bounds.top, bounds.bottom).toDouble();
      paint(canvas, Rect.fromLTRB(l, y, l + t, end), iron: iron);
      paint(canvas, Rect.fromLTRB(r - t, y, r, end), iron: iron);
    }
  }

  static void paint(
    Canvas canvas,
    Rect solid, {
    bool iron = false,
    Iterable<Offset> actors = const [],
  }) {
    if (!canvas.getLocalClipBounds().inflate(60).overlaps(solid)) return;
    final vertical = solid.height > solid.width * 1.4;
    final atlas = RegunArt.shared.contains('arenas/multiplayer_walls_hd')
        ? 'arenas/multiplayer_walls_hd'
        : 'arenas/multiplayer_walls';
    final sprite = RegunArt.shared.rawSprite(
      atlas,
      (iron ? 4 : 0) + (vertical ? 1 : 0),
    );
    final image = RegunArt.shared.image(atlas);
    final source = Rect.fromLTWH(
      sprite.srcPosition.x,
      sprite.srcPosition.y,
      sprite.srcSize.x,
      sprite.srcSize.y,
    );
    // Cap details stay fixed while the wall's quiet center follows its footprint.
    final insetX = source.width * .19, insetY = source.height * .19;
    final visual = Rect.fromLTRB(
      solid.left,
      solid.top - 32,
      solid.right,
      solid.bottom,
    );
    final occludes = actors.any(
      (p) =>
          p.dx >= solid.left - 28 &&
          p.dx <= solid.right + 28 &&
          p.dy >= solid.top - 45 &&
          p.dy < solid.bottom,
    );
    canvas.drawRect(
      solid.shift(const Offset(7, 7)),
      Paint()..color = const Color(0x88080D0B),
    );
    // Nine-slice the subregion through a canvas transform; drawImageNine expects
    // an entire image, so map its nine source patches explicitly.
    final sx = [
      source.left,
      source.left + insetX,
      source.right - insetX,
      source.right,
    ];
    final sy = [
      source.top,
      source.top + insetY,
      source.bottom - insetY,
      source.bottom,
    ];
    final dx = [
      visual.left,
      visual.left + (visual.width * .19).clamp(4, 24),
      visual.right - (visual.width * .19).clamp(4, 24),
      visual.right,
    ];
    final dy = [
      visual.top,
      visual.top + (visual.height * .19).clamp(4, 24),
      visual.bottom - (visual.height * .19).clamp(4, 24),
      visual.bottom,
    ];
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..color = Color.fromRGBO(210, 218, 203, occludes ? .48 : 1);
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 3; x++) {
        canvas.drawImageRect(
          image,
          Rect.fromLTRB(sx[x], sy[y], sx[x + 1], sy[y + 1]),
          Rect.fromLTRB(dx[x], dy[y], dx[x + 1], dy[y + 1]),
          paint,
        );
      }
    }
    canvas.drawRect(
      solid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xff82765D),
    );
  }
}
