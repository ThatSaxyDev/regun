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
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/widgets/online_combat_hud.dart';
import 'package:regun/widgets/online_upgrade_picker.dart';
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
  String? chosen;
  @override
  Future<void> chooseUpgrade(String choice) async {
    chosen = choice;
  }

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
  setUpAll(() async {
    await RegunArt.shared.load();
    await RegunArt.shared.acquire('arenas/multiplayer_walls_hd');
  });
  tearDownAll(() => RegunArt.shared.release('arenas/multiplayer_walls_hd'));

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
        expect(find.text('Online'), findsOneWidget);
        await tester.ensureVisible(find.text('Versus'));
        await tester.tap(find.text('Versus'));
        await tester.pumpAndSettle();
        expect(find.text('3 v 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Ten characters must fit: the server creates ten-character room codes.
        await tester.ensureVisible(find.text('Join room'));
        await tester.tap(find.text('Join room'));
        await tester.pumpAndSettle();
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
        expect(find.text('ABCDEFGH23'), findsOneWidget);
        expect(find.textContaining('Player 6'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await tester.ensureVisible(find.text('ABCDEFGH23'));
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
  for (final scale in [1.0, 1.8]) {
    testWidgets('online co-op choices and result fit small phone at $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(667, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = FakeSession()
        ..connected = true
        ..identity = id(1).toHexString
        ..combatAvailable = true;
      addTearDown(s.close);
      s.room = Room.fromJson({
        ...room(mode: 'coop').toJson(),
        'owner': id(1),
        'phase': 'active',
      });
      s.members = [member(1), member(2)];
      s.match = OnlineMatch({
        'version': 1,
        'phase': 'choice',
        'phaseSeconds': 15,
      });
      s.fighters = {
        s.identity!: OnlineGun(s.identity!, {
          'health': 6,
          'maximumHealth': 6,
          'weapon': 'shotgun',
          'ammo': 5,
          'ranks': {'heavyLoad': 3},
          'progress': {
            'offerId': 1,
            'source': 'xp',
            'offers': ['heavyLoad', 'maxBulletsIncrease', 'sprintMine'],
            'rerolls': 2,
            'bans': 1,
          },
        }),
      };
      Widget wrap(Widget child) => ProviderScope(
        overrides: [soloudPlayProvider.overrideWithValue(QuietAudio())],
        child: MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: child),
        ),
      );
      await tester.pumpWidget(wrap(OnlineUpgradePicker(session: s)));
      await tester.pumpAndSettle();
      expect(find.text('Heavy Load IV'), findsOneWidget);
      await tester.ensureVisible(find.text('TAKE').first);
      await tester.tap(find.text('TAKE').first);
      await tester.pump();
      expect(s.chosen, 'heavyLoad');
      expect(tester.takeException(), isNull);
      s.match = OnlineMatch({
        'version': 1,
        'phase': 'finished',
        'seconds': 245,
        'wins': [0, 0],
        'winner': -1,
      });
      await tester.pumpWidget(wrap(OnlineCombatHud(session: s)));
      await tester.pumpAndSettle();
      expect(find.text('Run complete'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'covered online combat renders material warnings, enemies and authoritative HUD',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = FakeSession()
        ..connected = true
        ..identity = id(1).toHexString
        ..combatAvailable = true;
      addTearDown(s.close);
      s.room = Room.fromJson({
        ...room().toJson(),
        'owner': id(1),
        'phase': 'active',
        'mapId': 'ossuary_cross_1v1',
        'geometryHash': geometryHashes['ossuary_cross_1v1'],
      });
      s.match = OnlineMatch({
        'version': 1,
        'phase': 'active',
        'round': 1,
        'wins': [1, 0],
        'seconds': 25,
      });
      s.members = [
        for (final n in [1, 2])
          Member.fromJson({
            ...member(n, team: n - 1).toJson(),
            'identity': id(n),
            'x': n == 1 ? -180.0 : 240.0,
            'y': n == 1 ? 0.0 : 100.0,
          }),
      ];
      s.fighters = {
        for (final n in [1, 2])
          id(n).toHexString: OnlineGun(id(n).toHexString, {
            'weapon': n == 1 ? 'shotgun' : 'arcCaster',
            'survivor': 'rook',
            'health': 5,
            'maximumHealth': 6,
            'ammo': 3,
          }),
      };
      s.scene = [
        OnlineEntity('1', 'enemy', {
          'key': 'e:1',
          'kind': 'scorpion',
          'x': 20.0,
          'y': -80.0,
          'size': 85,
          'radius': 25.5,
          'health': 1,
          'maximumHealth': 2,
          'dx': -1,
          'age': 2,
        }),
        OnlineEntity('2', 'enemy', {
          'key': 'e:2',
          'kind': 'mummy',
          'x': -80.0,
          'y': 130.0,
          'size': 100,
          'radius': 30,
          'health': 6,
          'maximumHealth': 6,
          'dx': 1,
          'age': 1,
        }),
        OnlineEntity('3', 'hazard', {
          'key': 'h:1',
          'x': 220,
          'y': -150,
          'shape': 'circle',
          'points': [
            {'x': 220, 'y': -150},
          ],
          'radius': 115,
          'warning': 1.2,
          'duration': 1.5,
          'age': .8,
          'material': 'ember',
        }),
        OnlineEntity('4', 'hazard', {
          'key': 'h:2',
          'x': -100,
          'y': -200,
          'shape': 'line',
          'points': [
            {'x': -100, 'y': -200},
            {'x': 380, 'y': 100},
          ],
          'width': 20,
          'radius': 0,
          'warning': 1,
          'duration': .3,
          'age': .7,
          'material': 'chain',
        }),
      ];
      await tester.runAsync(() async {
        await RegunArt.shared.load();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(QuietAudio())],
          child: MaterialApp(
            home: RepaintBoundary(
              key: const Key('combat-preview'),
              child: OnlineArena(session: s),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('combat-preview')),
      );
      await tester.runAsync(() async {
        final im = await boundary.toImage(pixelRatio: 2),
            data = await im.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/online-combat.png')
            .writeAsBytes(data!.buffer.asUint8List());
        im.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
