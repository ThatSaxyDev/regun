import 'package:regun/services/account/account_controller.dart';
import 'package:regun/models/account/account_session.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/online_view.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/online_preparation.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'online_test.dart' show FakeSession, QuietAudio, id, member, room;

class ControlledSession extends FakeSession {
  bool inFlight = false;
  int attempts = 0, joins = 0, starts = 0, recoveries = 0;
  @override
  Future<void> recoverGuest() async {
    recoveries++;
  }

  String? joinedCode;
  @override
  bool get connecting => inFlight;
  @override
  Future<void> connect() async {
    attempts++;
  }

  @override
  Future<void> join(String code, String name) async {
    joins++;
    joinedCode = code;
  }

  @override
  Future<void> start() async {
    starts++;
  }
}

Widget wrap(OnlineSession session, {double scale = 1}) => ProviderScope(
  overrides: [soloudPlayProvider.overrideWithValue(QuietAudio())],
  child: MaterialApp(
    theme: ThemeData.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: RepaintBoundary(
      key: const Key('capture'),
      child: OnlineView(session: session),
    ),
  ),
);

Future<void> capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/test-previews').create(recursive: true);
    await File('build/test-previews/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUp(() {
    AccountController.shared.session = const AccountSession(
      accountId: '11111111-1111-4111-8111-111111111111',
      accessToken: 'test-account-token',
      refreshToken: 'test-refresh-token',
      expiresAt: 4102444800,
    );
    AccountController.shared.account = {
      'username': 'ada',
      'changesRemaining': 2,
    };
  });
  setUpAll(() async {
    await RegunArt.shared.load();
    for (final font in [
      ('PressStart2P', 'PressStart2P-Regular.ttf'),
      ('Orbitron', 'Orbitron-Bold.ttf'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
    }
  });

  test(
    'room codes preserve invalid characters for correction and normalize paste',
    () {
      const formatter = RoomCodeFormatter();
      final value = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'abcde-fgh23',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      expect(value.text, 'ABCDEFGH23');
      expect(value.selection.extentOffset, 10);
      expect(RoomCodeFormatter.valid(value.text), isTrue);
      expect(RoomCodeFormatter.valid('ABCDE0GH23'), isFalse);
      const composing = TextEditingValue(
        text: 'abc',
        composing: TextRange(start: 0, end: 3),
      );
      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, composing),
        composing,
      );
    },
  );

  test('connection distinguishes service rejection, invalid schema and art failure', () async {
    final prepare = OnlineSession.prepareAssets;
    addTearDown(() => OnlineSession.prepareAssets = prepare);
    for (final scenario in ['http', 'schema', 'assets']) {
      final session = OnlineSession();
      final gate = Completer<http.Response>();
      OnlineSession.prepareAssets = () => Future.error(StateError('decode'));
      await http.runWithClient(() async {
        final connecting = session.connect();
        expect(session.connecting, isTrue);
        expect(session.error, isEmpty);
        gate.complete(switch (scenario) {
          'http' => http.Response('down', 503),
          'schema' => http.Response('invalid', 200),
          _ => http.Response(
            '{"misc_exports":[{"View":{"name":"room_combat"}}]}',
            200,
          ),
        });
        await connecting;
      }, () => MockClient((request) => gate.future));
      expect(session.connected, isFalse);
      expect(session.connecting, isFalse);
      expect(session.retryScheduled, isTrue);
      expect(
        session.connectionDiagnostic,
        startsWith(switch (scenario) {
          'http' => 'schema_http_503',
          'schema' => 'schema_',
          _ => 'assets_',
        }),
      );
      expect(
        session.error,
        contains(switch (scenario) {
          'http' => 'service is unavailable',
          'schema' => 'service needs an update',
          _ => 'Arena preparation failed',
        }),
      );
      await session.close();
    }
  });

  test(
    'closing during schema request prevents asset work and session attachment',
    () async {
      final session = OnlineSession();
      final gate = Completer<http.Response>();
      final prepare = OnlineSession.prepareAssets;
      var prepared = false;
      OnlineSession.prepareAssets = () async {
        prepared = true;
      };
      addTearDown(() => OnlineSession.prepareAssets = prepare);
      await http.runWithClient(() async {
        final connecting = session.connect();
        await Future<void>.delayed(Duration.zero);
        await session.close();
        gate.complete(
          http.Response(
            '{"misc_exports":[{"View":{"name":"room_combat"}}]}',
            200,
          ),
        );
        await connecting;
      }, () => MockClient((request) => gate.future));
      expect(prepared, isFalse);
      expect(session.connected, isFalse);
      expect(session.retryScheduled, isFalse);
    },
  );

  testWidgets(
    'initial attempt hides retry; failure preserves the read-only account username',
    (tester) async {
      final s = ControlledSession()
        ..inFlight = true
        ..status = 'Connecting…';
      await tester.pumpWidget(wrap(s));
      await tester.pumpAndSettle();
      expect(s.attempts, 1);
      expect(find.text('RETRY CONNECTION'), findsNothing);
      expect(find.textContaining('connection test'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('ada'), findsOneWidget);
      expect(find.text('Change your username in Settings.'), findsOneWidget);
      s.inFlight = false;
      s.status = 'Connection failed';
      s.error = 'Online service is unavailable. Please try again shortly.';
      s.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('RETRY CONNECTION'), findsOneWidget);
      expect(find.text('ada'), findsOneWidget);
      await tester.tap(find.text('RETRY CONNECTION'));
      await tester.pump();
      expect(s.attempts, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('rejected account never offers an anonymous guest fallback', (
    tester,
  ) async {
    final s = ControlledSession()
      ..guestRejected = true
      ..status = 'Connection failed'
      ..error =
          'Sign in again from Settings to reconnect. Solo and Training are available.';
    await tester.pumpWidget(wrap(s));
    await tester.pumpAndSettle();
    expect(find.text('RETRY CONNECTION'), findsNothing);
    expect(find.text('START NEW GUEST'), findsNothing);
    expect(find.textContaining('Sign in again from Settings'), findsOneWidget);
    expect(s.recoveries, 0);
    expect(s.recoveries, 0);
    await tester.pumpWidget(const SizedBox());
  });

  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'join validates and submits code; keyboard dismiss/refocus at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(667, 320);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final s = ControlledSession()..connected = true;
        await tester.pumpWidget(wrap(s, scale: scale));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Join room'));
        await tester.pumpAndSettle();
        expect(find.text('Game mode'), findsNothing);
        var field = find.byType(TextField).last;
        await tester.ensureVisible(field);
        await tester.enterText(field, 'abcde-fgh23');
        await tester.pump();
        expect(tester.widget<TextField>(field).controller!.text, 'ABCDEFGH23');
        expect(
          tester
              .widget<ClickButton>(
                find.widgetWithText(ClickButton, 'JOIN ROOM'),
              )
              .onTap,
          isNotNull,
        );
        await tester.enterText(field, 'ABCDE0GH23');
        await tester.pump();
        expect(
          tester
              .widget<ClickButton>(
                find.widgetWithText(ClickButton, 'JOIN ROOM'),
              )
              .onTap,
          isNull,
        );
        await tester.enterText(field, 'ABCDEFGH23');
        // Model an actual landscape soft keyboard inset, not just test IME focus.
        tester.view.viewInsets = const FakeViewPadding(bottom: 190);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Hide keyboard'), findsOneWidget);
        await tester.tap(find.text('Hide keyboard'));
        await tester.pump();
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
        expect(tester.widget<TextField>(field).controller!.text, 'ABCDEFGH23');
        await tester.testTextInput.receiveAction(TextInputAction.join);
        await tester.pumpAndSettle();
        expect(s.joins, 1);
        expect(s.joinedCode, 'ABCDEFGH23');
        // Empty names immediately disable submission; no stale controller state.
        await tester.ensureVisible(find.byType(TextField).first);
        await tester.enterText(find.byType(TextField).first, '   ');
        await tester.pump();
        expect(
          tester
              .widget<ClickButton>(
                find.widgetWithText(ClickButton, 'JOIN ROOM'),
              )
              .onTap,
          isNull,
        );
        if (scale == 1) {
          await tester.enterText(find.byType(TextField).first, 'Ada');
          tester
              .widget<TextField>(find.byType(TextField).first)
              .focusNode!
              .unfocus();
          await tester.pumpAndSettle();
          await capture(tester, 'online-join');
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }

  testWidgets(
    'explicit clipboard actions normalize invitations and confirm copy',
    (tester) async {
      var clipboard = 'abcde-fgh23';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final s = ControlledSession()
        ..connected = true
        ..identity = id(1).toHexString;
      await tester.pumpWidget(wrap(s));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join room'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Paste code'));
      await tester.tap(find.text('Paste code'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.controller!.text, 'ABCDEFGH23');
      expect(field.focusNode!.hasFocus, isTrue);
      // An outside touch dismisses editing without wiping the invitation.
      await tester.tap(find.text('Online'));
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, isFalse);
      expect(field.controller!.text, 'ABCDEFGH23');
      s.room = room(mode: 'coop');
      s.members = [member(1)];
      s.changes.add(null);
      await tester.pumpAndSettle();
      await tester.tap(find.text('COPY CODE'));
      await tester.pumpAndSettle();
      expect(clipboard, 'ABCDEFGH23');
      expect(find.text('COPIED'), findsOneWidget);
      expect(find.text('Room code copied'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'lobby arrivals, empty slots, readiness, loadouts and reconnect resync',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = ControlledSession()
        ..connected = true
        ..combatAvailable = true
        ..identity = id(1).toHexString
        ..room = room(mode: 'coop')
        ..match = OnlineMatch({'version': 1, 'phase': 'waiting'})
        ..members = [member(1)];
      for (var i = 1; i <= 3; i++) {
        s.fighters[id(i).toHexString] = OnlineGun(id(i).toHexString, {
          'weapon': WeaponType.values[i].name,
          'survivor': CharacterType.values[i - 1].name,
        });
      }
      await tester.pumpWidget(wrap(s));
      await tester.pumpAndSettle();
      expect(find.text('Waiting for player'), findsNWidgets(2));
      expect(find.text('Waiting for one more player'), findsOneWidget);
      expect(
        tester
            .widget<ClickButton>(
              find.widgetWithText(ClickButton, 'START MATCH'),
            )
            .onTap,
        isNull,
      );
      s.members.add(member(2, ready: false));
      s.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Player 2 joined'), findsOneWidget);
      expect(find.text('Waiting for player'), findsOneWidget);
      expect(find.text('Revolver'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Player 2 is choosing'), findsOneWidget);
      s.members[1] = member(2);
      s.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Everyone is ready'), findsOneWidget);
      expect(
        tester
            .widget<ClickButton>(
              find.widgetWithText(ClickButton, 'START MATCH'),
            )
            .onTap,
        isNotNull,
      );
      await capture(tester, 'online-squad');
      await tester.tap(find.text('START MATCH'));
      await tester.pump();
      expect(s.starts, 1);
      s.members[1] = member(2, connected: false);
      s.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Reconnecting'), findsOneWidget);
      expect(find.text('Player 2 is reconnecting'), findsOneWidget);
      s.connected = false;
      s.changes.add(null);
      await tester.pump();
      s.connected = true;
      s.members.add(member(3));
      s.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Player 3 joined'), findsNothing);
      expect(find.text('Player 3'), findsOneWidget);
      s.members.removeLast();
      s.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Player 3 left'), findsOneWidget);
      s.room = null;
      s.members = [];
      s.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('This room is no longer available'), findsOneWidget);
      expect(find.text('JOIN ROOM'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
