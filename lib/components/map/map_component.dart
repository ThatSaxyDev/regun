import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/systems/arena_bounds.dart';

/// Tiled remains the authoring source for bounds/obstacles. Ground textures are
/// rendered as a handful of visible patches, rather than one widget per tile.
class MapComponent extends PositionComponent with HasGameReference<RegunGame> {
  MapComponent._(Vector2 dimensions, this._obstacles)
    : super(size: dimensions, position: -dimensions / 2, priority: -100) {
    bounds = ArenaBounds(Rect.fromLTWH(position.x, position.y, size.x, size.y));
  }
  late final ArenaBounds bounds;
  final Map<String, List<Rect>> _obstacles;
  static Future<MapComponent> loadMap() async {
    final root = XmlDocument.parse(
      await rootBundle.loadString('assets/tiles/maptile.tmx'),
    ).rootElement;
    double value(XmlElement e, String key) =>
        double.parse(e.getAttribute(key)!);
    final dimensions = Vector2(
      value(root, 'width') * value(root, 'tilewidth'),
      value(root, 'height') * value(root, 'tileheight'),
    );
    final obstacles = <String, List<Rect>>{};
    for (final group in root.findElements('objectgroup')) {
      obstacles[group.getAttribute('name')!] = [
        for (final o in group.findElements('object'))
          Rect.fromLTWH(
            value(o, 'x') - dimensions.x / 2,
            value(o, 'y') - dimensions.y / 2,
            value(o, 'width'),
            value(o, 'height'),
          ),
      ];
    }
    for (final arena in ArenaType.values) {
      if (!obstacles.containsKey('${arena.name}_obstacles')) {
        throw FormatException('Missing ${arena.name} obstacles');
      }
    }
    if (obstacles['foundry_vents']?.isNotEmpty != true) {
      throw const FormatException('Missing Foundry vent anchors');
    }
    final world = Rect.fromLTWH(
      -dimensions.x / 2,
      -dimensions.y / 2,
      dimensions.x,
      dimensions.y,
    );
    for (final objects in obstacles.values) {
      for (final rect in objects) {
        if (!world.contains(rect.topLeft) ||
            !world.contains(rect.bottomRight)) {
          throw const FormatException('Arena object outside world');
        }
      }
    }
    return MapComponent._(dimensions, obstacles);
  }

  List<Vector2> get vents => [
    for (final r in _obstacles['foundry_vents'] ?? <Rect>[])
      Vector2(r.left, r.top),
  ];
  List<Rect> obstacles(ArenaType arena) =>
      List.unmodifiable(_obstacles['${arena.name}_obstacles']!);
  @override
  void render(Canvas canvas) {
    final image = RegunArt.shared.image(
      'arenas/${game.loadout.arena.name}_floor',
    );
    final visible = game.camera.visibleWorldRect
        .shift(Offset(-position.x, -position.y))
        .intersect(Rect.fromLTWH(0, 0, size.x, size.y));
    const patch = 768.0;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..colorFilter = const ColorFilter.mode(
        Color(0xff6B7770),
        BlendMode.modulate,
      );
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.x, size.y));
    for (
      var x = (visible.left / patch).floor() * patch;
      x < visible.right;
      x += patch
    ) {
      for (
        var y = (visible.top / patch).floor() * patch;
        y < visible.bottom;
        y += patch
      ) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(x, y, patch + .2, patch + .2),
          paint,
        );
      }
    }
    canvas.restore();
  }
}
