import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/weapons/weapon_art.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/weapon_art_spec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'render both reload modes for all fifteen measured weapon packets',
    () async {
      final art = RegunArt.shared;
      await art.load();
      await (FontLoader('PressStart2P')
            ..addFont(rootBundle.load('assets/fonts/PressStart2P-Regular.ttf')))
          .load();
      final leased = WeaponType.values
          .where((w) => w.hasLeasedArt)
          .map((w) => w.atlasName)
          .toList();
      for (final name in leased) {
        await art.acquire(name);
      }
      for (var page = 0; page < 3; page++) {
        final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xff161B18), BlendMode.src);
        void label(String text, double x, double y) {
          final p = TextPainter(
            text: TextSpan(
              text: text,
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 10,
                color: Color(0xffD6C9AF),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          p.paint(canvas, Offset(x, y));
        }

        for (var col = 0; col < 4; col++) {
          label(
            '${col < 2 ? "EMPTY" : "TOP UP"} ${col.isEven ? "FEED" : "FINAL"}',
            15 + col * 220.0,
            12,
          );
        }
        for (var row = 0; row < 5; row++) {
          final type = WeaponType.values[page * 5 + row];
          label(type.title, 15, row * 155.0 + 48);
          for (var col = 0; col < 4; col++) {
            canvas.save();
            canvas.translate(110 + col * 220.0, row * 155.0 + 120);
            canvas.scale(math.min(2.6, 180 / WeaponArtSpec.of(type).width));
            paintWeapon(
              canvas,
              type,
              reload: col.isEven
                  ? .25
                  : (type == WeaponType.shotgun ? .97 : .86),
              tactical: col >= 2,
              reloadShells: 5,
            );
            canvas.restore();
          }
        }
        final picture = recorder.endRecording(),
            image = await picture.toImage(900, 815);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/reload-modes-$page.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }
      for (final name in leased.reversed) {
        art.release(name);
      }
    },
  );
}
