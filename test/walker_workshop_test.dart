import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/walker_art.dart';
import 'package:regun/systems/walker_rig.dart';
import 'package:regun/views/walker_workshop_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'capture battle stepping through a sharp turn without crossed stance',
    () async {
      final assets = WalkerAssets();
      await assets.load();
      final rig = WalkerRig(
        maxSpeed: 260,
        acceleration: 600,
        turnSpeed: 1.5,
        agileGait: true,
        bodyBounds: const Rect.fromLTRB(-3000, -3000, 3000, 3000),
        footBounds: const Rect.fromLTRB(-3200, -3200, 3200, 3200),
      );
      final rec = ui.PictureRecorder(), canvas = Canvas(rec);
      canvas.drawColor(const Color(0xff252b26), BlendMode.src);
      for (var panel = 0; panel < 8; panel++) {
        for (var step = 0; step < 48; step++) {
          final t = (panel * 48 + step) / 120;
          rig.desiredYaw = t < .8 ? 0 : math.pi * .85;
          rig.command = WalkerRig.rotate(const Offset(210, 60), rig.desiredYaw);
          rig.advance(1 / 120);
        }
        canvas.save();
        canvas.translate((panel % 4) * 500.0 + 250, (panel ~/ 4) * 440.0 + 270);
        canvas.translate(-rig.position.dx, -rig.position.dy);
        WalkerArt(assets).paint(canvas, rig);
        canvas.restore();
      }
      final pic = rec.endRecording(), im = await pic.toImage(2000, 880);
      final data = await im.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/walker-workshop').createSync(recursive: true);
      File('build/walker-workshop/battle-turn.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
      im.dispose();
      pic.dispose();
      assets.dispose();
    },
  );

  test(
    'workshop art stays sharp, bounded and disposed after route ownership',
    () async {
      final assets = WalkerAssets();
      await assets.load();
      expect(assets.parts!.width, 1774);
      expect(assets.decodedBytes, lessThan(12 * 1024 * 1024));
      expect(
        assets.decodedBytes + RegunArt.shared.decodedBytes,
        lessThan(32 * 1024 * 1024),
      );
      final audit = Directory('build/walker-workshop')
        ..createSync(recursive: true);
      File('${audit.path}/texture-budget.txt').writeAsStringSync(
        'Workshop-owned RGBA: ${assets.decodedBytes} bytes\n'
        'Shared cache RGBA: ${RegunArt.shared.decodedBytes} bytes\n'
        'Floors borrowed from shared cache. Not total device memory or performance.\n',
      );
      for (final rect in assets.rects.values) {
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(assets.parts!.width));
        expect(rect.bottom, lessThanOrEqualTo(assets.parts!.height));
      }
      assets.dispose();
      expect(assets.decodedBytes, 0);
      expect(
        RegunArt.shared.image('arenas/breach_floor').width,
        greaterThan(0),
      );
      final pending = WalkerAssets();
      final load = pending.load();
      pending.dispose();
      await load;
      expect(pending.decodedBytes, 0);
    },
  );

  test(
    'render the rig at phone scale on both floors and through all headings',
    () async {
      final assets = WalkerAssets();
      await assets.load();
      await RegunArt.shared.acquire('characters/rook');
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      for (var row = 0; row < 2; row++) {
        for (var col = 0; col < 4; col++) {
          final controller = WalkerWorkshopController();
          controller.choose(col == 3 ? WalkerDemo.brace : WalkerDemo.stand);
          controller.foundry = row == 1;
          controller.autoTarget = false;
          controller.rig.desiredYaw = col * math.pi / 2;
          controller.rig.target = const Offset(330, 60);
          for (var f = 0; f < 600; f++) {
            controller.advance(1 / 120);
          }
          canvas.save();
          canvas.translate(col * 844.0, row * 390.0);
          canvas.clipRect(const Rect.fromLTWH(0, 0, 844, 390));
          WalkerWorkshopPainter(
            controller,
            assets,
            rook: true,
          ).paint(canvas, const Size(844, 390));
          canvas.restore();
          controller.dispose();
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(3376, 780);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/walker-workshop')
        ..createSync(recursive: true);
      File('${dir.path}/rig-headings.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();

      if (Platform.environment['REGUN_WALKER_CAPTURE'] == '1') {
        for (final foundry in [false, true]) {
          final controller = WalkerWorkshopController()..foundry = foundry;
          final encoder = await Process.start('ffmpeg', [
            '-y',
            '-loglevel',
            'error',
            '-f',
            'image2pipe',
            '-framerate',
            '15',
            '-i',
            '-',
            '-an',
            '-c:v',
            'libx264',
            '-pix_fmt',
            'yuv420p',
            '-movflags',
            '+faststart',
            '${dir.path}/${foundry ? 'foundry' : 'breach'}.mp4',
          ]);
          final errors = encoder.stderr
              .transform(const SystemEncoding().decoder)
              .join();
          // Walk, strafe/reverse, turn, stand/track, brace, stand/recover.
          final modes = [
            WalkerDemo.walk,
            WalkerDemo.strafe,
            WalkerDemo.turn,
            WalkerDemo.stand,
            WalkerDemo.brace,
            WalkerDemo.stand,
          ];
          for (final mode in modes) {
            controller.choose(mode);
            for (var frame = 0; frame < 60; frame++) {
              for (var tick = 0; tick < 8; tick++) {
                controller.advance(1 / 120);
              }
              final rec = ui.PictureRecorder();
              WalkerWorkshopPainter(
                controller,
                assets,
                rook: true,
              ).paint(Canvas(rec), const Size(844, 390));
              final pic = rec.endRecording(), im = await pic.toImage(844, 390);
              final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
              encoder.stdin.add(bytes!.buffer.asUint8List());
              await encoder.stdin.flush();
              im.dispose();
              pic.dispose();
            }
          }
          await encoder.stdin.close();
          expect(await encoder.exitCode, 0, reason: await errors);
          controller.dispose();
        }
      }
      RegunArt.shared.release('characters/rook');
      assets.dispose();
    },
  );

  test(
    'inspection view preserves touch/world alignment while following the rig',
    () {
      final controller = WalkerWorkshopController()..inspect = true;
      controller.rig.position = const Offset(200, -20);
      const size = Size(844, 390), point = Offset(-70, 40);
      final screen =
          controller.viewOrigin(size) + point * controller.viewScale(size);
      expect(
        (controller.worldPoint(screen, size) - point).distance,
        lessThan(1e-8),
      );
      expect(
        (controller.worldPoint(const Offset(422, 195), size) -
                controller.rig.position)
            .distance,
        lessThan(1e-8),
      );
      controller.dispose();
    },
  );

  testWidgets(
    'workshop controls remain usable and background pauses animation',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: WalkerWorkshopView())),
      );
      for (
        var i = 0;
        i < 100 && find.text('ASSEMBLING').evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      expect(find.text('WALKER / 01'), findsOneWidget);
      expect(find.text('ASSEMBLING'), findsNothing);
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<WalkerWorkshopPainter>()
          .single;
      final controller = painter.controller;
      await tester.tap(find.text('STAND'));
      await tester.pump(const Duration(milliseconds: 300));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final frozen = controller.clock;
      await tester.pump(const Duration(seconds: 2));
      expect(controller.clock, frozen);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
