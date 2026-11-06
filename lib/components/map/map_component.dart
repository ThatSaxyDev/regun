import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
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
  static Future<String>? _webLayout;
  static const _layoutAsset = 'assets/tiles/maptile.tmx';

  static Future<String> preloadWebLayout() => _webLayout ??= _readWebLayout();

  static Future<String> _readWebLayout() async {
    try {
      return await rootBundle
          .loadString(_layoutAsset, cache: false)
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      _webLayout = null;
      rethrow;
    }
  }

  static Future<MapComponent> loadMap() async {
    final xml = await (kIsWeb
        ? preloadWebLayout()
        : rootBundle.loadString(_layoutAsset, cache: false));
    final root = XmlDocument.parse(xml).rootElement;
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

  List<Vector2> get vents => anchors('foundry_vents');

  List<Vector2> anchors(String group) => [
    for (final r in regions(group)) Vector2(r.left, r.top),
  ];

  List<Rect> obstacles(ArenaType arena, {bool legacy = false}) =>
      List.unmodifiable([
        ...regions(
          legacy && arena == ArenaType.foundry
              ? 'foundry_legacy_obstacles'
              : '${arena.name}_obstacles',
        ),
        if (arena == ArenaType.floodworks) ...regions('floodworks_gate'),
      ]);

  List<Rect> regions(String group) =>
      List.unmodifiable(_obstacles[group] ?? const <Rect>[]);

  late final List<Rect> foundryTracks = _foundryTracks();

  List<Rect> _foundryTracks() {
    final landmarks = _obstacles['foundry_landmarks'];
    if (landmarks == null || landmarks.length < 2) return const [];
    return List.unmodifiable(landmarks.take(landmarks.length - 1));
  }

  static const floorGrade = ColorFilter.mode(
    Color(0xff6B7770),
    BlendMode.modulate,
  );
  static const breachGrade = ColorFilter.matrix([
    .30,
    .16,
    .08,
    0,
    8,
    .15,
    .36,
    .09,
    0,
    12,
    .13,
    .22,
    .36,
    0,
    16,
    0,
    0,
    0,
    1,
    0,
  ]);

  String footstepSurface(
    ArenaType arena,
    Offset contact, {
    required bool legacy,
  }) {
    if (!legacy) {
      final landmark = _obstacles['${arena.name}_landmarks']?.firstOrNull;
      if (arena == ArenaType.floodworks &&
          landmark != null &&
          landmark.contains(contact)) {
        return 'wet';
      }
      if (arena == ArenaType.foundry) {
        for (final track in foundryTracks) {
          if (contact.dy >= track.top &&
              contact.dy < track.bottom &&
              (contact.dx - track.center.dx).abs() > 31 &&
              (contact.dx - track.center.dx).abs() < 54) {
            return 'metal';
          }
        }
      }
    }
    return 'stone';
  }

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
      ..colorFilter = game.loadout.arena == ArenaType.breach
          ? breachGrade
          : floorGrade;
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
