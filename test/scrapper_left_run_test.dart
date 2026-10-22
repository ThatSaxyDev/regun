import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/regun_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Scrapper left run alternates broad contact with narrow passing legs',
    () async {
      final art = RegunArt.shared;
      await art.load();
      final image = art.image('characters/scrapper_left_run');
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final widths = <int>[];
      for (var i = 0; i < 8; i++) {
        final sprite = art.survivorRunFrame('scrapper', 2, i);
        expect(
          identical(sprite, art.sprite('characters/scrapper_left_run', i)),
          isTrue,
        );
        var left = image.width, right = 0;
        final x0 = sprite.srcPosition.x.ceil(),
            x1 = (sprite.srcPosition.x + sprite.srcSize.x).floor();
        final y0 = (sprite.srcPosition.y + sprite.srcSize.y * .67).ceil(),
            y1 = (sprite.srcPosition.y + sprite.srcSize.y).floor();
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            if (bytes.getUint8((y * image.width + x) * 4 + 3) > 100) {
              if (x < left) left = x;
              if (x > right) right = x;
            }
          }
        }
        widths.add(right - left + 1);
      }
      expect(widths[2], lessThan(widths[0] * .75));
      expect(widths[6], lessThan(widths[4] * .75));
      expect(
        identical(
          art.survivorRunFrame('scrapper', 0, 0),
          art.sprite('characters/scrapper_run', 0),
        ),
        isTrue,
      );
      final recorder = ui.PictureRecorder(), canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xff202429), ui.BlendMode.src);
      for (var i = 0; i < 8; i++) {
        art
            .survivorRunFrame('scrapper', 2, i)
            .render(
              canvas,
              position: Vector2(i * 150.0, 0),
              size: Vector2.all(150),
            );
      }
      final picture = recorder.endRecording(),
          preview = await picture.toImage(1200, 160);
      final png = (await preview.toByteData(format: ui.ImageByteFormat.png))!;
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/scrapper-left-run.png')
          .writeAsBytes(png.buffer.asUint8List());
      preview.dispose();
      picture.dispose();
    },
  );
}
