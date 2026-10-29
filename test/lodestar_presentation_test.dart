import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/lodestar_art.dart';
import 'package:regun/presentation/lodestar_battle_art.dart';
import 'package:regun/systems/lodestar/lodestar_combat.dart';
import 'package:regun/systems/lodestar/lodestar_rig.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';

void main() {
  testWidgets(
    'both arena materials, finite impacts and sequential burrow paint visible pixels',
    (tester) async {
      await tester.runAsync(() async {
        await (FontLoader('Orbitron')
              ..addFont(rootBundle.load('assets/fonts/Orbitron-Regular.ttf')))
            .load();
        final assets = LodestarAssets();
        await assets.load(combat: true);
        try {
          final dir = Directory('docs/validation/lodestar-training-2026-10-29')
            ..createSync(recursive: true);
          final f = LodestarCombat(
            rig: LodestarRig(head: const Offset(260, 0)),
            bounds: const Rect.fromLTRB(-2000, -1500, 2000, 1500),
            clear: (_, __, ___) => true,
            poseLegal: (_) => true,
            hurt: (_, __) => false,
            signal: (_) {},
          );
          f.phase = LodestarPhase.travel;
          f.depths.fillRange(0, 6, 0);
          f.player = const Offset(300, 220);
          final art = LodestarBattleArt(assets);
          Future<void> capture(String name, ArenaType arena) async {
            final rec = ui.PictureRecorder(),
                c = Canvas(rec)..translate(750, 350);
            final floor = assets.floors[arena.name]!;
            for (var x = -1536.0; x < 1536; x += 768) {
              for (var y = -768.0; y < 768; y += 768) {
                c.drawImageRect(
                  floor,
                  Rect.fromLTWH(
                    0,
                    0,
                    floor.width.toDouble(),
                    floor.height.toDouble(),
                  ),
                  Rect.fromLTWH(x, y, 768, 768),
                  Paint()
                    ..filterQuality = FilterQuality.none
                    ..colorFilter = const ColorFilter.mode(
                      Color(0xff6B7770),
                      BlendMode.modulate,
                    ),
                );
              }
            }
            art.floor(c, f, arena, false);
            art.body(c, f, false);
            art.ordnance(c, f, arena, false);
            final pic = rec.endRecording(), im = await pic.toImage(1500, 700);
            File('${dir.path}/$name-${arena.name}.png').writeAsBytesSync(
              (await im.toByteData(format: ui.ImageByteFormat.png))!.buffer
                  .asUint8List(),
            );
            im.dispose();
            pic.dispose();
          }

          for (final arena in ArenaType.values) {
            await capture('arsenal', arena);
          }
          f.shots.add(
            LodestarShot(
                const Offset(0, 0),
                const Offset(150, 100),
                1,
                shell: true,
              )
              ..position = const Offset(50, 30)
              ..age = .5,
          );
          for (final arena in ArenaType.values) {
            await capture('mortar-flight', arena);
          }
          f.shots.clear();
          f.phase = LodestarPhase.entry;
          f.entry = f.rig.poses.first.socket(const Offset(120, 0));
          f.depths.setAll(0, [.8, .4, .05, 0, 0, 0]);
          for (final arena in ArenaType.values) {
            await capture('burrow-mask', arena);
          }
          f.depths.fillRange(0, 6, 0);
          f.phase = LodestarPhase.travel;
          f.localDamage(
            f.sections.primary(
              LodestarSection.accelerator,
              100,
              LodestarHitLedger(),
            ),
          );
          f.localDamage(
            f.sections.primary(
              LodestarSection.feeder,
              100,
              LodestarHitLedger(),
            ),
          );
          for (final arena in ArenaType.values) {
            await capture('local-wrecks', arena);
          }
          f.shots.add(
            LodestarShot(
                const Offset(0, 0),
                const Offset(150, 100),
                2,
                shell: true,
              )
              ..age = 1.145
              ..position = const Offset(150, 100),
          );
          f.advance(1 / 120);
          expect(f.bursts.any((b) => b.blast && b.radius == 110), isTrue);
          for (final reduced in [false, true]) {
            final rec = ui.PictureRecorder(),
                c = Canvas(rec)..translate(100, -0);
            art.ordnance(c, f, ArenaType.breach, reduced);
            final pic = rec.endRecording(), im = await pic.toImage(512, 256);
            final pixels = (await im.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            var visible = 0;
            for (var i = 0; i < pixels.length; i += 4) {
              if (pixels[i + 3] > 50) visible++;
            }
            expect(
              visible,
              greaterThan(150),
              reason: 'actual airborne impact core, reduced=$reduced',
            );
            im.dispose();
            pic.dispose();
          }
          f.localDamage(
            f.sections.primary(
              LodestarSection.mortars,
              100,
              LodestarHitLedger(),
            ),
          );
          expect(f.sections.coreExposed, isTrue);
          f.elapsed += .5;
          for (final arena in ArenaType.values) {
            await capture('core-exposed', arena);
          }
          f.localDamage(
            f.sections.primary(LodestarSection.head, 80, LodestarHitLedger()),
          );
          for (final time in [0.0, .65, 1.6, 3.2, 3.9]) {
            f.age = time;
            for (final arena in ArenaType.values) {
              await capture('shutdown-$time', arena);
            }
          }
        } finally {
          assets.dispose();
        }
      });
    },
  );
}
