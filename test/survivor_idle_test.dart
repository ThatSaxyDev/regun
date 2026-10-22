import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/widgets/survivor_portrait.dart';

void main() {
  testWidgets(
    'loadout idle moves rendered art and system Reduced Motion holds it still',
    (tester) async {
      await tester.runAsync(() async {
        await RegunArt.shared.load();
      });
      final previous = LocalPreferences.shared.reducedMotion;
      LocalPreferences.shared.reducedMotion = false;
      addTearDown(() {
        LocalPreferences.shared.reducedMotion = previous;
      });
      Future<List<int>> pixels() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('portrait')),
        );
        return await tester.runAsync(() async {
              final image = await boundary.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              image.dispose();
              return data!.buffer.asUint8List().toList();
            }) ??
            [];
      }

      Widget scene(bool still) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: const Center(
            child: RepaintBoundary(
              key: Key('portrait'),
              child: SizedBox(
                width: 220,
                height: 220,
                child: SurvivorPortrait(animated: true, maxArtSize: 180),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene(false));
      await tester.pump();
      final start = await pixels();
      await tester.pump(const Duration(milliseconds: 550));
      expect(await pixels(), isNot(orderedEquals(start)));
      await tester.pumpWidget(scene(true));
      await tester.pump();
      final resting = await pixels();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(await pixels(), orderedEquals(resting));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
