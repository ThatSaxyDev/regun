import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'render technical pose guide for full-body animation authoring',
    () async {
      if (const bool.fromEnvironment('REGUN_GAIT_GUIDE_MUMMY')) {
        await mummyGuide();
        return;
      }
      const profileOnly = bool.fromEnvironment('REGUN_GAIT_GUIDE_PROFILE');
      const leftOnly = bool.fromEnvironment('REGUN_GAIT_GUIDE_LEFT');
      const width = profileOnly ? 800 : 1600, height = profileOnly ? 400 : 800;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xffeeeeee), ui.BlendMode.src);
      final body = ui.Paint()
        ..color = const ui.Color(0xff555a60)
        ..strokeWidth = 12
        ..strokeCap = ui.StrokeCap.round;
      for (var row = 0; row < (profileOnly ? 1 : 4); row++) {
        for (var frame = 0; frame < 8; frame++) {
          canvas.save();
          canvas.translate(
            profileOnly ? (frame % 4) * 200.0 : frame * 200.0,
            profileOnly ? (frame ~/ 4) * 200.0 : row * 200.0,
          );
          final phase = frame * pi / 4 + (leftOnly ? pi / 2 : 0);
          final bob = -cos(phase * 2) * 2;
          final side = row == 0 || row == 2;
          final sign = row == 2 || leftOnly ? -1.0 : 1.0;
          final head = ui.Offset(100, 45 + bob);
          final hip = ui.Offset(100, 109 + bob);
          final facing = leftOnly
              ? const ui.Offset(-12, 0)
              : row == 0
              ? const ui.Offset(12, 0)
              : row == 2
              ? const ui.Offset(-12, 0)
              : row == 1
              ? const ui.Offset(0, 7)
              : const ui.Offset(0, -7);
          canvas.drawCircle(head, 19, body);
          canvas.drawCircle(
            head + facing,
            5,
            ui.Paint()..color = const ui.Color(0xff00aaaa),
          );
          canvas.drawLine(
            head + const ui.Offset(0, 16),
            hip,
            body..strokeWidth = 27,
          );
          canvas.drawLine(
            const ui.Offset(65, 170),
            const ui.Offset(140, 170),
            ui.Paint()
              ..color = const ui.Color(0xffbbbbbb)
              ..strokeWidth = 1,
          );
          for (final far in [true, false]) {
            final p = phase + (far ? pi : 0);
            final c = ui.Paint()
              ..color = far
                  ? const ui.Color(0xff2673b8)
                  : const ui.Color(0xffe68b27)
              ..strokeWidth = 11
              ..strokeCap = ui.StrokeCap.round;
            final h =
                hip + ui.Offset(side ? (far ? -2 : 2) : (far ? -9 : 9), 0);
            final ankle = ui.Offset(
              h.dx + (side ? sin(p) * 24 * sign : sin(p) * 2),
              165 - max(0, cos(p)) * 25,
            );
            final delta = ankle - h;
            final d = delta.distance.clamp(1.0, 64.99);
            final ang =
                atan2(delta.dy, delta.dx) +
                (side
                        ? -sign
                        : far
                        ? -1
                        : 1) *
                    acos((33 * 33 + d * d - 32 * 32) / (2 * 33 * d));
            final knee = side
                ? h + ui.Offset(cos(ang) * 33, sin(ang) * 33)
                : h + ui.Offset((ankle.dx - h.dx) * .5, (ankle.dy - h.dy) * .5);
            canvas.drawLine(h, knee, c);
            canvas.drawLine(knee, ankle, c);
            canvas.drawLine(
              ankle,
              ankle + ui.Offset(side ? 10 * sign : 0, side ? 0 : 4),
              c,
            );
          }
          canvas.drawLine(
            ui.Offset(92, 77 + bob),
            ui.Offset(82, 100 + bob),
            body..strokeWidth = 10,
          );
          canvas.drawLine(
            ui.Offset(110, 77 + bob),
            ui.Offset(122, 98 + bob),
            body,
          );
          canvas.restore();
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('art/source/gait-guides').create(recursive: true);
      await File(
        'art/source/gait-guides/${leftOnly
            ? 'left-profile-guide'
            : profileOnly
            ? 'profile-guide'
            : 'pose-guide'}.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    },
    skip: !const bool.fromEnvironment('REGUN_GAIT_GUIDE'),
  );
}

