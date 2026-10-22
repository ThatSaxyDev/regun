import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/components.dart' show Vector2, Sprite;
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/presentation/marshal_aim.dart';
import 'package:regun/presentation/regun_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Marshal muzzle follows the barrel in eight directions and both facings',
    () {
      for (final left in [false, true]) {
        for (var i = 0; i < 8; i++) {
          final center = const Offset(45, 70), angle = i * math.pi / 4;
          final aim = center + Offset(math.cos(angle), math.sin(angle)) * 900;
          final grip = MarshalAim.grip(center, 340, left);
          final muzzle = MarshalAim.muzzle(center, aim, 340, left);
          expect((muzzle - grip).distance, closeTo(119, 1e-8));
          expect(MarshalAim.facingLeft(center, muzzle, aim, 340), left);
          final a = aim - grip, b = muzzle - grip;
          expect(a.dx * b.dy - a.dy * b.dx, closeTo(0, 1e-7));
          expect(a.dx * b.dx + a.dy * b.dy, greaterThan(0));
        }
      }
    },
  );
  test('render all area materials against both real arena floors', () async {
    await RegunArt.shared.load();
    await (FontLoader('PressStart2P')
          ..addFont(rootBundle.load('assets/fonts/PressStart2P-Regular.ttf')))
        .load();
    final recorder = ui.PictureRecorder(), c = Canvas(recorder);
    const materials = [
      AttackMaterial.stone,
      AttackMaterial.chain,
      AttackMaterial.ember,
      AttackMaterial.poison,
      AttackMaterial.glass,
      AttackMaterial.shadow,
    ];
    const size = 190.0;
    for (var row = 0; row < 4; row++) {
      final arena = row < 2 ? ArenaType.breach : ArenaType.foundry;
      final warning = row.isEven;
      for (var col = 0; col < materials.length; col++) {
        final x = col * size, y = row * size;
        Sprite(RegunArt.shared.image('arenas/${arena.name}_floor'))
            .render(c, position: Vector2(x, y), size: Vector2.all(size));
        AttackVfx.disk(
          c,
          Offset(x + size / 2, y + size / 2),
          76,
          warning: warning,
          progress: warning ? .55 : .25,
          material: materials[col],
          ambient: BossArt.ambient(arena),
        );
        final label = TextPainter(
          text: TextSpan(
            text:
                '${arena.name} ${warning ? "warn" : "hit"}\n${materials[col].name}',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 8,
              color: Color(0xffCCC3AD),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 180);
        label.paint(c, Offset(x + 5, y + 5));
      }
    }
    final picture = recorder.endRecording(),
        image = await picture.toImage(1140, 760);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/test-previews').create(recursive: true);
    await File('build/test-previews/grounded-area-materials.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });

  test('export Burster four-facing authored gait for motion review', () async {
    await RegunArt.shared.load();
    for (var phase = 0; phase < 4; phase++) {
      final recorder = ui.PictureRecorder(), c = Canvas(recorder);
      for (var facing = 0; facing < 4; facing++) {
        Sprite(RegunArt.shared.image('arenas/breach_floor')).render(
          c,
          position: Vector2(facing * 160.0, 0),
          size: Vector2.all(160),
        );
        c.drawOval(
          Rect.fromCenter(
            center: Offset(facing * 160 + 80, 137),
            width: 75,
            height: 13,
          ),
          Paint()..color = const Color(0x660D1315),
        );
        RegunArt.shared
            .sprite('enemies/burster_walk', facing * 4 + phase)
            .render(
              c,
              position: Vector2(facing * 160.0, 0),
              size: Vector2.all(160),
            );
      }
      final picture = recorder.endRecording(),
          image = await picture.toImage(640, 160);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/burster-walk-$phase.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  });

  test(
    'capture grounded warning, sweep, dash and angled laser presentations',
    () async {
      await RegunArt.shared.load();
      await RegunArt.shared.acquire('bosses/marshal');
      final recorder = ui.PictureRecorder(), c = Canvas(recorder);
      c.drawColor(const Color(0xff29292b), BlendMode.src);
      final ambient = BossArt.ambient(ArenaType.breach);
      AttackVfx.lungeWarning(
        c,
        const Offset(35, 55),
        const Offset(560, 55),
        progress: 0,
        ambient: ambient,
      );
      AttackVfx.lungeWarning(
        c,
        const Offset(35, 105),
        const Offset(560, 105),
        progress: .95,
        ambient: ambient,
      );
      AttackVfx.fan(
        c,
        const Offset(230, 365),
        190,
        -2.5,
        2.5,
        warning: true,
        progress: .5,
        innerRadius: 70,
      );
      AttackVfx.wave(
        c,
        const Offset(230, 365),
        190,
        -2.5,
        2.5,
        warning: true,
        progress: .5,
      );
      for (var i = 0; i < 4; i++) {
        AttackVfx.dashDust(
          c,
          Offset(370 + i * 48, 340),
          const Offset(1, 0),
          progress: i * .2,
          ambient: ambient,
        );
      }
      for (var i = 0; i < 6; i++) {
        final center = Offset(140 + (i % 3) * 290, 660 + (i ~/ 3) * 290);
        final angle = [-.7, 1.3, -2.1, .4, -1.6, 2.8][i];
        final aim = center + Offset(math.cos(angle), math.sin(angle)) * 230;
        final left = math.cos(angle) < 0;
        final muzzle = MarshalAim.muzzle(center, aim, 200, left);
        MarshalAim.paint(c, center, aim, 200, left: left, ambient: ambient);
        AttackVfx.laser(c, muzzle, aim, 9, warning: false, progress: .25);
      }
      final picture = recorder.endRecording(),
          im = await picture.toImage(920, 1130);
      final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/combat-readability.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      im.dispose();
      picture.dispose();
      RegunArt.shared.release('bosses/marshal');
    },
  );
}
