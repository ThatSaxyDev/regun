import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/views/settings_view.dart';

void main() {
  testWidgets('settings Back stays visible above scrolling content and returns',
      (tester) async {
    tester.view.physicalSize = const Size(667, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!),
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          const SettingsView(allowProgressReset: true))),
                  child: const Text('Open settings')))),
    )));
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    final initial = tester.getRect(find.text('BACK'));
    expect(initial.top, lessThan(70));
    expect(find.text('BACK').hitTestable(), findsOneWidget);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('BACK')), initial);
    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.byType(SettingsView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