Future<void> mummyGuide() async {
  await (FontLoader(
    'Orbitron',
  )..addFont(rootBundle.load('assets/fonts/Orbitron-Regular.ttf'))).load();
  const ankles = [
    ui.Offset(171, 280),
    ui.Offset(149, 280),
    ui.Offset(128, 280),
    ui.Offset(105, 278),
    ui.Offset(77, 275),
    ui.Offset(97, 253),
    ui.Offset(130, 230),
    ui.Offset(159, 250),
  ];
  const knees = [
    ui.Offset(159, 224),
    ui.Offset(142, 225),
    ui.Offset(127, 225),
    ui.Offset(112, 224),
    ui.Offset(102, 222),
    ui.Offset(131, 213),
    ui.Offset(163, 204),
    ui.Offset(176, 214),
  ];
  const names = [
    'CONTACT',
    'DOWN',
    'PASSING',
    'UP',
    'OPPOSITE CONTACT',
    'DOWN',
    'PASSING',
    'UP',
  ];
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawColor(const ui.Color(0xffeeeeee), ui.BlendMode.src);
  for (var i = 0; i < 8; i++) {
    canvas.save();
    canvas.translate((i % 4) * 256.0, (i ~/ 4) * 320.0);
    final line = ui.Paint()
      ..color = const ui.Color(0xffb9b9b9)
      ..strokeWidth = 1;
    canvas.drawLine(const ui.Offset(30, 284), const ui.Offset(225, 284), line);
    for (final far in [true, false]) {
      final index = far ? (i + 4) % 8 : i;
      final paint = ui.Paint()
        ..color = (far
            ? const ui.Color(0xff2673b8)
            : const ui.Color(0xffe68b27))
        ..strokeWidth = 13
        ..strokeCap = ui.StrokeCap.round;
      canvas.drawLine(const ui.Offset(128, 166), knees[index], paint);
      canvas.drawLine(knees[index], ankles[index], paint);
      canvas.drawLine(
        ankles[index],
        ankles[index] + const ui.Offset(22, 0),
        paint..strokeWidth = 10,
      );
    }
    final body = ui.Paint()
      ..color = const ui.Color(0xff555a60)
      ..strokeWidth = 40
      ..strokeCap = ui.StrokeCap.round;
    canvas.drawLine(const ui.Offset(128, 166), const ui.Offset(134, 115), body);
    canvas.drawLine(
      const ui.Offset(134, 115),
      const ui.Offset(158, 85),
      body..strokeWidth = 48,
    );
    canvas.drawCircle(const ui.Offset(164, 65), 24, body);
    canvas.drawLine(
      const ui.Offset(133, 107),
      const ui.Offset(116, 160),
      body..strokeWidth = 17,
    );
    final paragraph =
        (ui.ParagraphBuilder(
                ui.ParagraphStyle(fontSize: 13, fontFamily: 'Orbitron'),
              )
              ..pushStyle(ui.TextStyle(color: const ui.Color(0xff202020)))
              ..addText('${i + 1}: ${names[i]}'))
            .build()
          ..layout(const ui.ParagraphConstraints(width: 240));
    canvas.drawParagraph(paragraph, const ui.Offset(12, 300));
    canvas.restore();
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(1024, 640);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await Directory('art/source/gait-guides').create(recursive: true);
  await File('art/source/gait-guides/mummy-eight-step-guide.png')
      .writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}
