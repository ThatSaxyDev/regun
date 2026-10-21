import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/services/app_updates.dart';
import 'package:regun/widgets/app_update_gate.dart';
import 'package:regun/utils/soloud_play.dart';

const optional = VersionCheckResult(
    requiresUpdate: true,
    isRequired: false,
    minVersion: '1.0.0',
    minBuild: 5,
    target: '1.0.0+5',
    storeUrl: 'https://apps.apple.com/app/id1234567890');
const requiredUpdate = VersionCheckResult(
    requiresUpdate: true,
    isRequired: true,
    minVersion: '1.0.0',
    minBuild: 5,
    target: '1.0.0+5',
    storeUrl: 'https://apps.apple.com/app/id1234567890');

class Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
}

class FakeUpdates extends AppUpdates {
  FakeUpdates() : super(apiKey: 'test', platform: TargetPlatform.iOS);
  VersionCheckResult result = optional;
  Completer<VersionCheckResult>? pending;
  bool fail = false, opened = false, snoozed = false;
  @override
  Future<VersionCheckResult> check() async {
    if (pending != null) return pending!.future;
    if (fail) throw StateError('offline');
    return result;
  }

  @override
  Future<bool> openStore(VersionCheckResult result) async => opened;
  @override
  Future<void> later(VersionCheckResult result) async {
    snoozed = true;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<PackageInfo> installed() async => PackageInfo(
      appName: 'Regun',
      packageName: 'dev.kiishi.regun',
      version: '1.0.0',
      buildNumber: '4');
  AppUpdates service(Map<String, dynamic> Function() response,
          {TargetPlatform platform = TargetPlatform.iOS,
          void Function(http.Request)? inspect}) =>
      AppUpdates(
          apiKey: 'test-project',
          platform: platform,
          version: installed,
          client: () => MockClient((request) async {
                inspect?.call(request);
                return http.Response(jsonEncode(response()), 200);
              }));
  Map<String, dynamic> policy({bool required = false, int build = 5}) => {
        'requiresUpdate': true,
        'isRequired': required,
        'minVersion': '1.0.0',
        'minBuild': build,
        'target': '1.0.0+$build',
        'storeUrl': 'https://apps.apple.com/app/id1234567890'
      };

  test('sends native version/build to Telling with project key; no SDK init',
      () async {
    final s = service(() => policy(), inspect: (request) {
      expect(request.url.path, '/api/v1/project/version-check');
      expect(request.url.queryParameters,
          {'platform': 'ios', 'version': '1.0.0', 'build': '4'});
      expect(request.headers['x-api-key'], 'test-project');
    });
    expect((await s.check()).minBuild, 5);
    expect(AppUpdates(apiKey: '').enabled, false);
  });
  test('optional snooze scopes build target; required ignores it', () async {
    var required = false, build = 5;
    final s = service(() => policy(required: required, build: build));
    await s.later(await s.check());
    expect((await s.check()).requiresUpdate, false);
    build = 6;
    expect((await s.check()).requiresUpdate, true);
    build = 5;
    required = true;
    expect((await s.check()).isRequired, true);
  });
  test('official TestFlight invitations open on iOS only', () async {
    Uri? opened;
    final s = AppUpdates(
        platform: TargetPlatform.iOS,
        open: (uri) async {
          opened = uri;
          return true;
        });
    const beta = VersionCheckResult(
        requiresUpdate: true,
        isRequired: true,
        storeUrl: 'https://testflight.apple.com/join/96knrEeD');
    expect(await s.openStore(beta), true);
    expect(opened.toString(), beta.storeUrl);
    expect(AppUpdates(platform: TargetPlatform.android).storeUri(beta.storeUrl),
        isNull);
    for (final url in [
      'http://testflight.apple.com/join/96knrEeD',
      'https://testflight.apple.com.evil.com/join/96knrEeD',
      'https://testflight.apple.com/other/96knrEeD',
      'https://testflight.apple.com/join/',
      'https://testflight.apple.com/join/abc'
    ]) {
      expect(s.storeUri(url), isNull);
    }
  });
  test('Firebase App Distribution tester links open on Android only',
      () async {
    const appId = '1:225712394437:android:a774f7de7e22d0abd0e0ac';
    const share = 'https://appdistribution.firebase.google.com/testerapps/'
        '$appId/releases/1ajb55gcj4t3o?utm_source=firebase-tools';
    const invite = 'https://appdistribution.firebase.dev/i/AbC123_x';
    final android = AppUpdates(platform: TargetPlatform.android);
    expect(android.storeUri(share), isNotNull);
    expect(android.storeUri(invite), isNotNull);
    expect(AppUpdates(platform: TargetPlatform.iOS).storeUri(share), isNull);
    for (final url in [
      'http://appdistribution.firebase.google.com/testerapps/$appId/releases/1ajb55gcj4t3o',
      'https://appdistribution.firebase.google.com.evil.com/testerapps/$appId/releases/1ajb55gcj4t3o',
      'https://user@appdistribution.firebase.google.com/testerapps/$appId/releases/1ajb55gcj4t3o',
      'https://appdistribution.firebase.google.com:8443/testerapps/$appId/releases/1ajb55gcj4t3o',
      'https://appdistribution.firebase.google.com/testerapps/1:1:android:other/releases/1ajb55gcj4t3o',
      'https://appdistribution.firebase.google.com/testerapps/$appId',
      'https://appdistribution.firebase.dev/i/abc',
      'https://appdistribution.firebase.dev/other/AbC123_x',
      'https://appdistribution.firebase.dev.evil.com/i/AbC123_x'
    ]) {
      expect(android.storeUri(url), isNull);
    }
  });
  test('current, invalid config, offline, malformed and store failures',
      () async {
    expect(
        (await service(() => {'requiresUpdate': false}).check()).requiresUpdate,
        false);
    await expectLater(
        service(() => {'requiresUpdate': true}).check(), throwsStateError);
    final invalidLink = await service(() =>
        {...policy(required: true), 'storeUrl': 'https://example.com'}).check();
    expect(invalidLink.isRequired, true);
    expect(
        await AppUpdates(platform: TargetPlatform.iOS).openStore(invalidLink),
        false);
    final missingLink =
        await service(() => {...policy(required: true), 'storeUrl': ''})
            .check();
    expect(missingLink.requiresUpdate, true);
    expect(missingLink.minBuild, 5);
    final offline = AppUpdates(
        apiKey: 'test',
        platform: TargetPlatform.iOS,
        version: installed,
        client: () => MockClient((_) async => http.Response('', 503)));
    await expectLater(offline.check(), throwsStateError);
    final s = AppUpdates(
        apiKey: 'test',
        platform: TargetPlatform.iOS,
        open: (_) async => throw StateError('unavailable'));
    expect(await s.openStore(optional), false);
    for (final url in [
      'javascript:alert(1)',
      'http://apps.apple.com/app/id123',
      'https://apps.apple.com.evil.com/app/id123',
      'https://user@apps.apple.com/app/id123'
    ]) {
      expect(s.storeUri(url), isNull);
    }
    final android = AppUpdates(platform: TargetPlatform.android);
    expect(
        android.storeUri(
            'https://play.google.com/store/apps/details?id=dev.kiishi.regun'),
        isNotNull);
    expect(
        android.storeUri(
            'https://play.google.com/store/apps/details?id=other.app'),
        isNull);
  });

  Widget shell(FakeUpdates service, {double scale = 1}) => ProviderScope(
          overrides: [
            appUpdatesProvider.overrideWithValue(service),
            soloudPlayProvider.overrideWithValue(Quiet())
          ],
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      padding: const EdgeInsets.fromLTRB(44, 0, 44, 21)),
                  child: child!),
              home: RepaintBoundary(
                  key: const Key('preview'),
                  child: AppUpdateGate(
                      child: Scaffold(
                          body: Center(
                              child: TextButton(
                                  onPressed: () {},
                                  child: const Text('PLAY'))))))));
  testWidgets('pending startup and resume checks allow taps through status',
      (tester) async {
    final service = FakeUpdates()..pending = Completer<VersionCheckResult>();
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [appUpdatesProvider.overrideWithValue(service)],
      child: MaterialApp(home: AppUpdateGate(child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: Center(child: TextButton(
            focusNode: focus,
            onPressed: () => taps++,
            child: const Text('PLAY'),
          )),
        ),
      ))),
    ));
    await tester.pump();
    Future<void> verifyPending() async {
      expect(find.text('Checking for updates…'), findsOneWidget);
      final status = tester.renderObject<RenderParagraph>(
          find.text('Checking for updates…'));
      expect(status.text.style!.decoration, TextDecoration.none);
      await tester.tap(find.text('PLAY'));
      await tester.tapAt(tester.getCenter(find.text('Checking for updates…')));
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      final excluded = tester.widget<ExcludeSemantics>(find.descendant(
        of: find.byType(AppUpdateGate), matching: find.byType(ExcludeSemantics),
      ).first);
      expect(excluded.excluding, isFalse);
    }
    await verifyPending();
    expect(taps, 2);
    service.pending!.complete(VersionCheckResult.noUpdateRequired);
    await tester.pumpAndSettle();
    service.pending = Completer<VersionCheckResult>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await verifyPending();
    expect(taps, 4);
    service.pending!.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Checking for updates…'), findsNothing);
    await tester.tap(find.text('PLAY'));
    expect(taps, 5);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'optional later; forced back blocked; failure preserves required gate; policy withdrawal unlocks',
      (tester) async {
    final s = FakeUpdates();
    await tester.pumpWidget(shell(s));
    await tester.pumpAndSettle();
    expect(find.text('NEW UPDATE'), findsOneWidget);
    await tester.tap(find.text('LATER'));
    await tester.pumpAndSettle();
    expect(s.snoozed, true);
    expect(find.text('NEW UPDATE'), findsNothing);
    s.result = requiredUpdate;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('UPDATE REQUIRED'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('UPDATE REQUIRED'), findsOneWidget);
    await tester.tap(find.text('UPDATE'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t open the store. Please try again.'),
        findsOneWidget);
    s.fail = true;
    await tester.tap(find.text('CHECK AGAIN'));
    await tester.pumpAndSettle();
    expect(find.text('UPDATE REQUIRED'), findsOneWidget);
    s.fail = false;
    s.result = VersionCheckResult.noUpdateRequired;
    await tester.tap(find.text('CHECK AGAIN'));
    await tester.pumpAndSettle();
    expect(find.text('UPDATE REQUIRED'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'required build policy stays blocking without a store URL and recovers when configured',
      (tester) async {
    final s = FakeUpdates()
      ..result = const VersionCheckResult(
          requiresUpdate: true,
          isRequired: true,
          minVersion: '1.0.0',
          minBuild: 5,
          target: '1.0.0+5',
          storeUrl: '');
    await tester.pumpWidget(shell(s));
    await tester.pumpAndSettle();
    expect(find.text('UPDATE REQUIRED'), findsOneWidget);
    expect(
        find.text(
            'The update link isn’t ready yet. Please check again shortly.'),
        findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('UPDATE REQUIRED'), findsOneWidget);
    await tester.tap(find.text('UPDATE'));
    await tester.pumpAndSettle();
    expect(
        find.text('Couldn’t open the store. Please try again.'), findsNothing);
    s.result = requiredUpdate;
    s.opened = true;
    await tester.tap(find.text('CHECK AGAIN'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'The update link isn’t ready yet. Please check again shortly.'),
        findsNothing);
    await tester.tap(find.text('UPDATE'));
    await tester.pumpAndSettle();
    expect(find.text('UPDATE REQUIRED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'TestFlight policy enables Update instead of link-unavailable message',
      (tester) async {
    final s = FakeUpdates()
      ..result = const VersionCheckResult(
          requiresUpdate: true,
          isRequired: true,
          minVersion: '1.0.0',
          minBuild: 5,
          storeUrl: 'https://testflight.apple.com/join/96knrEeD');
    await tester.pumpWidget(shell(s));
    await tester.pumpAndSettle();
    expect(find.text('UPDATE REQUIRED'), findsOneWidget);
    expect(
        find.text(
            'The update link isn’t ready yet. Please check again shortly.'),
        findsNothing);
    await tester.tap(find.text('UPDATE'));
    await tester.pumpAndSettle();
    // Fake opening fails: reaching this feedback proves the action was enabled.
    expect(find.text('Couldn’t open the store. Please try again.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('offline startup does not block play', (tester) async {
    final s = FakeUpdates()..fail = true;
    await tester.pumpWidget(shell(s));
    await tester.pumpAndSettle();
    expect(find.text('PLAY').hitTestable(), findsOneWidget);
    expect(find.byType(UpdateNotice), findsNothing);
  });
  testWidgets(
      'pixel update notice fits compact and Max landscape at enlarged text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final pair in [
        ('PressStart2P', 'PressStart2P-Regular.ttf'),
        ('Orbitron', 'Orbitron-Regular.ttf')
      ]) {
        await (FontLoader(pair.$1)
              ..addFont(rootBundle.load('assets/fonts/${pair.$2}')))
            .load();
      }
    });
    for (final size in [
      const Size(568, 320),
      const Size(844, 390),
      const Size(956, 440)
    ]) {
      tester.view.physicalSize = size;
      for (final scale in [1.0, 1.5]) {
        final s = FakeUpdates()..result = requiredUpdate;
        await tester.pumpWidget(shell(s, scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('UPDATE'));
        await tester.pumpAndSettle();
        expect(find.text('UPDATE').hitTestable(), findsOneWidget);
        if (size.width == 844 && scale == 1) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('preview')));
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('build/test-previews').create(recursive: true);
            await File('build/test-previews/update-required.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
