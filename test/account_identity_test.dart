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
import 'package:regun/models/account/account_session.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/account/account_storage.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/widgets/account_flow.dart';
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
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final font in ['PressStart2P', 'Orbitron']) {
      await (FontLoader(
        font,
      )..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf'))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('local boot and saves do not perform account verification; dirty owner snapshot survives restart', () async {
    final dir = await Directory.systemTemp.createTemp('regun-account-test');
    addTearDown(() => dir.delete(recursive: true));
    final prefs = LocalPreferences();
    await prefs.load();
    int requests = 0;
    final secrets = _Secrets()..value = jsonEncode(session(owner).toJson());
    final api = AccountApi(
      endpoint: Uri.parse('https://identity.example'),
      client: () => MockClient((_) async {
        requests++;
        throw const SocketException('offline');
      }),
    );
    final account = AccountController(
      api: api,
      secrets: secrets,
      store: AccountLocalStore(directory: dir),
      preferences: prefs,
    );
    addTearDown(account.dispose);
    await account.initialize();
    expect(requests, 0);
    await prefs.activateProfile(
      owner,
      initial: PlayerProfile(scrap: 45, totalKills: 120),
    );
    await account.sync();
    expect(prefs.profile.scrap, 45);
    expect(prefs.profile.totalKills, 120);
    final stored = await AccountLocalStore(directory: dir).read(owner);
    expect(stored!['pending'], true);
    expect(stored['profile']['scrap'], 45);
    // Preferences can lag an atomic profile/outbox write: startup recovers the latter.
    await SharedPreferences.getInstance().then(
      (p) => p.remove('profile.account.$owner'),
    );
    final restored = LocalPreferences();
    await restored.load();
    final second = AccountController(
      api: api,
      secrets: secrets,
      store: AccountLocalStore(directory: dir),
      preferences: restored,
    );
    addTearDown(second.dispose);
    final before = requests;
    await second.initialize();
    expect(requests, before);
    expect(restored.profile.scrap, 45);
  });
  test('fresh device restores cloud; meaningful guest conflict is explicit and leaves guest intact', () async {
    final dir = await Directory.systemTemp.createTemp('regun-cloud-test');
    addTearDown(() => dir.delete(recursive: true));
    final prefs = LocalPreferences();
    await prefs.load();
    prefs.profile.scrap = 25;
    await prefs.saveProfile();
    final account = AccountController(
      secrets: _Secrets(),
      store: AccountLocalStore(directory: dir),
      preferences: prefs,
    );
    addTearDown(account.dispose);
    await account.initialize();
    account.session = session(owner);
    account.account = {
      'accountId': owner,
      'username': 'rook_12',
      'cloud': {
        'revision': '3',
        'epoch': '0',
        'payload': PlayerProfile(scrap: 100, totalKills: 900).toJson(),
      },
    };
    await account.attach();
    expect(account.conflict, true);
    expect(prefs.profileOwner, 'guest');
    expect(prefs.profile.scrap, 25);
    await account.attach(useCloud: true);
    expect(prefs.profileOwner, owner);
    expect(prefs.profile.scrap, 100);
    await prefs.activateProfile('guest');
    expect(prefs.profile.scrap, 25);
  });
  test('changing account never imports another account inventory', () async {
    final dir = await Directory.systemTemp.createTemp(
      'regun-account-isolation',
    );
    addTearDown(() => dir.delete(recursive: true));
    final prefs = LocalPreferences();
    await prefs.load();
    await prefs.activateProfile(
      owner,
      initial: PlayerProfile(scrap: 77, totalKills: 400),
    );
    final account = AccountController(
      secrets: _Secrets(),
      store: AccountLocalStore(directory: dir),
      preferences: prefs,
    );
    addTearDown(account.dispose);
    await account.initialize();
    const other = '22222222-2222-4222-8222-222222222222';
    account.session = session(other);
    account.account = {
      'accountId': other,
      'username': 'another_rook',
      'cloud': null,
    };
    await account.attach();
    expect(prefs.profileOwner, other);
    expect(prefs.profile.scrap, 0);
    await prefs.activateProfile(owner);
    expect(prefs.profile.scrap, 77);
  });
  test('offline sign-out waits for an active local run and preserves its pending progress', () async {
    final dir = await Directory.systemTemp.createTemp('regun-offline-signout');
    addTearDown(() => dir.delete(recursive: true));
    final prefs = LocalPreferences();
    await prefs.load();
    prefs.profile.scrap = 25;
    await prefs.saveProfile();
    await prefs.activateProfile(owner, initial: PlayerProfile(scrap: 50));
    final secrets = _Secrets();
    final account = AccountController(
      api: AccountApi(
        endpoint: Uri.parse('https://identity.example'),
        client: () =>
            MockClient((_) async => throw const SocketException('offline')),
      ),
      secrets: secrets,
      store: AccountLocalStore(directory: dir),
      preferences: prefs,
    );
    addTearDown(account.dispose);
    await account.initialize();
    account.session = session(owner);
    account.account = {'username': 'rook_12'};
    await account.beginLocalPlay();
    final logout = account.signOut();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(prefs.profileOwner, owner);
    prefs.profile.scrap = 60;
    await prefs.saveProfile();
    account.endLocalPlay();
    await logout;
    expect(prefs.profileOwner, 'guest');
    expect(prefs.profile.scrap, 25);
    final stored = await AccountLocalStore(directory: dir).read(owner);
    expect(stored!['profile']['scrap'], 60);
    expect(stored['pending'], true);
    expect((jsonDecode(secrets.value!) as Map)['revocations'], isNotEmpty);
  });

  testWidgets(
    'email flow remains dismissible during a hung send at phone and large text sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final pending = Completer<http.Response>();
      final account = AccountController(
        api: AccountApi(
          endpoint: Uri.parse('https://identity.example'),
          client: () => MockClient((_) => pending.future),
        ),
        secrets: _Secrets(),
      );
      addTearDown(account.dispose);
      for (final layout in [
        (const Size(844, 390), 1.0),
        (const Size(568, 320), 1.5),
      ]) {
        tester.view.physicalSize = layout.$1;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
            child: MaterialApp(
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(layout.$2)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showAccountFlow(context, account),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'player@example.com');
        await tester.ensureVisible(find.text('SEND CODE'));
        await tester.tap(find.text('SEND CODE'));
        await tester.pump();
        await tester.ensureVisible(find.text('NOT NOW'));
        await tester.tap(find.text('NOT NOW'));
        await tester.pumpAndSettle();
        expect(find.text('Open'), findsOneWidget);
        expect(find.byType(AccountFlow), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
      pending.complete(http.Response('{}', 503));
      await tester.pump();
    },
  );
  testWidgets('outside taps hide the keyboard and preserve the code step', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var requests = 0;
    final account = AccountController(
      api: AccountApi(
        endpoint: Uri.parse('https://identity.example'),
        client: () => MockClient((_) async {
          requests++;
          return http.Response(
            jsonEncode({
              'requestId': owner,
              'resendAfter': 60,
              'expiresIn': 600,
            }),
            200,
          );
        }),
      ),
      secrets: _Secrets(),
    );
    addTearDown(account.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAccountFlow(context, account),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'player@example.com');
    await tester.tap(find.text('SEND CODE'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123');
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tapAt(const Offset(3, 3));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.byType(AccountFlow), findsOneWidget);
    expect(find.text('CHECK YOUR EMAIL'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '123',
    );
    expect(requests, 1);
    await tester.tapAt(const Offset(3, 3));
    await tester.pumpAndSettle();
    expect(find.byType(AccountFlow), findsOneWidget);
    await tester.tap(find.text('NOT NOW'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountFlow), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'production settings put Gameplay before a concise Account section',
    (tester) async {
      tester.view.physicalSize = const Size(844, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = AccountController(secrets: _Secrets());
      addTearDown(account.dispose);
      account.session = session(owner);
      account.account = {
        'username': 'rook_12',
        'email': 'player@example.com',
        'changesRemaining': 2,
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountProvider.overrideWithValue(account),
            soloudPlayProvider.overrideWithValue(_Quiet()),
          ],
          child: const MaterialApp(
            home: RepaintBoundary(
              key: Key('capture-settings'),
              child: SettingsView(allowProgressReset: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('GAMEPLAY')).dy,
        lessThan(tester.getTopLeft(find.text('ACCOUNT')).dy),
      );
      expect(find.text('SAVE PROGRESS'), findsNothing);
      for (final text in [
        'Change email',
        'Recover older online records',
        'Verify email again',
        '2 username changes left this month.',
      ]) {
        expect(find.text(text), findsNothing);
      }
      expect(find.text('CHANGE USERNAME'), findsOneWidget);
      expect(find.text('player@example.com'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture-settings')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/account-settings.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      for (final size in [const Size(844, 390), const Size(568, 320)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              accountProvider.overrideWithValue(account),
              soloudPlayProvider.overrideWithValue(_Quiet()),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: const SettingsView(allowProgressReset: true),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Delete account'));
        await tester.pumpAndSettle();
        expect(find.text('Delete account').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('account notice renders with real fonts and inline code entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final account = AccountController(
      api: AccountApi(
        endpoint: Uri.parse('https://identity.example'),
        client: () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'requestId': owner,
              'resendAfter': 60,
              'expiresIn': 600,
            }),
            200,
          ),
        ),
      ),
      secrets: _Secrets(),
    );
    addTearDown(account.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
        child: MaterialApp(
          home: RepaintBoundary(
            key: const Key('capture-account'),
            child: AccountFlow(account: account),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'player@example.com');
    await tester.tap(find.text('SEND CODE'));
    await tester.pumpAndSettle();
    expect(find.text('CHECK YOUR EMAIL'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('capture-account')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/account-code.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
}
