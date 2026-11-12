import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/services/push/push_router.dart';

void main() {
  testWidgets('a cold-start notification waits for Home before routing', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final router = PushRouter(
      key,
      (route) => const Scaffold(body: Text('Collection destination')),
    )..waitForHome();

    router.handle({'route': 'collection'});
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        home: const Scaffold(body: Text('Home')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Collection destination'), findsNothing);

    router.flush();
    await tester.pumpAndSettle();
    expect(find.text('Collection destination'), findsOneWidget);
  });

  testWidgets('a notification tap leaves an active match route in place', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final router = PushRouter(
      key,
      (route) => const Scaffold(body: Text('Push destination')),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        home: const Scaffold(body: Text('Home')),
      ),
    );
    key.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Active match')),
      ),
    );
    await tester.pumpAndSettle();

    router.handle({'route': 'leaderboards'});
    await tester.pumpAndSettle();
    expect(find.text('Active match'), findsOneWidget);
    expect(find.text('Push destination'), findsNothing);
  });
}
