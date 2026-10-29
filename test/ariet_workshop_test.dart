import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/ariet_art.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/views/ariet_workshop_view.dart';

Future<void> save(
  ui.Picture picture,
  String path,
  int width,
  int height,
) async {
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = Directory('build/ariet-workshop');
  setUpAll(() async {
    for (final entry in {
      'PressStart2P': 'assets/fonts/PressStart2P-Regular.ttf',
      'Orbitron': 'assets/fonts/Orbitron-Regular.ttf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load(entry.value));
      await loader.load();
    }
  });
  test('single-flight route assets fit combined budget and cancel pending loads', () async {
    dir.createSync(recursive: true);
    final assets = ArietAssets();
    final first = assets.load();
    expect(identical(first, assets.load()), isTrue);
    await first;
    await RegunArt.shared.acquire('characters/rook');
    addTearDown(() => RegunArt.shared.release('characters/rook'));
    expect(assets.ready, isTrue);
    expect(assets.parts!.width, 1024);
    expect(
      assets.decodedBytes + RegunArt.shared.decodedBytes,
      lessThan(32 * 1024 * 1024),
    );
    File('${dir.path}/texture-budget.txt').writeAsStringSync(
      'Ariet + ONE shared Walker study atlas: ${assets.decodedBytes} RGBA bytes\n'
      'Shared world cache INCLUDING leased Rook: ${RegunArt.shared.decodedBytes} RGBA bytes\n'
      'Combined: ${assets.decodedBytes + RegunArt.shared.decodedBytes} bytes; envelope 33554432 bytes\n'
      'Floors borrowed. Not process/GPU usage or physical-device performance proof.\n',
    );
    for (final r in assets.rects.values) {
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(assets.parts!.width));
      expect(r.bottom, lessThanOrEqualTo(assets.parts!.height));
    }
    final floor = assets.floors['breach'];
    assets.dispose();
    assets.dispose();
    expect(assets.ready, isFalse);
    expect(assets.decodedBytes, 0);
    expect(floor!.width, greaterThan(0));
    final pending = ArietAssets();
    final load = pending.load();
    pending.dispose();
    await load;
    expect(pending.decodedBytes, 0);
    expect(pending.rects, isEmpty);
    expect(pending.walker.parts, isNull);
    final cancelled = ArietAssets()..dispose();
    await cancelled.load();
    expect(cancelled.decodedBytes, 0);
  });
  test(
    'render eight headings, carrier cutaway and real Walker scale comparisons',
    timeout: const Timeout(Duration(minutes: 3)),
    () async {
      dir.createSync(recursive: true);
      final assets = ArietAssets();
      await assets.load();
      await RegunArt.shared.acquire('characters/rook');
      try {
        for (final foundry in [false, true]) {
          final rec = ui.PictureRecorder(), canvas = Canvas(rec);
          for (var i = 0; i < 8; i++) {
            final c = ArietWorkshopController()..foundry = foundry;
            c.rig.yaw = i * math.pi / 4;
            c.rig.desiredYaw = c.rig.yaw;
            c.rig.cannonYaw = c.rig.yaw + math.pi / 2;
            canvas.save();
            canvas.translate((i % 4) * 844.0, (i ~/ 4) * 390.0);
            canvas.clipRect(const Rect.fromLTWH(0, 0, 844, 390));
            ArietWorkshopPainter(
              c,
              assets,
              rook: true,
            ).paint(canvas, const Size(844, 390));
            canvas.restore();
            c.dispose();
          }
          await save(
            rec.endRecording(),
            '${dir.path}/${foundry ? 'foundry' : 'breach'}-headings.png',
            3376,
            780,
          );
        }
        for (final mode in [ArietDemo.cargo, ArietDemo.scale]) {
          final c = ArietWorkshopController()..choose(mode);
          final rec = ui.PictureRecorder();
          ArietWorkshopPainter(
            c,
            assets,
            rook: true,
          ).paint(Canvas(rec), const Size(1200, 560));
          await save(
            rec.endRecording(),
            '${dir.path}/${mode.name}.png',
            1200,
            560,
          );
          c.dispose();
        }
        if (Platform.environment['REGUN_ARIET_CAPTURE'] == '1') {
          for (final foundry in [false, true]) {
            final c = ArietWorkshopController()..foundry = foundry;
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
            for (final mode in [
              ArietDemo.hover,
              ArietDemo.accelerate,
              ArietDemo.strafe,
              ArietDemo.turn,
            ]) {
              c.choose(mode);
              for (
                var frame = 0;
                frame < (mode == ArietDemo.hover ? 30 : 150);
                frame++
              ) {
                c.advance(1 / 15);
                final rec = ui.PictureRecorder();
                ArietWorkshopPainter(
                  c,
                  assets,
                  rook: true,
                ).paint(Canvas(rec), const Size(844, 390));
                final pic = rec.endRecording(),
                    im = await pic.toImage(844, 390);
                final bytes = await im.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                encoder.stdin.add(bytes!.buffer.asUint8List());
                await encoder.stdin.flush();
                im.dispose();
                pic.dispose();
              }
            }
            await encoder.stdin.close();
            expect(await encoder.exitCode, 0, reason: await errors);
            c.dispose();
          }
        }
      } finally {
        assets.dispose();
        RegunArt.shared.release('characters/rook');
      }
    },
  );
  testWidgets(
    'phone controls, single step and lifecycle work without production navigation',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capture = ValueKey('capture');
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RepaintBoundary(key: capture, child: ArietWorkshopView()),
          ),
        ),
      );
      for (
        var i = 0;
        i < 150 && find.text('ASSEMBLING').evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.text('ASSEMBLING'), findsNothing);
      expect(tester.takeException(), isNull);
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<ArietWorkshopPainter>()
          .single;
      final c = painter.controller;
      await tester.tap(find.text('ACCELERATE'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('PAUSE'));
      await tester.pump();
      final clock = c.rig.elapsed;
      await tester.pump(const Duration(seconds: 2));
      expect(c.rig.elapsed, clock);
      await tester.tap(find.text('STEP'));
      await tester.pump();
      expect(c.rig.elapsed, closeTo(clock + 1 / 60, 1e-8));
      await tester.tap(find.text('RESUME'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final frozen = c.rig.elapsed;
      await tester.pump(const Duration(seconds: 3));
      expect(c.rig.elapsed, frozen);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 16));
      expect(c.rig.elapsed, frozen);
      await tester.tap(find.text('HOVER'));
      await tester.pump();
      dir.createSync(recursive: true);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/phone-workshop.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.text('CARGO'));
      await tester.pump();
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/phone-cargo.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      expect(painter.assets.disposed, isTrue);
      expect(painter.assets.decodedBytes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'large text stays usable and early route disposal cancels ownership',
    (tester) async {
      tester.view.physicalSize = const Size(667, 375);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const ArietWorkshopView(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
