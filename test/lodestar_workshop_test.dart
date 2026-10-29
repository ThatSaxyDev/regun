import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/presentation/lodestar_art.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/systems/lodestar/lodestar_rig.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';
import 'package:regun/views/lodestar_workshop_view.dart';
import 'package:regun/utils/constants.dart';

void main() {
  final dir = Directory('docs/validation/lodestar-foundation-2026-10-29');
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final entry in {
      FontFam.orbitron: 'assets/fonts/Orbitron-Regular.ttf',
      FontFam.pressStart: 'assets/fonts/PressStart2P-Regular.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  testWidgets(
    'new parts have alpha, aligned manifest, one bounded lease and pending disposal',
    (tester) async {
      await tester.runAsync(() async {
        final assets = LodestarAssets();
        await Future.wait([assets.load(), assets.load()]);
        expect(assets.ready, isTrue);
        expect(assets.decodedBytes, lessThan(3 * 1024 * 1024));
        expect(
          assets.decodedBytes + RegunArt.shared.decodedBytes,
          lessThanOrEqualTo(32 * 1024 * 1024),
        );
        dir.createSync(recursive: true);
        File('${dir.path}/art-budget.json').writeAsStringSync(
          jsonEncode({
            'ownedRgbaBytes': assets.decodedBytes,
            'sharedRgbaBytes': RegunArt.shared.decodedBytes,
            'combinedRgbaBytes':
                assets.decodedBytes + RegunArt.shared.decodedBytes,
            'limitRgbaBytes': 32 * 1024 * 1024,
            'scope': 'isolated carriage/rig workshop; full encounter not implemented',
          }),
        );
        expect(
          assets.rects.keys,
          containsAll(['carriage', 'spine', 'coupling', 'bogie', 'feeder']),
        );
        final data = await assets.sheet!.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final raw = data!.buffer.asUint8List();
        expect(raw[3], 0);
        var opaque = 0, transparent = 0;
        for (var i = 3; i < raw.length; i += 4) {
          if (raw[i] > 200) opaque++;
          if (raw[i] < 20) transparent++;
        }
        expect(opaque, greaterThan(70000));
        expect(transparent, greaterThan(200000));
        final meta = jsonDecode(
          await rootBundle.loadString(
            'assets/art/workshop/lodestar_parts_v01.json',
          ),
        ) as Map;
        expect(meta['geometry']['centerSpacing'], LodestarRig.spacing);
        expect(meta['geometry']['couplingSockets'], [
          [40.5, 0],
          [-40.5, 0],
        ]);
        final borrowed = assets.floors['breach']!;
        assets.dispose();
        expect(assets.decodedBytes, 0);
        expect(
          await borrowed.toByteData(),
          isNotNull,
        ); // not disposed by our lease
        final cancelled = LodestarAssets();
        final pending = cancelled.load();
        cancelled.dispose();
        await pending;
        expect(cancelled.ready, isFalse);
        expect(cancelled.decodedBytes, 0);
      });
    },
  );
  testWidgets(
    'two-floor carriage, permanent broken spine and full-rig pixel evidence',
    (tester) async {
      await tester.runAsync(() async {
        final assets = LodestarAssets();
        await assets.load();
        try {
          dir.createSync(recursive: true);
          Future<List<int>> render(
            String name,
            LodestarWorkshopController c,
          ) async {
            final recorder = ui.PictureRecorder();
            LodestarWorkshopPainter(
              c,
              assets,
            ).paint(Canvas(recorder), const Size(1500, 700));
            final picture = recorder.endRecording(),
                image = await picture.toImage(1500, 700);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            File('${dir.path}/$name.png')
                .writeAsBytesSync(png!.buffer.asUint8List());
            final rgba = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            image.dispose();
            picture.dispose();
            return rgba!.buffer.asUint8List();
          }

          final c = LodestarWorkshopController()
            ..close = true
            ..sockets = true
            ..loading = true;
          c.advance(.1);
          for (final floor in [false, true]) {
            c.foundry = floor;
            await render(floor ? 'carriage-foundry' : 'carriage-breach', c);
          }
          final loadA = await render('feeder-load-a', c);
          c.advance(.2);
          c.advance(.2);
          c.advance(.2);
          final loadB = await render('feeder-load-b', c);
          var changed = 0;
          for (var i = 0; i < loadA.length; i += 4) {
            if (loadA[i] != loadB[i] ||
                loadA[i + 1] != loadB[i + 1] ||
                loadA[i + 2] != loadB[i + 2]) {
              changed++;
              // Only the arm changes pixels; housing/chassis/floor stay planted.
              expect((i ~/ 4) % 1500, greaterThan(650));
            }
          }
          expect(changed, greaterThan(100));
          final stoppedAt = c.loadClock;
          for (var hit = 0; hit < 3; hit++) {
            c.hit();
          }
          expect(c.sections.living(LodestarSection.feeder), isFalse);
          c.advance(.1);
          expect(c.loadClock, stoppedAt);
          c.advance(.25);
          final brokenA = await render('feeder-broken', c);
          c.advance(.2);
          final brokenB = await render('feeder-broken-held', c);
          expect(listEquals(brokenA, brokenB), isTrue);
          c.choose(LodestarStudy.orbit);
          c.close = false;
          c.foundry = false;
          for (var i = 0; i < 120 * 4; i++) {
            c.advance(1 / 120);
          }
          await render('bare-rig-breach', c);
          c.reducedMotion = true;
          await render('bare-rig-reduced', c);
          c.dispose();
        } finally {
          assets.dispose();
        }
      });
    },
  );
  testWidgets(
    'phone pause, active loading, single step, background and restart isolate ownership',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const key = ValueKey('phone-capture');
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RepaintBoundary(key: key, child: LodestarWorkshopView()),
          ),
        ),
      );
      for (
        var i = 0;
        i < 160 && find.text('ASSEMBLING').evaluate().isNotEmpty;
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
          .whereType<LodestarWorkshopPainter>()
          .single;
      final c = painter.controller;
      await tester.tap(find.text('LOAD'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('PAUSE'));
      await tester.pump();
      final clock = c.clock, load = c.loadClock;
      await tester.pump(const Duration(seconds: 2));
      expect(c.clock, clock);
      expect(c.loadClock, load);
      await tester.tap(find.text('STEP'));
      await tester.pump();
      expect(c.clock, closeTo(clock + 1 / 60, 1e-8));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final frozen = c.clock;
      await tester.tap(find.text('STEP'));
      await tester.pump(const Duration(seconds: 1));
      expect(c.clock, frozen);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.runAsync(() async {
        dir.createSync(recursive: true);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/phone-workshop.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.text('RESTART'));
      await tester.pump();
      expect(c.clock, 0);
      expect(c.sections.total, 240);
      await tester.pumpWidget(const SizedBox());
      expect(painter.assets.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('large text and early disposal leave no error or late atlas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(667, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.8),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: const LodestarWorkshopView(),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
