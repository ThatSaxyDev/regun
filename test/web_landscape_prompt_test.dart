import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/desktop/web_landscape_prompt.dart';

void main() {
  testWidgets('portrait blocks the game and widening restores the same route', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(620, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => WebLandscapePrompt(child: child!),
        home: const Scaffold(body: Text('Home')),
      ),
    );
    final prompt = find.text('LANDSCAPE REQUIRED');
    expect(prompt, findsOneWidget);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Settings')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsNothing);
    expect(find.text('Settings'), findsNothing);

    tester.view.physicalSize = const Size(960, 540);
    await tester.pumpAndSettle();
    expect(prompt, findsNothing);
    expect(find.text('Settings'), findsOneWidget);

    tester.view.physicalSize = const Size(620, 620);
    await tester.pumpAndSettle();
    expect(prompt, findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });
}
