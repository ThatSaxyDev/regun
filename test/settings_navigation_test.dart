import 'package:regun/utils/soloud_play.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/views/controls_view.dart';
import 'package:regun/views/menu_view.dart';
import 'package:regun/widgets/control_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/views/settings_view.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  void configure({required double music, required double sfx}) {}
}

void main() {
  testWidgets(
    'home settings opens persistent controls without starting a match',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        await LocalPreferences.shared.load();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: const MenuView(),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      for (var i = 0; i < 40 && find.text('PLAY').evaluate().isEmpty; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
      }
      expect(find.text('SETTINGS'), findsNothing);
      expect(find.byTooltip('Settings'), findsOneWidget);
      final settings = find.byKey(const Key('home-settings'));
      expect(tester.getRect(settings).right, lessThan(500));
      expect(tester.getRect(settings).top, greaterThan(200));
      expect(
        tester.getRect(find.text('TRAINING')).top -
            tester.getRect(find.text('PLAY')).bottom,
        greaterThan(28),
      );
      await tester.tap(settings);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTROLS'));
      await tester.pumpAndSettle();
      expect(find.byType(ControlsView), findsOneWidget);
      final slider = tester.widget<ControlSlider>(
        find.byWidgetPredicate(
          (w) => w is ControlSlider && w.label == 'Control size',
        ),
      );
      slider.onChanged(112);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('ARRANGE'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('ARRANGE'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('MOVE'), const Offset(30, -20));
      await tester.pumpAndSettle();
      expect(LocalPreferences.shared.controls.positions['move'], isNotNull);
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BACK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BACK'));
      await tester.pumpAndSettle();
      final reloaded = LocalPreferences();
      await reloaded.load();
      expect(reloaded.controls.size, 112);
      expect(reloaded.controls.positions['move'], isNotNull);
      expect(find.byType(MenuView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings Back stays visible above scrolling content and returns',
    (tester) async {
      tester.view.physicalSize = const Size(667, 375);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const SettingsView(allowProgressReset: true),
                    ),
                  ),
                  child: const Text('Open settings'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      final initial = tester.getRect(find.text('BACK'));
      expect(initial.top, lessThan(70));
      expect(find.text('BACK').hitTestable(), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('BACK')), initial);
      await tester.tap(find.text('BACK'));
      await tester.pumpAndSettle();
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.byType(SettingsView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
