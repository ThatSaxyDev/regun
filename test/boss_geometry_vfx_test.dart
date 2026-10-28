import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/boss_vfx.dart';
import 'package:regun/presentation/regun_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<ui.Image> capture(void Function(Canvas) draw, {int size = 300}) async {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    c.clipRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    draw(c);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    picture.dispose();
    return image;
  }

  test(
    'annular arc leaves the safe pocket and outside sector untouched',
    () async {
      final image = await capture((c) {
        c.drawColor(const Color(0xff203020), BlendMode.src);
        const BossVfx(kind: BossKind.bellkeeper).fan(
          c,
          const Offset(150, 150),
          120,
          -.8,
          1.6,
          innerRadius: 55,
          warning: true,
          progress: .8,
        );
      });
      final bytes = (await image.toByteData())!;
      void unchanged(int x, int y) {
        final i = (y * 300 + x) * 4;
        expect(bytes.getUint8(i), 32);
        expect(bytes.getUint8(i + 1), 48);
        expect(bytes.getUint8(i + 2), 32);
      }

      for (var y = 120; y <= 180; y += 5) {
        for (var x = 120; x <= 180; x += 5) {
          unchanged(x, y);
        }
      }
      unchanged(70, 150);
      unchanged(150, 50);
      image.dispose();
    },
  );
  test(
    'moving wave remains visible during its final damaging frames',
    () async {
      Future<int> ink(double progress) async {
        final image = await capture(
          (c) => const BossVfx().wave(
            c,
            const Offset(150, 150),
            100,
            0,
            math.pi * 2,
            warning: false,
            progress: progress,
          ),
        );
        final bytes = (await image.toByteData())!;
        var count = 0;
        for (var i = 3; i < bytes.lengthInBytes; i += 4) {
          if (bytes.getUint8(i) > 80) count++;
        }
        image.dispose();
        return count;
      }

      expect(await ink(.999), greaterThan((await ink(.1)) * .7));
    },
  );
  test(
    'ring escape gap stays visually open and warning footprint stays planted',
    () async {
      Future<List<int>> alpha(double progress) async {
        final image = await capture(
          (c) => const BossVfx(kind: BossKind.bellkeeper).wave(
            c,
            const Offset(150, 150),
            100,
            .5,
            math.pi * 2 - 1,
            warning: true,
            progress: progress,
            width: 16,
          ),
        );
        final bytes = (await image.toByteData())!;
        final values = [
          for (var i = 3; i < bytes.lengthInBytes; i += 4) bytes.getUint8(i),
        ];
        image.dispose();
        return values;
      }

      final early = await alpha(0), late = await alpha(.99);
      for (var y = 140; y <= 160; y++) {
        for (var x = 240; x <= 260; x++) {
          expect(late[y * 300 + x], 0);
        }
      }
      expect(
        [for (var i = 0; i < early.length; i++) early[i] > 0],
        [for (var i = 0; i < late.length; i++) late[i] > 0],
      );
    },
  );
  test('export boss comparison on both arena floors', () async {
    await RegunArt.shared.load();
    for (final b in _legacyBosses) {
      await RegunArt.shared.acquire('bosses/${b.name}');
    }
    await (FontLoader('PressStart2P')
          ..addFont(rootBundle.load('assets/fonts/PressStart2P-Regular.ttf')))
        .load();
    for (final arena in ArenaType.values) {
      final recorder = ui.PictureRecorder(), c = Canvas(recorder);
      const cell = 340.0, rowHeight = 280.0;
      for (final b in _legacyBosses) {
        for (var col = 0; col < 4; col++) {
          c.save();
          c.translate(col * cell, b.index * rowHeight);
          c.clipRect(const Rect.fromLTWH(0, 0, cell, rowHeight));
          Sprite(RegunArt.shared.image('arenas/${arena.name}_floor'))
              .render(c, size: Vector2(cell, rowHeight));
          final warning = col.isEven, legacy = col < 2;
          final vfx = BossVfx(kind: b, ambient: BossArt.ambient(arena));
          c.save();
          c.translate(170, 165);
          c.scale(.44);
          final material = switch (b) {
            BossKind.shadow => AttackMaterial.shadow,
            BossKind.demon || BossKind.sovereign => AttackMaterial.ember,
            BossKind.queen => AttackMaterial.poison,
            BossKind.magistrate => AttackMaterial.chain,
            BossKind.saint => AttackMaterial.glass,
            _ => AttackMaterial.stone,
          };
          if (b == BossKind.demon ||
              b == BossKind.bellkeeper ||
              b == BossKind.sovereign) {
            (legacy ? AttackVfx.fan : vfx.fan)(
              c,
              Offset.zero,
              340,
              -2.8,
              2.5,
              innerRadius: b == BossKind.demon ? 0 : 130,
              warning: warning,
              progress: .65,
              material: material,
            );
            if (legacy) {
              AttackVfx.wave(
                c,
                Offset.zero,
                340,
                -2.8,
                2.5,
                warning: warning,
                progress: .65,
                material: material,
              );
            }
          } else if (b == BossKind.magistrate) {
            for (var i = 0; i < 5; i++) {
              final a = -2.7 + i * .5;
              (legacy ? AttackVfx.ribbon : vfx.ribbon)(
                c,
                Offset.zero,
                Offset(math.cos(a), math.sin(a)) * (310 + i * 16),
                20,
                warning: warning,
                progress: .4,
                material: material,
              );
            }
          } else if (b == BossKind.marshal) {
            AttackVfx.laser(
              c,
              Offset.zero,
              const Offset(320, -230),
              20,
              warning: warning,
              progress: .4,
            );
          } else {
            (legacy ? AttackVfx.disk : vfx.disk)(
              c,
              const Offset(65, -115),
              200,
              warning: warning,
              progress: .4,
              material: material,
              ambient: BossArt.ambient(arena),
            );
          }
          // The actual boss art, at the same scale as its attack geometry.
          RegunArt.shared
              .sprite('bosses/${b.name}', 0)
              .render(
                c,
                position: Vector2(-b.spriteSize / 2, -b.spriteSize * .82),
                size: Vector2.all(b.spriteSize),
              );
          c.restore();
          c.drawRect(
            const Rect.fromLTWH(0, 0, cell, 40),
            Paint()..color = const Color(0xdd131915),
          );
          final label = TextPainter(
            text: TextSpan(
              text:
                  '${b.title}\n${legacy ? "CURRENT" : "GEOMETRY"} / ${warning ? "WARNING" : "IMPACT"}',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 9,
                height: 1.5,
                color: Color(0xffCCC3AD),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: 330);
          label.paint(c, const Offset(8, 6));
          c.restore();
        }
      }
      final picture = recorder.endRecording(),
          image = await picture.toImage(1360, 2240);
      final arcRecorder = ui.PictureRecorder(), arcCanvas = Canvas(arcRecorder);
      for (var row = 0; row < 2; row++) {
        for (var col = 0; col < 2; col++) {
          arcCanvas.drawImageRect(
            image,
            Rect.fromLTWH(
              col * 680,
              (row == 0 ? 1 : 3) * rowHeight,
              cell,
              rowHeight,
            ),
            Rect.fromLTWH(col * cell, row * rowHeight, cell, rowHeight),
            Paint()..filterQuality = FilterQuality.none,
          );
        }
      }
      final arcPicture = arcRecorder.endRecording(),
          arcImage = await arcPicture.toImage(680, 560);
      final arcData = await arcImage.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/boss-arcs-${arena.name}.png')
          .writeAsBytes(arcData!.buffer.asUint8List());
      arcImage.dispose();
      arcPicture.dispose();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/boss-geometry-${arena.name}.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
    for (final b in _legacyBosses) {
      RegunArt.shared.release('bosses/${b.name}');
    }
  });
}

final _legacyBosses = BossKind.active
    .where((kind) => kind != BossKind.walker)
    .toList();
