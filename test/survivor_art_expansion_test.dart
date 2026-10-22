import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/regun_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every active survivor plus largest pair and Cinder fits existing texture budget', () async {
    final art = RegunArt.shared;
    await art.load();
    final extra = [
      'bosses/marshal',
      'bosses/sovereign',
      'weapons/cinder_hose',
      'effects/cinder_flame',
    ];
    for (final name in extra) {
      await art.acquire(name);
    }
    var peak = 0;
    try {
      for (final c in CharacterType.values) {
        await art.acquireSurvivor(c.name);
        peak = peak > art.decodedBytes ? peak : art.decodedBytes;
        expect(
          art.decodedBytes,
          lessThanOrEqualTo(32 * 1024 * 1024),
          reason: c.name,
        );
        art.releaseSurvivor(c.name);
      }
    } finally {
      for (final name in extra.reversed) {
        art.release(name);
      }
    }
    // ignore: avoid_print
    print('Largest survivor/pair/Cinder decoded budget: $peak bytes');
  });
  test('new left gaits alternate contact and passing; all poses render grounded', () async {
    final art = RegunArt.shared;
    await art.load();
    final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xff202429), ui.BlendMode.src);
    for (final c in CharacterType.values) {
      await art.acquireSurvivor(c.name);
      try {
        for (var f = 0; f < 4; f++) {
          final signatures = <String>{};
          for (var i = 0; i < 8; i++) {
            final sprite = art.survivorRunFrame(c.name, f, i);
            final bytes = (await sprite.image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final x0 = sprite.srcPosition.x.ceil(),
                x1 = (sprite.srcPosition.x + sprite.srcSize.x).floor();
            final y0 = (sprite.srcPosition.y + sprite.srcSize.y * .67).ceil(),
                y1 = (sprite.srcPosition.y + sprite.srcSize.y).floor();
            var left = x1, right = x0;
            final bits = <int>[];
            for (var y = y0; y < y1; y++) {
              for (var x = x0; x < x1; x++) {
                final alpha = bytes.getUint8(
                  (y * sprite.image.width + x) * 4 + 3,
                );
                if (alpha >= 100) {
                  if (x < left) left = x;
                  if (x > right) right = x;
                }
                bits.add(alpha);
              }
            }
            signatures.add('${right - left}:${Object.hashAll(bits)}');
            if (c.expansion && f == 2) {
              // Broad contact at0/4 and genuinely narrow passing at2/6.
              final broad = art.survivorRunFrame(c.name, f, i < 4 ? 0 : 4);
              if (i == 2 || i == 6) {
                var l = 100000, r = -1;
                for (
                  var y = (broad.srcPosition.y + broad.srcSize.y * .67).ceil();
                  y < (broad.srcPosition.y + broad.srcSize.y).floor();
                  y++
                ) {
                  for (
                    var x = broad.srcPosition.x.ceil();
                    x < (broad.srcPosition.x + broad.srcSize.x).floor();
                    x++
                  ) {
                    if (bytes.getUint8((y * broad.image.width + x) * 4 + 3) >=
                        100) {
                      if (x < l) l = x;
                      if (x > r) r = x;
                    }
                  }
                }
                expect(
                  right - left + 1,
                  lessThan((r - l + 1) * .80),
                  reason:
                      '${c.name} passing pose $i must not slide a planted leg',
                );
              }
            }
            if (f == 2) {
              canvas.save();
              canvas.translate(i * 150.0, c.index * 150.0);
              sprite.render(canvas, size: Vector2.all(140));
              canvas.restore();
            }
          }
          expect(
            signatures.length,
            greaterThanOrEqualTo(4),
            reason: '${c.name} facing$f leg motion',
          );
          for (var a = 0; a < 4; a++) {
            expect(
              art.survivorActionFrame(c.name, f, a).srcSize.y,
              greaterThan(0),
            );
          }
        }
      } finally {
        art.releaseSurvivor(c.name);
      }
    }
    final picture = recorder.endRecording(),
        image = await picture.toImage(1200, 1500);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory('build/test-previews').create(recursive: true);
    await File('build/test-previews/ten-survivor-left-gaits.png')
        .writeAsBytes(data.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
  test(
    'render runtime all-direction cycles and ten idle silhouettes',
    () async {
      final art = RegunArt.shared;
      await art.load();
      for (final c in CharacterType.values) {
        await art.acquireSurvivor(c.name);
      }
      try {
        final dir = Directory('build/test-previews/ten-survivor-cycles');
        await dir.create(recursive: true);
        for (var phase = 0; phase < 8; phase++) {
          final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
          canvas.drawColor(const ui.Color(0xff202429), ui.BlendMode.src);
          for (final c in CharacterType.values) {
            for (var facing = 0; facing < 4; facing++) {
              canvas.save();
              canvas.translate(c.index * 150.0, facing * 150.0);
              art
                  .survivorRunFrame(c.name, facing, phase)
                  .render(canvas, size: Vector2.all(140));
              canvas.restore();
            }
          }
          final picture = recorder.endRecording(),
              image = await picture.toImage(1500, 600);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File('${dir.path}/$phase.png')
              .writeAsBytes(data.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        }
      } finally {
        for (final c in CharacterType.values) {
          art.releaseSurvivor(c.name);
        }
      }
      expect(art.decodedBytes, lessThan(32 * 1024 * 1024));
    },
  );
}
