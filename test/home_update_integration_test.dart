import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/services/app_updates.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/services/online_availability.dart';
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

class _Updates extends AppUpdates {
  _Updates() : super(apiKey: 'test', platform: TargetPlatform.iOS);
  int checks = 0;
  bool required = true;
  @override
  Future<VersionCheckResult> check() async {
    checks++;
    return required
        ? const VersionCheckResult(
            requiresUpdate: true,
            isRequired: true,
            minVersion: '1.0.0',
            minBuild: 18,
            target: '1.0.0+18',
            storeUrl: 'https://testflight.apple.com/join/96knrEeD',
          )
        : VersionCheckResult.noUpdateRequired;
  }
}

void main() {
  testWidgets('real Home presents required policy and rechecks on resume', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final updates = _Updates();
    final policy = OnlineAvailability(
      client: () => MockClient(
        (_) async =>
            http.Response('{"schemaVersion":1,"onlinePlay":false}', 200),
      ),
    );
    addTearDown(policy.dispose);
    await tester.runAsync(() async {
      await LocalPreferences.shared.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUpdatesProvider.overrideWithValue(updates),
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
    expect(updates.checks, 1);
    expect(find.text('UPDATE REQUIRED'), findsOneWidget);
    expect(find.text('PLAY').hitTestable(), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('UPDATE REQUIRED'), findsOneWidget);
    updates.required = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(updates.checks, 2);
    expect(find.text('UPDATE REQUIRED'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
