import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/collection_view.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
}

void main() {
  testWidgets(
    'shop finishes and earned goals render in the actual Collection',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        for (final family in ['PressStart2P', 'Orbitron']) {
          await (FontLoader(family)
                ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf')))
              .load();
        }
        await RegunArt.shared.load();
        await LocalPreferences.shared.load();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const RepaintBoundary(
              key: Key('capture'),
              child: CollectionView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('capture')),
              )
              .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/test-previews/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.tap(find.text('CHALLENGES'));
      await tester.pumpAndSettle();
      expect(find.text('FIELD RECORD'), findsOneWidget);
      await capture('economy-career');
      await tester.tap(find.text('STYLE'));
      await tester.pumpAndSettle();
      expect(find.text('FIELD FINISHES'), findsOneWidget);
      await capture('economy-shop');
      final scrollable = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.text('RUST'),
        250,
        scrollable: scrollable,
        maxScrolls: 30,
      );
      await tester.pumpAndSettle();
      expect(find.text('RUST'), findsOneWidget);
      await capture('economy-finishes');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
