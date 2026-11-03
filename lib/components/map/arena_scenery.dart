import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:regun/game.dart';
import 'package:regun/components/map/map_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/sluice_art.dart';
import 'package:regun/presentation/wall_art.dart';

/// Sparse authored landmarks and grounded props, sharing the actual collision
/// layout. Static prop depth is compared to the actors' ground/foot positions.
class ArenaScenery extends PositionComponent with HasGameReference<RegunGame> {
  ArenaScenery() : super(priority: -80);
  double _flowTime = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (!game.preferences.reducedMotion) _flowTime = (_flowTime + dt) % 31;
  }

  @override
  Future<void> onLoad() async {
    final foundry = game.loadout.arena == ArenaType.foundry;
    for (final rect in game.geometry.obstacles) {
      await game.world.add(
        _ArenaProp(
          rect,
          foundry || game.loadout.arena == ArenaType.relayGraveyard ? 4 : 0,
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final visible = game.camera.visibleWorldRect;
    final foundry = game.loadout.arena == ArenaType.foundry;
    final floor = game.map.bounds.floor;
    canvas.save();
    canvas.clipRect(floor);
    drawArenaDistricts(
      canvas,
      game.map,
      game.loadout.arena,
      visible,
      legacy: game.legacyArena,
      flowTime: game.preferences.reducedMotion ? 0 : _flowTime,
    );
    // Fence dimensions and its visible inner edge share ArenaBounds geometry.
    WallArt.perimeter(canvas, floor, iron: foundry, inside: true);
    canvas.restore();
  }
}

void drawArenaDistricts(
  Canvas canvas,
  MapComponent map,
  ArenaType arena,
  Rect visible, {
  bool legacy = false,
  double flowTime = 0,
}) {
  final marks = map.regions('${arena.name}_landmarks');
  final paint = Paint()..isAntiAlias = false;
  void strip(Rect rect, Color color) {
    if (visible.overlaps(rect)) canvas.drawRect(rect, paint..color = color);
  }

  if (arena == ArenaType.foundry) {
    if (!legacy && marks.length == 2) {
      final rail = marks.first, bypass = marks.last;
      for (var y = rail.top; y < rail.bottom; y += 74) {
        strip(
          Rect.fromLTWH(rail.left, y, rail.width, 16),
          const Color(0xff41372c),
        );
        strip(
          Rect.fromLTWH(rail.left, y, rail.width, 3),
          const Color(0xff635341),
        );
      }
      for (final x in [rail.left + 25, rail.right - 32]) {
        strip(
          Rect.fromLTWH(x, rail.top, 8, rail.height),
          const Color(0xff685f52),
        );
        strip(
          Rect.fromLTWH(x + 2, rail.top, 2, rail.height),
          const Color(0xff95816a),
        );
      }
      _pavers(
        canvas,
        bypass,
        visible,
        const Color(0xff3d3830),
        const Color(0xff5b4c39),
      );
    }
    for (final vent in map.anchors(
      legacy ? 'foundry_legacy_vents' : 'foundry_vents',
    )) {
      if (!visible.inflate(150).contains(vent.toOffset())) continue;
      RegunArt.shared
          .rawSprite('arenas/props', 5)
          .render(
            canvas,
            position: vent - Vector2(90, 42),
            size: Vector2(180, 84),
          );
    }
    return;
  }

  if (marks.length != 2 || legacy) return;
  switch (arena) {
    case ArenaType.floodworks:
      final bed = marks.first;
      _pavers(
        canvas,
        bed.inflate(33),
        visible,
        const Color(0xff333d37),
        const Color(0xff42483f),
      );
      if (visible.overlaps(bed)) {
        SluiceArt.channel(canvas, bed, flowTime: flowTime);
      }
      // The bypass is the intact dry stone lane south of the channel.
      // It remains continuous with the arena floor.
      break;
    case ArenaType.breach:
      final road = marks.first;
      _pavers(
        canvas,
        road,
        visible,
        const Color(0xff3c3b2e),
        const Color(0xff56503b),
      );
      break;
    case ArenaType.relayGraveyard:
      final trench = marks.first;
      for (var y = trench.top; y < trench.bottom; y += 110) {
        final bend = ((y - trench.top) / 110).floor() % 3 * 9;
        strip(
          Rect.fromLTWH(trench.center.dx + bend, y, 7, 83),
          const Color(0xff785340),
        );
        strip(
          Rect.fromLTWH(trench.center.dx + bend + 9, y + 15, 4, 89),
          const Color(0xff665e43),
        );
      }
      break;
    case ArenaType.foundry:
      break;
  }
}

void _pavers(Canvas canvas, Rect rect, Rect visible, Color base, Color rim) {
  if (!visible.overlaps(rect)) return;
  final paint = Paint()..isAntiAlias = false;
  canvas.save();
  canvas.clipRect(rect);
  for (var row = 0; rect.top + row * 44 < rect.bottom; row++) {
    final y = rect.top + row * 44;
    if (y + 44 < visible.top || y > visible.bottom) continue;
    for (var col = -1; rect.left + col * 73 < rect.right; col++) {
      final x = rect.left + col * 73 + (row.isOdd ? 36 : 0);
      if (x + 73 < visible.left || x > visible.right) continue;
      final n = (row * 13 + col * 7).abs() % 5;
      canvas.drawRect(
        Rect.fromLTWH(x + 2, y + 3, 69, 38),
        paint..color = Color.lerp(base, rim, n * .06)!,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 2, y + 3, 61 - n * 3, 3),
        paint..color = rim,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 9 + n * 5, y + 18, 15 + n * 4, 2),
        paint..color = const Color(0x53302522),
      );
    }
  }
  canvas.restore();
}

