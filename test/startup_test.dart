import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame_splash_screen/flame_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/views/flame_splash_view.dart';
import 'package:regun/views/menu_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> start(WidgetTester tester, {bool reduced = false}) async {
  SharedPreferences.setMockInitialValues({'settings.motion': reduced});
  tester.view.physicalSize = const Size(844, 390);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(() async {
    await RegunArt.shared.load();
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RepaintBoundary(
            key: Key('startup-capture'),
            child: FlameSplashView(),
          ),
        ),
      ),
    );
    await tester.pump();
    // Complete genuine asset/preference I/O before advancing the fake ticker.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  });
  await tester.pump();
}

Future<void> capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('startup-capture')),
    );
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('build/test-previews/startup-$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
    'Flame then godKiishi then Menu; startup route is replaced once',
    (tester) async {
      await start(tester);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(const Key('startup-flame')), findsOneWidget);
      expect(find.byType(MenuView), findsNothing);
      await capture(tester, 'flame');
      await tester.pump(const Duration(milliseconds: 2400));
      expect(find.byKey(const Key('startup-godkiishi')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      await capture(tester, 'godkiishi');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(MenuView), findsOneWidget);
      expect(find.byType(FlameSplashView), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(MenuView))).canPop(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Reduced Motion shows both still logos and reaches Menu', (
    tester,
  ) async {
    await start(tester, reduced: true);
    expect(find.byType(LogoComposite), findsNothing);
    expect(find.byType(AnimatedLogo), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byType(AnimatedLogo),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity,
      1,
    );
    await tester.pump(const Duration(milliseconds: 3300));
    expect(find.byKey(const Key('startup-godkiishi')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MenuView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'background freezes intro and resume continues the same sequence',
    (tester) async {
      await start(tester);
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(find.byKey(const Key('startup-flame')), findsOneWidget);
      expect(find.byType(MenuView), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2400));
      expect(find.byKey(const Key('startup-godkiishi')), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(MenuView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'disposing during intro cancels callbacks and cannot reopen Menu',
    (tester) async {
      await start(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const MaterialApp(home: Text('Another route')));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Another route'), findsOneWidget);
      expect(find.byType(MenuView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
