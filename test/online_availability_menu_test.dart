import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    'pending policy leaves solo usable and remote off updates the same Home',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var pending = Completer<http.Response>();
      final policy = OnlineAvailability(
        client: () => MockClient((_) => pending.future),
      );
      addTearDown(policy.dispose);
      await tester.runAsync(() async {
        await LocalPreferences.shared.load();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onlineAvailabilityProvider.overrideWithValue(policy),
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
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(find.text('PLAY').hitTestable(), findsOneWidget);
      expect(find.text('CHECKING…'), findsOneWidget);
      await tester.runAsync(() async {
        pending.complete(http.Response('{"schemaVersion":1,"onlinePlay":true}', 200));
        await policy.refresh();
      });
      await tester.pumpAndSettle();
      expect(find.text('CO-OP / VERSUS'), findsOneWidget);
      pending = Completer<http.Response>();
      await tester.runAsync(() async {
        final recheck = policy.refresh();
        pending.complete(http.Response('{"schemaVersion":1,"onlinePlay":false}', 200));
        await recheck;
      });
      await tester.pumpAndSettle();
      expect(find.text('COMING SOON'), findsOneWidget);
      await tester.tap(find.text('ONLINE'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('PLAY'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
