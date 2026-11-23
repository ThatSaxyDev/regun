import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/services/app_updates.dart';
import 'package:regun/services/online_availability.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/menu_view.dart';

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
    'Home distinguishes online checks, connection failures and a server disable',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<http.Response>();
      Future<http.Response> Function() respond = () => pending.future;
      final policy = OnlineAvailability(
        client: () => MockClient((_) => respond()),
      );
      addTearDown(policy.dispose);
      await tester.runAsync(() async {
        await LocalPreferences.shared.load();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onlineAvailabilityProvider.overrideWithValue(policy),
              appUpdatesProvider.overrideWithValue(
                AppUpdates(platform: TargetPlatform.linux, web: false),
              ),
              soloudPlayProvider.overrideWithValue(_Quiet()),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: const MenuView(),
            ),
          ),
        );
        for (
          var attempt = 0;
          attempt < 100 && find.text('ARENA').evaluate().isEmpty;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('ARENA').hitTestable(), findsOneWidget);
      expect(find.text('CHECKING…'), findsOneWidget);
      await tester.runAsync(() async {
        pending.complete(
          http.Response('{"schemaVersion":1,"onlinePlay":true}', 200),
        );
        await policy.refresh();
      });
      await tester.pumpAndSettle();
      expect(find.text('CO-OP / VERSUS'), findsOneWidget);

      respond = () async =>
          http.Response('{"schemaVersion":1,"onlinePlay":false}', 200);
      await tester.runAsync(policy.refresh);
      await tester.pumpAndSettle();
      expect(policy.state, OnlineAvailabilityState.disabled);
      expect(find.text('COMING SOON'), findsOneWidget);
      await tester.tap(find.text('ONLINE'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('ARENA'), findsOneWidget);
      await tester.tap(find.text('GOT IT'));
      await tester.pumpAndSettle();
      respond = () async => http.Response('Service unavailable', 503);
      await tester.runAsync(policy.refresh);
      await tester.pumpAndSettle();
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('COMING SOON'), findsNothing);

      late Completer<http.Response> retry;
      respond = () => (retry = Completer<http.Response>()).future;
      await tester.tap(find.text('ONLINE'));
      await tester.pump();
      expect(find.text('CHECKING…'), findsOneWidget);
      expect(find.text('ARENA').hitTestable(), findsOneWidget);
      retry.complete(http.Response('Service unavailable', 503));
      await tester.pumpAndSettle();
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
