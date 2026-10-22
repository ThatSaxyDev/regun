import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/widgets/home_menu.dart';
import 'package:regun/widgets/home_artwork.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
}

void main() {
  test(
    'shelter voltage has unequal brownouts, recovery and seamless looping',
    () {
      expect(ShelterVoltage.at(.5), lessThan(.2));
      expect(ShelterVoltage.at(2), greaterThan(.85));
      expect(ShelterVoltage.at(8.6), lessThan(.1));
      expect(ShelterVoltage.at(14), inInclusiveRange(.48, .7));
      expect(ShelterVoltage.at(24), ShelterVoltage.at(0));
      // Any five-second demo must include visible voltage variation, even
      // if the recording starts between the deeper brownouts.
      for (var start = 0; start < 240; start++) {
        final values = List.generate(
          51,
          (i) => ShelterVoltage.at((start + i) / 10),
        );
        final low = values.reduce((a, b) => a < b ? a : b);
        final high = values.reduce((a, b) => a > b ? a : b);
        expect(high - low, greaterThan(.35));
      }
      for (var step = 1; step <= 2400; step++) {
        final value = ShelterVoltage.at(step / 100);
        expect(value, inInclusiveRange(.08, .96));
        expect(
          (value - ShelterVoltage.at((step - 1) / 100)).abs(),
          lessThan(.08),
        );
      }
    },
  );

  testWidgets('five home actions and settings fit safe landscape edges', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PackageInfo.setMockInitialValues(
      appName: 'Regun',
      packageName: 'dev.kiishi.regun',
      version: '1.0.0',
      buildNumber: '8',
      buildSignature: '',
    );
    await tester.runAsync(() async {
      for (final font in [
        ('PressStart2P', 'PressStart2P-Regular.ttf'),
        ('Orbitron', 'Orbitron-Bold.ttf'),
      ]) {
        await (FontLoader(
          font.$1,
        )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
      }
    });
    var settings = 0;
    var continueCount = 0;
    var index = 0;
    for (final size in [
      const Size(568, 320),
      const Size(844, 390),
      const Size(1024, 768),
      const Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      for (final scale in [1.0, 1.5]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
            child: MaterialApp(
              key: ValueKey(index++),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 21),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: RepaintBoundary(
                  key: const Key('capture'),
                  child: HomeMenu(
                    ready: true,
                    reducedMotion: true,
                    onPlay: () {},
                    onOnline: () {},
                    onContinue: () => continueCount++,
                    onTraining: () {},
                    onCollection: () {},
                    onSettings: () => settings++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/art/arenas/home_hideout_v2.png'),
            tester.element(find.byType(HomeArtwork)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size / $scale');
        if (size.width > size.height && scale == 1) {
          for (final label in [
            'CONTINUE',
            'PLAY',
            'ONLINE',
            'TRAINING',
            'COLLECTION',
          ]) {
            expect(find.text(label).hitTestable(), findsOneWidget);
            final rect = tester.getRect(find.text(label));
            expect(rect.left, greaterThanOrEqualTo(24));
            expect(rect.bottom, lessThan(size.height - 21));
          }
          final title = tester.getRect(find.byKey(const Key('home-title')));
          expect(title.top, greaterThanOrEqualTo(16));
          expect(
            tester.getRect(find.byKey(const Key('home-settings'))).top,
            greaterThan(title.bottom),
          );
          await tester.tap(find.text('CONTINUE'));
        } else {
          await tester.scrollUntilVisible(
            find.byKey(const Key('home-settings')),
            120,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tester.tap(find.byKey(const Key('home-settings')));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        if (size == const Size(844, 390) && scale == 1) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/test-previews').create(recursive: true);
            await File('build/test-previews/home-redesign.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    }
    expect(settings, 8);
    expect(continueCount, 3);
  });

  testWidgets(
    'release Online stays gray and opens only coming soon; toggle restores play',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var online = 0;
      Widget home({double scale = 1}) => ProviderScope(
        overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
              key: const Key('online-preview'),
              child: child!,
            ),
          ),
          home: Scaffold(
            body: HomeMenu(
              ready: true,
              onlineAvailable: false,
              reducedMotion: true,
              onPlay: () {},
              onOnline: () => online++,
              onTraining: () {},
              onCollection: () {},
              onSettings: () {},
            ),
          ),
        ),
      );
      for (final size in [const Size(844, 390), const Size(568, 320)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(home(scale: size.width < 600 ? 1.5 : 1));
        await tester.pumpAndSettle();
        final label = tester.widget<Text>(find.text('ONLINE'));
        expect(label.style!.color, const Color(0xff99979c));
        await tester.tap(find.text('ONLINE'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(
          find.text('Co-op and versus are on the way. Stay tuned.'),
          findsOneWidget,
        );
        expect(online, 0);
        if (size.width == 844) {
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(
                  find.byKey(const Key('online-preview')),
                )
                .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('build/test-previews/online-coming-soon.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.text('GOT IT'));
        await tester.tap(find.text('GOT IT'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: MaterialApp(
            home: Scaffold(
              body: HomeMenu(
                ready: true,
                reducedMotion: true,
                onlineAvailable: true,
                onPlay: () {},
                onOnline: () => online++,
                onTraining: () {},
                onCollection: () {},
                onSettings: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ONLINE'));
      expect(online, 1);
      expect(find.text('CO-OP / VERSUS'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('animated home can switch to reduced motion and dispose', (
    tester,
  ) async {
    Widget home(bool reduced) => MaterialApp(
      home: Scaffold(
        body: HomeMenu(
          ready: false,
          reducedMotion: reduced,
          onPlay: () {},
          onOnline: () {},
          onTraining: () {},
          onCollection: () {},
          onSettings: () {},
        ),
      ),
    );
    await tester.pumpWidget(home(false));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('LOADING'), findsOneWidget);
    expect(find.text('CONTINUE'), findsNothing);
    await tester.pumpWidget(home(true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'brownout dims bulb and bench while reduced motion holds shelter steady',
    (tester) async {
      const capture = Key('lamp-capture');
      Widget scene(bool reduced) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 768,
              height: 512,
              child: RepaintBoundary(
                key: capture,
                child: HomeArtwork(reducedMotion: reduced),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene(false));
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/art/arenas/home_hideout_v2.png'),
          tester.element(find.byType(HomeArtwork)),
        );
      });
      await tester.pump();
      Future<List<int>> pixels() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        final image = await boundary.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final result = bytes!.buffer.asUint8List().toList();
        image.dispose();
        return result;
      }

      Future<void> save(String name) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('build/test-previews/shelter-$name.png')
            .create(recursive: true)
            .then((f) => f.writeAsBytes(bytes!.buffer.asUint8List()));
        image.dispose();
      }

      await tester.runAsync(() => save('bright'));
      final first = await tester.runAsync(pixels);
      await tester.pump(const Duration(milliseconds: 500));
      final second = await tester.runAsync(pixels);
      await tester.runAsync(() => save('brownout'));
      double difference(Rect region) {
        var sum = 0;
        var count = 0;
        for (var y = region.top.toInt(); y < region.bottom; y++) {
          for (var x = region.left.toInt(); x < region.right; x++) {
            for (var c = 0; c < 3; c++) {
              final offset = (y * 768 + x) * 4 + c;
              sum += (first![offset] - second![offset]).abs();
              count++;
            }
          }
        }
        return sum / count;
      }

      expect(
        difference(const Rect.fromLTWH(450, 165, 38, 22)),
        greaterThan(1),
        reason: 'The actual bulb must change, not just floating dust.',
      );
      expect(
        difference(const Rect.fromLTWH(450, 245, 60, 45)),
        greaterThan(.1),
        reason: 'The workbench must respond to the lamp.',
      );
      expect(
        difference(const Rect.fromLTWH(40, 230, 40, 30)),
        0,
        reason: 'The dark shelter outside the lamp pool stays steady.',
      );
      await tester.pump(const Duration(milliseconds: 2700));
      await tester.runAsync(() => save('sparks'));
      await tester.pumpWidget(scene(true));
      await tester.pumpAndSettle();
      await tester.runAsync(() => save('steady'));
      final still = await tester.runAsync(pixels);
      await tester.pump(const Duration(seconds: 2));
      expect(await tester.runAsync(pixels), still);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
