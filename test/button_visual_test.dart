import 'dart:io';
import 'dart:ui' as ui;
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/widgets/home_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/menu_view.dart';
import 'package:regun/widgets/click_button.dart';

class _SilentAudio extends SoloudPlay {
  @override
  Future<void> play(String assetPath) async {}
}

void main() {
  testWidgets('menu buttons render at phone size and respond to touch',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const capture = Key('capture');
    await tester.runAsync(() async {
      final loader = FontLoader('PressStart2P')
        ..addFont(rootBundle.load('assets/fonts/PressStart2P-Regular.ttf'));
      await loader.load();
      await tester.pumpWidget(ProviderScope(
        overrides: [soloudPlayProvider.overrideWithValue(_SilentAudio())],
        child: MaterialApp(
            theme: ThemeData.dark(),
            home: const RepaintBoundary(key: capture, child: MenuView())),
      ));
      await RegunArt.shared.load();
      await tester.pump();
    });
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HomeArtwork), findsOneWidget);
    expect(tester.takeException(), isNull);
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/menu-buttons.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    // Check the common control's pressed/released activation without navigating.
    var taps = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [soloudPlayProvider.overrideWithValue(_SilentAudio())],
      child: MaterialApp(
          home: Scaffold(
              body: Center(
                  child: ClickButton(
        width: 120,
        height: 50,
        text: 'Restart',
        onTap: () => taps++,
      )))),
    ));
    await tester.tap(find.text('RESTART'));
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
