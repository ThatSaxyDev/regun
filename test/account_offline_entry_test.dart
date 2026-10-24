import 'package:regun/views/base_view.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:regun/game.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:regun/models/account/account_session.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/account/account_storage.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/services/online_availability.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/menu_view.dart';
import 'package:regun/views/settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Secrets implements AccountSecrets {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async {
    value = v;
  }
}

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String s) async {}
  @override
  Future<void> playMusic(String s) async {}
  @override
  void configure({required double music, required double sfx}) {}
}

const owner = '11111111-1111-4111-8111-111111111111';
AccountSession session(String id) => AccountSession(
  accountId: id,
  accessToken: 'signed.jwt.token',
  refreshToken: 'refresh',
  expiresAt: 4102444800,
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Home and local settings stay usable while account and online policy are unavailable',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await LocalPreferences.shared.load();
      final pending = Completer<http.Response>();
      int accountCalls = 0;
      final controller = AccountController(
        api: AccountApi(
          endpoint: Uri.parse('https://identity.example'),
          client: () => MockClient((_) async {
            accountCalls++;
            return pending.future;
          }),
        ),
        secrets: _Secrets(),
      );
      addTearDown(controller.dispose);
      await tester.pump();
      controller.session = session(owner);
      controller.account = {'username': 'rook_12'};
      final policy = OnlineAvailability(
        client: () =>
            MockClient((_) async => http.Response('unavailable', 503)),
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              accountProvider.overrideWithValue(controller),
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
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      for (var i = 0; i < 40 && find.text('PLAY').evaluate().isEmpty; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
      }

      expect(accountCalls, 1);
      expect(find.text('PLAY').hitTestable(), findsOneWidget);
      expect(find.text('TRAINING').hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SettingsView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('BACK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('PLAY'));
      await tester.pump();
      for (
        var i = 0;
        i < 20 && find.byType(RiverpodAwareGameWidget).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
      }
      expect(find.byType(RiverpodAwareGameWidget), findsOneWidget);
      final game =
          tester
                  .widget<RiverpodAwareGameWidget>(
                    find.byType(RiverpodAwareGameWidget),
                  )
                  .game!
              as RegunGame;
      var loaded = false;
      unawaited(
        game.loaded.then((_) {
          loaded = true;
        }),
      );
      for (var i = 0; i < 200 && !loaded; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
      }
      expect(loaded, isTrue);
      await tester.pump();
      expect(find.byType(BaseView), findsOneWidget);
      expect(accountCalls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      policy.dispose();
      pending.complete(http.Response('{}', 503));
    },
  );
}
