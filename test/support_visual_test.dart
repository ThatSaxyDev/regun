import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/support_art.dart';
import 'package:regun/systems/support_rewards.dart';
import 'package:regun/systems/support_runtime.dart';
import 'package:regun/data/loadout.dart';

void main() {
  testWidgets(
    'aura has advancing inner energy and a steady reduced-motion seal',
    (tester) async {
      await tester.runAsync(() async {
        await RegunArt.shared.load();
        for (final n in SupportArt.atlases) {
          await RegunArt.shared.acquire(n);
        }
        final directory = Directory('build/test-previews/aura-energy-frames');
        await directory.create(recursive: true);
        Future<List<int>> frame(
          double time, {
          bool reduced = false,
          int? index,
        }) async {
          final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
          canvas.drawRect(
            const Rect.fromLTWH(0, 0, 384, 384),
            Paint()..color = const Color(0xff292C27),
          );
          final floor = RegunArt.shared.image('arenas/breach_floor');
          canvas.drawImageRect(
            floor,
            Rect.fromLTWH(
              0,
              0,
              floor.width.toDouble(),
              floor.height.toDouble(),
            ),
            const Rect.fromLTWH(0, 0, 384, 384),
            Paint()..filterQuality = FilterQuality.none,
          );
          final u =
              SupportUnit(
                  const SupportCard(SupportFamily.aura, 2),
                  1,
                  const Offset(192, 192),
                )
                ..phase = 'active'
                ..life = time;
          const config = SupportConfig({});
          final ambient = BossArt.ambient(ArenaType.breach);
          SupportArt.floor(
            canvas,
            u,
            config,
            ambient: ambient,
            reducedMotion: reduced,
          );
          SupportArt.body(
            canvas,
            u,
            config,
            ambient: ambient,
            reducedMotion: reduced,
          );
          final picture = recorder.endRecording(),
              image = await picture.toImage(384, 384);
          final raw = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (index != null) {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '${directory.path}/${index.toString().padLeft(3, '0')}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
          }
          image.dispose();
          picture.dispose();
          return raw!.buffer.asUint8List();
        }

        expect(await frame(1, reduced: true), await frame(2, reduced: true));
        final first = await frame(0, index: 0),
            later = await frame(.25, index: 4);
        expect(first, isNot(equals(later)));
        for (var i = 1; i < 32; i++) {
          if (i != 4) await frame(i / 16, index: i);
        }
        for (final n in SupportArt.atlases) {
          RegunArt.shared.release(n);
        }
      });
    },
  );
}
