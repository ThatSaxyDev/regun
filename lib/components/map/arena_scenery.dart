import 'package:regun/presentation/arena_machine_art.dart';
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
    if (!game.bossRush) {
      for (final machine in game.arenaMachines) {
        if (visible.overlaps(machine.area)) {
          ArenaMachineArt.floor(
            canvas,
            machine,
            game.preferences.reducedMotion,
          );
        }
      }
    }
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
  if (arena == ArenaType.foundry) {
    if (!legacy && marks.length >= 2) {
      for (final track in map.foundryTracks) {
        _railTrack(canvas, track, visible);
      }
      _pavers(canvas, marks.last, visible, arena);
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
      _pavers(canvas, bed.inflate(33), visible, arena);
      if (visible.overlaps(bed)) {
        SluiceArt.channel(canvas, bed, flowTime: flowTime);
      }
      // The bypass is the intact dry stone lane south of the channel.
      // It remains continuous with the arena floor.
      break;
    case ArenaType.breach:
      final road = marks.first;
      _pavers(canvas, road, visible, arena);
      break;
    case ArenaType.relayGraveyard:
      _relayTrench(canvas, marks.first, visible);
      break;
    case ArenaType.foundry:
      break;
  }
}

void _railTrack(Canvas canvas, Rect track, Rect visible) {
  if (!track.overlaps(visible)) return;
  final floor = RegunArt.shared.image('arenas/foundry_floor');
  final material = Paint()..filterQuality = FilterQuality.none;
  final shadow = Paint()..color = const Color(0xc4141516);
  final ballast = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(
      Color(0xff514d48),
      BlendMode.modulate,
    );
  final edge = Paint()..color = const Color(0xff60554b);
  final iron = Paint()..color = const Color(0xff333337);
  final rivet = Paint()..color = const Color(0xff8a7561);
  canvas.drawRect(track, shadow);
  canvas.save();
  canvas.clipRect(track);
  final start = ((visible.top - track.top) / 58).floor().clamp(0, 1000);
  for (
    var row = start, y = track.top + start * 58;
    y < track.bottom && y < visible.bottom;
    row++, y += 58
  ) {
    final source = Rect.fromLTWH(
      (row % 4) * floor.width / 5,
      floor.height * .16,
      floor.width * .19,
      floor.height * .22,
    );
    canvas.drawImageRect(
      floor,
      source,
      Rect.fromLTWH(track.left + 3, y, track.width - 6, 58),
      ballast,
    );
    final sleeper = Rect.fromLTWH(track.left + 4, y + 14, track.width - 8, 20);
    canvas.drawRect(sleeper.shift(const Offset(0, 4)), shadow);
    canvas.drawImageRect(floor, source, sleeper, material);
    canvas.drawRect(
      Rect.fromLTWH(sleeper.left, sleeper.top, sleeper.width, 2),
      edge,
    );
    for (final x in [track.center.dx - 42, track.center.dx + 42]) {
      canvas.drawRect(Rect.fromLTWH(x - 9, y, 18, 58), shadow);
      canvas.drawRect(Rect.fromLTWH(x - 5, y, 10, 58), iron);
      canvas.drawRect(Rect.fromLTWH(x - 2, y, 4, 58), edge);
      canvas.drawRect(Rect.fromLTWH(x + 3, y + 14, 7, 6), rivet);
      canvas.drawRect(Rect.fromLTWH(x - 9, y + 28, 6, 5), rivet);
    }
  }
  for (final y in [track.top, track.bottom - 17]) {
    final stop = Rect.fromLTWH(track.left + 2, y, track.width - 4, 17);
    canvas.drawImageRect(
      floor,
      const Rect.fromLTWH(6, 8, 72, 25),
      stop,
      material,
    );
    canvas.drawRect(Rect.fromLTWH(stop.left, stop.top, stop.width, 3), edge);
  }
  canvas.restore();
}

void _relayTrench(Canvas canvas, Rect trench, Rect visible) {
  if (!trench.overlaps(visible)) return;
  final floor = RegunArt.shared.image('arenas/relayGraveyard_floor');
  final source = Rect.fromLTWH(
    floor.width * .229,
    floor.height * .079,
    floor.width * .109,
    floor.height * .18,
  );
  final channel = Rect.fromCenter(
    center: trench.center,
    width: 82,
    height: trench.height,
  );
  canvas.save();
  canvas.clipRect(channel);
  final paint = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(
      Color(0xff85847e),
      BlendMode.modulate,
    );
  final first = ((visible.top - trench.top) / 142).floor().clamp(0, 1000);
  for (
    var y = trench.top + first * 142;
    y < trench.bottom && y < visible.bottom;
    y += 142
  ) {
    canvas.drawImageRect(
      floor,
      source,
      Rect.fromLTWH(channel.left, y, channel.width, 142),
      paint,
    );
  }
  canvas.restore();
}

void _pavers(Canvas canvas, Rect rect, Rect visible, ArenaType arena) {
  if (!visible.overlaps(rect)) return;
  final tile = RegunArt.shared.image('arenas/${arena.name}_floor');
  final material = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(
      Color(0xff858371),
      BlendMode.modulate,
    );
  final joint = Paint()..color = const Color(0x8c11160f);
  canvas.save();
  canvas.clipRect(rect);
  for (var row = 0, y = rect.top; y < rect.bottom; row++, y += 44) {
    if (y + 44 < visible.top || y > visible.bottom) continue;
    for (var col = -1; rect.left + col * 73 < rect.right; col++) {
      final x = rect.left + col * 73 + (row.isOdd ? 36 : 0);
      if (x + 73 < visible.left || x > visible.right) continue;
      final n = (row * 31 + col * 17).abs();
      final w = tile.width.toDouble(), h = tile.height.toDouble();
      final source = Rect.fromLTWH(
        (n % 67) / 100 * w,
        (n % 72) / 100 * h,
        w * .30,
        h * .24,
      );
      canvas.drawRect(Rect.fromLTWH(x + 1, y + 2, 72, 42), joint);
      canvas.drawImageRect(
        tile,
        source,
        Rect.fromLTWH(x + 1, y + 1, 71, 40),
        material,
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
      if (!game.bossRush) {
        for (final machine in game.arenaMachines) {
          if (machine.body == footprint) {
            ArenaMachineArt.head(
              canvas,
              machine,
              Offset(-position.x, -position.y),
              game.preferences.reducedMotion,
            );
          }
        }
      }
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
