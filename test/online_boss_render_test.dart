import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/multiplayer/generated/member.dart';
import 'package:regun/multiplayer/generated/room.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/widgets/online_arena.dart';

import 'online_test.dart' as fixtures;

void main() {
  testWidgets(
    'phone-scale online portal, held controls, departure and reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final oldMotion = LocalPreferences.shared.reducedMotion;
      addTearDown(() => LocalPreferences.shared.reducedMotion = oldMotion);
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
      for (final scenario in [
        (BossKind.shadow, 'breach', false),
        (BossKind.saint, 'foundry', false),
        (BossKind.marshal, 'breach', true),
      ]) {
        final (kind, arena, reduced) = scenario;
        LocalPreferences.shared.reducedMotion = reduced;
        if (kind.expansion) {
          await tester.runAsync(
            () => RegunArt.shared.acquire('bosses/${kind.name}'),
          );
        }
        final s = fixtures.FakeSession()
          ..identity = fixtures.id(1).toHexString
          ..connected = true;
        s.room = Room.fromJson({
          ...fixtures.room(mode: 'coop').toJson(),
          'owner': fixtures.id(1),
          'mapId': arena,
          'phase': 'active',
        });
        s.members = [
          for (final n in [1, 2, 3])
            Member.fromJson({
              ...fixtures.member(n, team: 0).toJson(),
              'identity': fixtures.id(n),
              'x': -120.0 + (n - 1) * 80,
              'y': (n - 1) * 80.0,
            }),
        ];
        s.fighters = {
          for (final n in [1, 2, 3])
            fixtures.id(n).toHexString: OnlineGun(fixtures.id(n).toHexString, {
              'weapon': 'carbine',
              'survivor': 'rook',
              'health': 5,
              'maximumHealth': 5,
              'ammo': 12,
            }),
        };
        Map<String, dynamic> boss(double hp, double deadAge) => {
          'key': 'boss',
          'kind': kind.name,
          'boss': true,
          'health': hp,
          'maximumHealth': kind.baseHealth,
          'size': kind.spriteSize,
          'radius': kind.bodyRadius,
          'x': 640.0,
          'y': 70.0,
          'dx': -1,
          'age': 0.0,
          'deadAge': deadAge,
          'bossPhase': 'recovery',
        };
        s.match = OnlineMatch({
          'version': 1,
          'phase': 'active',
          'matchId': 'review-${kind.name}',
        });
        s.scene = [OnlineEntity('boss', 'enemy', boss(kind.baseHealth, 0))];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              soloudPlayProvider.overrideWithValue(fixtures.QuietAudio()),
            ],
            child: MaterialApp(
              home: RepaintBoundary(
                key: const Key('arena'),
                child: OnlineArena(session: s),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 33));
        final capture = Platform.environment['REGUN_ONLINE_BOSS_CLIPS'] == '1';
        final dir = Directory(
          'build/online-boss/${kind.name}${reduced ? '-reduced' : ''}',
        );
        if (capture) dir.createSync(recursive: true);
        for (var i = 0; i < 180; i++) {
          final age = i / 30;
          if (age < 2.65) {
            s.match = OnlineMatch({
              'version': 1,
              'phase': 'boss_reveal',
              'phaseSeconds': 2.65 - age,
              'matchId': 'review-${kind.name}',
              'bossArrival': {
                'serial': 1,
                'duration': 2.65,
                'actors': [boss(kind.baseHealth, 0)],
              },
            });
            expect(s.controlsEnabled, isFalse);
          } else {
            s.match = OnlineMatch({
              'version': 1,
              'phase': 'active',
              'matchId': 'review-${kind.name}',
            });
            if (age >= 3.2 && age < 4.75) {
              s.scene = [OnlineEntity('boss', 'enemy', boss(0, age - 3.2))];
            } else if (age >= 4.75) {
              s.scene = [];
            }
          }
          await tester.pump(const Duration(microseconds: 33333));
          expect(tester.takeException(), isNull);
          expect(find.textContaining('takes the round'), findsNothing);
          if (capture) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('arena')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File('${dir.path}/${i.toString().padLeft(4, '0')}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await s.close();
        if (kind.expansion) RegunArt.shared.release('bosses/${kind.name}');
      }
    },
  );
}
