import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/map/map_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/systems/arena_geometry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('authored frames are finite, inside textures and fit the mobile budget', () async {
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/art/manifest.json'),
    ) as Map;
    await RegunArt.shared.load();
    for (final entry in manifest.entries) {
      final data = entry.value as Map;
      if (data['texture'] == true) continue;
      final frames = data['frames'] as List;
      expect(
        frames.length,
        (data['columns'] as int) * (data['rows'] as int),
        reason: entry.key,
      );
      for (final raw in frames) {
        final frame = raw as Map;
        final r = (frame['rect'] as List).cast<num>();
        expect(r.every((n) => n.isFinite), isTrue);
        expect(r[0], greaterThanOrEqualTo(0));
        expect(r[1], greaterThanOrEqualTo(0));
        expect(r[2], greaterThan(0));
        expect(r[3], greaterThan(0));
        expect(r[0] + r[2], lessThanOrEqualTo(1.00001));
        expect(r[1] + r[3], lessThanOrEqualTo(1.00001));
        expect(frame['pivot'], inInclusiveRange(0, 1));
      }
    }
    for (final survivor in CharacterType.values) {
      await RegunArt.shared.acquireSurvivor(survivor.name);
      expect(RegunArt.shared.contains('characters/${survivor.name}'), isTrue);
      for (var f = 0; f < 4; f++) {
        expect(
          RegunArt.shared.survivorActionFrame(survivor.name, f, 3).srcSize.x,
          greaterThan(0),
        );
      }
      RegunArt.shared.releaseSurvivor(survivor.name);
    }
    expect(RegunArt.shared.decodedBytes, lessThanOrEqualTo(32 * 1024 * 1024));
    // ignore: avoid_print
    print(
      'Shared decoded art: ${(RegunArt.shared.decodedBytes / 1048576).toStringAsFixed(2)} MiB',
    );
    expect(
      identical(
        RegunArt.shared.rawSprite('items/items', 6),
        RegunArt.shared.rawSprite('items/items', 6),
      ),
      isTrue,
    );
  });

  test(
    'enemy walking anchors follow the body on every pose, including fourth',
    () async {
      await RegunArt.shared.load();
      for (final name in ['scorpion', 'mummy', 'ranged', 'runner', 'shield']) {
        final image = RegunArt.shared.image('enemies/$name');
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (var frame = 0; frame < 4; frame++) {
          final sprite = RegunArt.shared.sprite('enemies/$name', frame);
          final left = sprite.srcPosition.x.round();
          final top = sprite.srcPosition.y.round();
          final right = (sprite.srcPosition.x + sprite.srcSize.x).round();
          final bottom = top + (sprite.srcSize.y / 3).floor();
          var count = 0, sumX = 0;
          for (var y = top; y < bottom; y++) {
            for (var x = left; x < right; x++) {
              if (rgba.getUint8((y * image.width + x) * 4 + 3) >= 96) {
                count++;
                sumX += x;
              }
            }
          }
          expect(count, greaterThan(0));
          final bodyCenter =
              (sumX / count - sprite.srcPosition.x) / sprite.srcSize.x;
          final manifest = jsonDecode(
            await rootBundle.loadString('assets/art/manifest.json'),
          ) as Map;
          final pivot =
              manifest['enemies/$name']['frames'][frame]['pivot'] as num;
          expect(
            pivot,
            closeTo(bodyCenter, .035),
            reason:
                '$name walk pose $frame must not switch to a death-pose anchor',
          );
        }
      }
    },
  );

  test(
    'authored Tiled solids drive collision and safely relocate old saves',
    () async {
      final map = await MapComponent.loadMap();
      expect(map.bounds.rect, const Rect.fromLTWH(-2256, -2256, 4512, 4512));
      for (final arena in ArenaType.values) {
        final solids = map.obstacles(arena);
        expect(solids.length, arena == ArenaType.breach ? 0 : 6);
        final geometry = ArenaGeometry(map.bounds, obstacles: solids);
        for (final solid in solids) {
          final savedPosition = Vector2(solid.center.dx, solid.center.dy);
          geometry.constrain(savedPosition, 30);
          expect(
            solid.inflate(29.99).contains(savedPosition.toOffset()),
            isFalse,
          );
          expect(map.bounds.floor.contains(savedPosition.toOffset()), isTrue);
          final start = Vector2(solid.left - 60, solid.center.dy);
          geometry.move(start, Vector2(solid.width + 120, 0), 30);
          expect(start.x, lessThanOrEqualTo(solid.left - 30));
        }
      }
      expect(map.vents, isNotEmpty);
      for (final vent in map.vents) {
        expect(map.bounds.floor.contains(vent.toOffset()), isTrue);
      }
      const viewport = Size(1500, 700);
      for (final corner in [
        map.bounds.rect.topLeft,
        map.bounds.rect.topRight,
        map.bounds.rect.bottomLeft,
        map.bounds.rect.bottomRight,
      ]) {
        final camera = map.bounds.cameraPosition(
          Vector2(corner.dx, corner.dy),
          Vector2(viewport.width, viewport.height),
        );
        final visible = Rect.fromCenter(
          center: camera.toOffset(),
          width: viewport.width,
          height: viewport.height,
        );
        expect(map.bounds.rect.intersect(visible), visible);
      }
    },
  );
}
