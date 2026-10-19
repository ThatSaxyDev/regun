import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/views/collection_view.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:regun/views/settings_view.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    for (final family in ['PressStart2P', 'Orbitron']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf')))
          .load();
    }
    SharedPreferences.setMockInitialValues({});
    await LocalPreferences.shared.load();
  });
  for (final size in [const Size(667, 375), const Size(1024, 768)]) {
    testWidgets('collection, loadout and settings fit $size with large text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capture = Key('capture');
      Future<void> show(Widget view) async {
        await tester.pumpWidget(ProviderScope(
            child: MaterialApp(
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.5)),
                    child: child!),
                home: RepaintBoundary(key: capture, child: view))));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      await show(const CollectionView());
      for (final tab in [
        'FUSIONS',
        'ENEMIES',
        'CHALLENGES',
        'STYLE',
        'CREDITS'
      ]) {
        await tester.ensureVisible(find.text(tab));
        await tester.tap(find.text(tab));
        await tester.pump();
        expect(tester.takeException(), isNull);
        if (tab == 'STYLE' && size.width == 667) {
          final boundary =
              tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('build/test-previews').create(recursive: true);
            await File('build/test-previews/collection-style.png')
                .writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      await show(const LoadoutView(training: true));
      expect(find.textContaining('Rook'), findsWidgets);
      await show(const SettingsView());
      if (size.width == 667) {
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/test-previews/settings-back.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
