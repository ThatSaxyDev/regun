import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/navigation/game_page_route.dart';
import 'package:regun/services/local_preferences.dart';

void main() {
  tearDown(() => LocalPreferences.shared.reducedMotion = false);
  testWidgets(
    'screen changes stay planted, fade through charcoal and retain route results',
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(pageTransitionsTheme: gamePageTransitionsTheme),
          navigatorKey: nav,
          home: const Scaffold(body: Center(child: Text('Home'))),
        ),
      );
      final route = GamePageRoute<String>(
        builder: (_) => const Scaffold(
          body: Center(child: Text('Destination', key: Key('destination'))),
        ),
      );
      final result = nav.currentState!.push(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final point = tester.getCenter(find.byKey(const Key('destination')));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getCenter(find.byKey(const Key('destination'))), point);
      expect(find.byType(SlideTransition), findsNothing);
      final scrim = tester.widget<ColoredBox>(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == GameScreenTransition.surface,
        ),
      );
      expect(scrim.color, GameScreenTransition.surface);
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getCenter(find.byKey(const Key('destination'))), point);
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(2, 250), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Destination'), findsOneWidget);
      nav.currentState!.pop('done');
      await tester.pumpAndSettle();
      expect(await result, 'done');
      expect(find.text('Home'), findsOneWidget);
      expect(route.transitionDuration, GameScreenTransition.enter);
      expect(route.reverseTransitionDuration, GameScreenTransition.leave);
    },
  );
  for (final deviceSetting in [false, true]) {
    testWidgets(
      'reduced motion cuts directly to the screen (${deviceSetting ? 'system' : 'game'})',
      (tester) async {
        LocalPreferences.shared.reducedMotion = !deviceSetting;
        final nav = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(pageTransitionsTheme: gamePageTransitionsTheme),
            navigatorKey: nav,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: deviceSetting),
              child: child!,
            ),
            home: const Scaffold(body: Text('Home')),
          ),
        );
        nav.currentState!.push(
          GamePageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Destination')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.text('Destination'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == GameScreenTransition.surface,
          ),
          findsNothing,
        );
        await tester.pumpAndSettle();
        nav.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
      },
    );
  }
}