void _landmark(Canvas canvas, String id, Rect rect, Rect visible) {
  if (!visible.overlaps(rect)) return;
  final sprite = RegunArt.shared.image('arenas/district_$id');
  canvas.drawImageRect(
    sprite,
    Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
    rect,
    Paint()..filterQuality = FilterQuality.none,
  );
}

/// Sprites are selected from the same authored rectangles used for collision.
String? arenaSolidSprite(
  MapComponent map,
  ArenaType arena,
  Rect solid, {
  bool legacy = false,
}) {
  if (arena == ArenaType.floodworks &&
      map.regions('floodworks_gate').contains(solid)) {
    return 'sluice';
  }
  if (legacy) return null;
  if (arena == ArenaType.foundry) return 'press';
  if (arena == ArenaType.relayGraveyard) return 'relay';
  return null;
}

void paintArenaSolid(Canvas canvas, Rect footprint, String spriteName) {
  final rise = spriteName == 'sluice' ? 38.0 : 48.0;
  final rect = Rect.fromLTRB(
    footprint.left,
    footprint.top - rise,
    footprint.right,
    footprint.bottom,
  );
  canvas.drawOval(
    footprint.shift(const Offset(3, 5)),
    Paint()..color = const Color(0x71090e0b),
  );
  _landmark(canvas, spriteName, rect, rect.inflate(1));
}

/// Raised masonry with a fixed pixel scale and a grounded footprint.
void paintFloodDivider(Canvas canvas, Rect body) {
  final image = RegunArt.shared.image('arenas/floodworks_floor');
  final paint = Paint()..filterQuality = FilterQuality.none;
  canvas.drawRect(
    body.shift(const Offset(8, 12)),
    paint..color = const Color(0x88080d0b),
  );
  canvas.drawRect(body, paint..color = const Color(0xff252b25));
  canvas.save();
  final coping = Rect.fromLTRB(
    body.left + 5,
    body.top - 13,
    body.right - 5,
    body.bottom - 14,
  );
  canvas.clipRect(coping);
  paint.color = Colors.white;
  paint.colorFilter = const ColorFilter.mode(
    Color(0xffa8b09c),
    BlendMode.modulate,
  );
  for (var y = coping.top, row = 0.0; y < coping.bottom; y += 58, row++) {
    final source = Rect.fromLTWH(
      24 + (row * 47) % 160,
      32 + (row * 61) % 230,
      140,
      49,
    );
    canvas.drawImageRect(
      image,
      source,
      Rect.fromLTWH(coping.left, y, coping.width, 55),
      paint,
    );
  }
  canvas.restore();
  paint.colorFilter = null;
  canvas.drawRect(
    Rect.fromLTWH(body.left + 5, body.bottom - 14, body.width - 10, 12),
    paint..color = const Color(0xff393c31),
  );
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
    final base = footprint.shift(Offset(-position.x, -position.y));
    final arena = game.loadout.arena;
    final spriteName = arenaSolidSprite(
      game.map,
      arena,
      footprint,
      legacy: game.legacyArena,
    );
    if (spriteName != null) {
      paintArenaSolid(canvas, base, spriteName);
      return;
    }
    if (arena == ArenaType.floodworks) {
      paintFloodDivider(canvas, base);
      return;
    }
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
