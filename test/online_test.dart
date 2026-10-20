import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spacetimedb/spacetimedb.dart';
import 'package:regun/multiplayer/generated/member.dart';
import 'package:regun/multiplayer/generated/room.dart';
import 'package:regun/multiplayer/geometry.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/online_view.dart';
import 'package:regun/widgets/online_arena.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/models/control_layout.dart';
import 'package:regun/services/local_preferences.dart';

Identity id(int n) => Identity(Uint8List(32)..[0] = n);
Member member(
  int n, {
  int team = 0,
  bool ready = true,
  bool connected = true,
  int ping = 95,
  int at = 0,
}) => Member.fromJson({
  'identity': id(n),
  'name': 'Player $n',
  'team': team,
  'slot': n,
  'ready': ready,
  'connected': connected,
  'pingMs': ping,
  'pingAt': at,
});
Room room({
  String mode = 'versus',
  int teamSize = 3,
  String hash = geometryHash,
}) => Room.fromJson({
  'id': 1,
  'code': 'ABCDEFGH23',
  'owner': id(1),
  'mode': mode,
  'teamSize': teamSize,
  'capacity': mode == 'coop' ? 3 : teamSize * 2,
  'enemies': true,
  'phase': 'waiting',
  'mapId': mode == 'coop' ? 'breach' : 'network_lab',
  'protocol': 1,
  'geometryHash': hash,
});

class FakeSession extends OnlineSession {
  int dashes = 0;
  @override
  void dash() {
    dashes++;
  }

  @override
  Future<void> connect() async {
    connected = true;
    status = 'Connected';
  }
}

class QuietAudio extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
}

void main() {
  test('wire IDs retain bits above 2^53 and across unsigned u64 range', () {
    for (final value in [Int64.parseInt('9007199254740993'), Int64(-1)]) {
      final r = Room.fromJson({
        ...room().toJson(),
        'owner': id(1),
        'id': value.toInt(),
      });
      final encoder = BsatnEncoder();
      r.encodeBsatn(encoder);
      final bytes = encoder.toBytes();
      expect(
        bytes.take(8),
        value == Int64(-1) ? List.filled(8, 255) : [1, 0, 0, 0, 0, 0, 32, 0],
      );
      expect(Room.decodeBsatn(BsatnDecoder(bytes)).id, value);
    }
  });
  test('full balanced PvP teams and 2–3 co-op players are required', () async {
    final s = FakeSession()..identity = id(1).toHexString;
    addTearDown(s.close);
    for (final size in [1, 2, 3]) {
      s.room = room(teamSize: size);
      s.members = [
        for (var i = 1; i <= size * 2; i++) member(i, team: (i - 1) % 2),
      ];
      expect(s.canStart, isTrue);
      s.members.removeLast();
      expect(s.canStart, isFalse);
    }
    s.room = room(mode: 'coop');
    s.members = [member(1), member(2)];
    expect(s.canStart, isTrue);
    s.members.add(member(3, ready: false));
    expect(s.canStart, isFalse);
    s.members[2] = member(3, connected: false);
    expect(s.canStart, isFalse);
    s.members[2] = member(3);
    expect(s.canStart, isTrue);
    s.room = room(hash: 'different geometry');
    expect(s.canStart, isFalse);
  });
  test('ping distinguishes good, fair, poor, stale, measuring and offline', () {
    final now = DateTime.now();
    String label({int ping = 95, int? at, bool online = true}) => pingLabel(
      member(1, ping: ping, at: at ?? now.microsecondsSinceEpoch),
      now,
      online: online,
    );
    expect(label(), '95 ms | Good');
    expect(label(ping: 100), '100 ms | Fair');
    expect(label(ping: 200), '200 ms | Poor');
    expect(label(at: now.microsecondsSinceEpoch - 4000000), 'Stale');
    expect(label(at: 0), 'Measuring…');
    expect(label(online: false), 'Offline');
    expect(
      pingLabel(member(1, at: 1), now, online: true, age: Duration.zero),
      '95 ms | Good',
    );
    expect(
      pingLabel(
        member(1, at: now.microsecondsSinceEpoch),
        now,
        online: true,
        age: const Duration(seconds: 4),
      ),
      'Stale',
    );
  });
  testWidgets(
    'online arena renders shared art and mirrors move/aim/dash input',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final old = LocalPreferences.shared.controls;
      addTearDown(() => LocalPreferences.shared.controls = old);
      final s = FakeSession()
        ..identity = id(1).toHexString
        ..connected = true;
      s.room = Room.fromJson({
        ...room().toJson(),
        'owner': id(1),
        'phase': 'active',
      });
      s.members = [
        for (var i = 1; i <= 6; i++)
          Member.fromJson({
            ...member(i).toJson(),
            'identity': id(i),
            'moveX': 1.0,
            'x': (i - 3) * 100.0,
          }),
      ];
      addTearDown(s.close);
      await tester.runAsync(() async {
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
      for (final mirrored in [false, true]) {
        LocalPreferences.shared.controls = ControlLayout(leftHanded: mirrored);
        final geometry = LocalPreferences.shared.controls.geometry(
          const Size(844, 390),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(QuietAudio())],
            child: MaterialApp(
              home: RepaintBoundary(
                key: const Key('arena'),
                child: OnlineArena(session: s),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump(const Duration(milliseconds: 100));
        final stick = await tester.startGesture(geometry.movement);
        await stick.moveBy(const Offset(40, 0));
        expect(s.moveX, greaterThan(.5));
        await stick.up();
        expect(s.moveX, 0);
        final dash = await tester.startGesture(geometry.dash);
        await dash.up();
        expect(s.dashes, mirrored ? 2 : 1);
        expect(tester.takeException(), isNull);
        if (!mirrored) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('arena')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/test-previews').create(recursive: true);
            await File('build/test-previews/online-arena.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    },
  );
  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'online creation and six-player lobby fit small phone at $scale',
      (tester) async {
        tester.view.physicalSize = const Size(667, 320);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = FakeSession()..identity = id(1).toHexString;
        await tester.runAsync(() async {
          for (final font in [
            ('PressStart2P', 'PressStart2P-Regular.ttf'),
            ('Orbitron', 'Orbitron-Bold.ttf'),
          ]) {
            await (FontLoader(
              font.$1,
            )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
          }
        });
        const capture = Key('online-capture');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(QuietAudio())],
            child: MaterialApp(
              theme: ThemeData.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: capture,
                child: OnlineView(session: s),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Online | connection test'), findsOneWidget);
        await tester.ensureVisible(find.text('VERSUS'));
        await tester.tap(find.text('VERSUS'));
        await tester.pumpAndSettle();
        expect(find.text('3 V 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Ten characters must fit: the server creates ten-character room codes.
        final field = find.byType(TextField).last;
        await tester.ensureVisible(field);
        await tester.enterText(field, 'ABCDEFGH23');
        expect(
          (tester.widget<TextField>(field)).controller!.text,
          'ABCDEFGH23',
        );
        s.room = room();
        s.members = [for (var i = 1; i <= 6; i++) member(i, team: (i - 1) % 2)];
        s.changes.add(null);
        await tester.pumpAndSettle();
        expect(find.text('ROOM ABCDEFGH23'), findsOneWidget);
        expect(find.textContaining('Player 6'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await tester.ensureVisible(find.text('ROOM ABCDEFGH23'));
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/test-previews').create(recursive: true);
            await File('build/test-previews/online-lobby.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
