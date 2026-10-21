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

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
}

void main() {
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
      buildNumber: '7',
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
}
