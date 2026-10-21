import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/views/flame_splash_view.dart';
import 'package:regun/views/menu_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Rook startup reaches Menu and removes its temporary route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await RegunArt.shared.load();
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!),
          home: const FlameSplashView())),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
    await tester.pumpAndSettle();
    expect(find.byType(MenuView), findsOneWidget);
    expect(find.byType(FlameSplashView), findsNothing);
    expect(
      Navigator.of(tester.element(find.byType(MenuView))).canPop(),
      isFalse,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
