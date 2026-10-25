import 'package:regun/presentation/support_art.dart';
import 'package:regun/systems/support_rewards.dart';
import 'package:regun/systems/support_runtime.dart';

// Run from regun: flutter test tool/export_admin_art.dart
// Reuses the actual game painters/poses. Does not change gameplay or balance.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/weapons/weapon_art.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/weapon_art_spec.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/theme/upgrade_glyph.dart';
import 'package:regun/widgets/survivor_portrait.dart';

void main() {
  testWidgets('export the current game artwork to the sibling admin', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final destination = Directory('../regun-admin');
      if (!destination.existsSync()) {
        throw StateError('Missing sibling regun-admin');
      }
      final out = Directory('${destination.path}/assets/items');
      await out.create(recursive: true);
      final records = <String, Map<String, String>>{};
      final art = RegunArt.shared;
      await art.load();
      Future<void> export(
        String group,
        String id,
        String title,
        ui.Size size,
        void Function(ui.Canvas) paint,
        String source,
      ) async {
        final recorder = ui.PictureRecorder();
        paint(ui.Canvas(recorder));
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          size.width.round(),
          size.height.round(),
        );
        // Remove transparent export margins, preserving every visible pixel.
        // Thumbnails then use their available space instead of shrinking the art.
        final rgba = (await image.toByteData())!.buffer.asUint8List();
        var left = image.width, top = image.height, right = -1, bottom = -1;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            if (rgba[(y * image.width + x) * 4 + 3] == 0) continue;
            left = math.min(left, x);
            top = math.min(top, y);
            right = math.max(right, x);
            bottom = math.max(bottom, y);
          }
        }
        if (right < left) throw StateError('Empty art: $group.$id');
        final bounds = ui.Rect.fromLTRB(
          math.max(0, left - 6).toDouble(),
          math.max(0, top - 6).toDouble(),
          math.min(image.width, right + 7).toDouble(),
          math.min(image.height, bottom + 7).toDouble(),
        );
        final cropRecorder = ui.PictureRecorder();
        ui.Canvas(cropRecorder).drawImageRect(
          image,
          bounds,
          ui.Offset.zero & bounds.size,
          ui.Paint()..filterQuality = ui.FilterQuality.none,
        );
        final croppedPicture = cropRecorder.endRecording();
        final cropped = await croppedPicture.toImage(
          bounds.width.round(),
          bounds.height.round(),
        );
        final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
        cropped.dispose();
        croppedPicture.dispose();
        final path = 'assets/items/$group-$id.png';
        await File('${destination.path}/$path')
            .writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
        records['$group.$id'] = {
          'asset': path,
          'label': title,
          'source': source,
        };
      }

      for (final weapon in WeaponType.values) {
        final spec = WeaponArtSpec.of(weapon);
        await art.acquire(spec.atlas);
        await export(
          'weapons',
          weapon.name,
          weapon.title,
          const ui.Size(320, 144),
          (canvas) {
            final bounds = ui.Rect.fromLTWH(
              -spec.width * spec.grip - 8,
              -spec.height * .55 - 12,
              spec.width + 16,
              spec.height + 30,
            );
            final scale = math.min(300 / bounds.width, 132 / bounds.height);
            canvas.translate(
              160 - bounds.center.dx * scale,
              72 - bounds.center.dy * scale,
            );
            canvas.scale(scale);
            paintWeapon(canvas, weapon, reducedMotion: true);
          },
          '${spec.atlas}: paintWeapon, assembled resting parts',
        );
        art.release(spec.atlas);
      }
      Future<void> portrait(
        String group,
        String id,
        String title,
        CharacterType character, [
        String style = 'standard',
      ]) async {
        await art.acquire('characters/${character.name}');
        await export(group, id, title, const ui.Size(160, 180), (canvas) {
          canvas.translate(8, 8);
          final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
          final tint = survivorTint(style);
          if (tint != null) {
            paint.colorFilter = ui.ColorFilter.mode(
              tint,
              ui.BlendMode.modulate,
            );
          }
          art
              .survivorIdleFrame(character.name, 1, 0)
              .render(canvas, size: Vector2.all(144), overridePaint: paint);
        }, 'characters/${character.name}: idle facing 1 frame 0; style $style');
        art.release('characters/${character.name}');
      }

      for (final character in CharacterType.values) {
        await portrait('survivors', character.name, character.title, character);
      }
      for (final style in [
        'copper',
        'moss',
        'ivory',
        'rust',
        'slate',
        'dusk',
      ]) {
        await portrait(
          'cosmetics',
          style,
          '${style[0].toUpperCase()}${style.substring(1)}',
          CharacterType.rook,
          style,
        );
      }
      final catalog = jsonDecode(
        await File('../regun-admin/assets/data/catalog.json').readAsString(),
      ) as Map;
      final fields = catalog['fields'] as List;
      final upgrades = fields
          .where((f) => f['group'] == 'powerups')
          .map((f) => f['itemId'] as String)
          .toSet();
      for (final id in upgrades) {
        final upgrade = PowerUp.values.byName(id);
        await export('powerups', id, upgrade.title, const ui.Size(64, 64), (
          canvas,
        ) {
          paintPixelGlyph(
            canvas,
            const ui.Rect.fromLTWH(8, 8, 48, 48),
            upgrade.glyph,
            const ui.Color(0xffD5BA75),
          );
        }, 'UpgradeGlyph / PixelGlyph.${upgrade.glyph.name}');
      }
      for (final boss in BossKind.values) {
        final atlas = 'bosses/${boss.name}';
        await art.acquire(atlas);
        final sprite = art.rawSprite(atlas, 0);
        await export('bosses', boss.name, boss.title, const ui.Size(160, 160), (
          canvas,
        ) {
          final scale = math.min(
            144 / sprite.srcSize.x,
            144 / sprite.srcSize.y,
          );
          final size = sprite.srcSize * scale;
          sprite.render(
            canvas,
            position: (Vector2.all(160) - size) / 2,
            size: size,
          );
        }, '$atlas: idle frame 0');
        art.release(atlas);
      }
      for (final f in fields) {
        final group = f['group'], id = f['itemId'];
        if (group == 'ranks' && id != 'meta') {
          records['ranks.$id'] = records['powerups.$id']!;
        }
        if (group == 'effects') {
          final weapon = WeaponType.values.singleWhere(
            (w) => w.title == f['item'],
          );
          records['effects.$id'] = records['weapons.${weapon.name}']!;
        }
      }
      for (final name in SupportArt.atlases) {
        await art.acquire(name);
      }
      for (final family in SupportFamily.values) {
        await export(
          'support',
          family.name,
          family == SupportFamily.sentry ? 'Sentry Gun' : 'Aura Salad',
          const ui.Size(200, 200),
          (canvas) {
            final unit = SupportUnit(
              SupportCard(family, 1),
              1,
              const ui.Offset(75, 155),
            )..phase = 'active';
            if (family == SupportFamily.aura) {
              canvas.translate(50, 50);
              canvas.scale(.6);
              SupportArt.floor(canvas, unit, const SupportConfig({}));
            }
            SupportArt.body(canvas, unit, const SupportConfig({}));
          },
          'SupportArt: authored base/head/emitter and material field',
        );
      }
      for (final name in SupportArt.atlases) {
        art.release(name);
      }
      await art.acquire('effects/cutter_ring');
      final cutter = art.image('effects/cutter_ring');
      await export(
        'projectiles',
        'cuttingRing',
        'Ring cutter',
        const ui.Size(256, 256),
        (canvas) {
          canvas.drawImage(
            cutter,
            ui.Offset.zero,
            ui.Paint()..filterQuality = ui.FilterQuality.none,
          );
        },
        'effects/cutter_ring: generated iron cutter, 256px decode',
      );
      art.release('effects/cutter_ring');
      // Brand mark is already an approved transparent export.
      final brandCodec = await ui.instantiateImageCodec(
        await File('assets/art/branding/rook_mark.png').readAsBytes(),
        targetWidth: 256,
      );
      final brand = (await brandCodec.getNextFrame()).image;
      await export(
        'branding',
        'rook',
        'Regun Rook mark',
        const ui.Size(256, 256),
        (canvas) {
          canvas.drawImageRect(
            brand,
            ui.Rect.fromLTWH(
              0,
              0,
              brand.width.toDouble(),
              brand.height.toDouble(),
            ),
            const ui.Rect.fromLTWH(0, 0, 256, 256),
            ui.Paint()..filterQuality = ui.FilterQuality.none,
          );
        },
        'assets/art/branding/rook_mark.png',
      );
      brand.dispose();
      brandCodec.dispose();
      await File('${out.path}/manifest.json').writeAsString(
        '${const JsonEncoder.withIndent('  ').convert({'schema': 1, 'items': records})}\n',
      );
      await File(
        '${destination.path}/lib/models/item_art_catalog.dart',
      ).writeAsString(
        '// Generated by regun/tool/export_admin_art.dart. No gameplay dependency.\n'
        'const itemArtCatalog = <String, Map<String, String>>${jsonEncode(records)};\n',
      );
    });
  });
}
