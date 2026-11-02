import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Audio extends SoloudPlay {
  @override
  Future<void> play(String sound) async {}
  @override
  Future<void> playMusic(String sound) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool value) {}
}

void main() {
  Future<RegunGame> mount(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late RegunGame game;
    await tester.runAsync(() async {
      for (final font in ['PressStart2P', 'Orbitron']) {
        await (FontLoader(
          font,
        )..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf'))).load();
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
          child: const MaterialApp(
            home: RepaintBoundary(
              key: Key('navigation-capture'),
              child: BaseView(
                loadout: Loadout(training: true),
                reviewControlledSpawns: true,
              ),
            ),
          ),
        ),
      );
      game =
          tester
                  .widget<RiverpodAwareGameWidget>(
                    find.byType(RiverpodAwareGameWidget),
                  )
                  .game!
              as RegunGame;
      await game.loaded;
      await tester.pump();
      await game.ready();
      game.pauseEngine();
      game.update(2);
      await game.ready();
      for (final e in game.liveEnemies.toList()) {
        e.removeFromParent();
      }
      await game.ready();
    });
    return game;
  }

  for (final seed in [7, 19, 43]) {
    testWidgets(
      'mixed pack $seed preserves melee pressure, spread, pause and live body clearance',
      (tester) async {
        final game = await mount(tester);
        final mummies = <Enemy2Component>[];
        await tester.runAsync(() async {
          game.myPlayer.position.setValues(-300, 0);
          final scorpion = EnemyComponent(position: Vector2.zero());
          await game.world.add(scorpion);
          await game.ready();
          final random = math.Random(seed);
          for (var i = 0; i < 36; i++) {
            final e = Enemy2Component(
              position: Vector2(
                100 + random.nextDouble() * 600,
                -350 + random.nextDouble() * 700,
              ),
            );
            mummies.add(e);
            await game.world.add(e);
            await game.ready();
          }
          var meleeFrames = 0;
          for (var frame = 0; frame < 1800; frame++) {
            game.myPlayer.position.setValues(
              -300 - math.min(frame / 60 * 38, 760),
              0,
            );
            // Deliberately scramble render order. Authority movement is independent.
            for (var i = 0; i < mummies.length; i++) {
              mummies[i].priority = frame.isEven ? i * 100 : -i * 100;
            }
            game.update(1 / 60);
            if (frame > 1200 && mummies.any((a) => a.isAttacking)) {
              meleeFrames++;
            }
            if (frame % 120 == 0) {
              await game.ready();
              final bodies = game.liveEnemies.toList();
              for (var i = 0; i < bodies.length; i++) {
                for (var j = i + 1; j < bodies.length; j++) {
                  expect(
                    bodies[i].position.distanceTo(bodies[j].position),
                    greaterThanOrEqualTo(
                      game.crowdRadius(bodies[i]) +
                          game.crowdRadius(bodies[j]) +
                          3.98,
                    ),
                  );
                }
              }
            }
          }
          expect(
            meleeFrames,
            greaterThan(120),
            reason: 'Spacing must retain a real front attacker',
          );
          final bonds = mummies.fold<int>(
            0,
            (sum, a) =>
                sum +
                mummies
                    .where(
                      (b) => a != b && a.position.distanceTo(b.position) < 94.5,
                    )
                    .length,
          );
          expect(
            bonds,
            lessThan(seed == 19 ? 32 : 100),
            reason: 'Most bodies must not freeze in a minimum-gap lattice',
          );
          final before = [for (final e in mummies) e.position.clone()];
          final memory = jsonEncode({
            for (final e in mummies)
              e.combatId.toString(): game.minionNavigation.memories[e.combatId]
                  ?.toJson(),
          });
          game.pauseGame();
          game.update(5);
          for (var i = 0; i < mummies.length; i++) {
            expect(mummies[i].position, before[i]);
          }
          expect(
            jsonEncode({
              for (final e in mummies)
                e.combatId.toString(): game
                    .minionNavigation
                    .memories[e.combatId]
                    ?.toJson(),
            }),
            memory,
          );
          game.resumeGame();
          final checkpoint = game.checkpoint();
          expect(
            (checkpoint['enemies'] as List).any((e) => e['navigation'] != null),
            isTrue,
          );
          if (seed == 19) {
            await Directory('build/diagnostics').create(recursive: true);
            await File(
              'build/diagnostics/navigation-native-candidate.json',
            ).writeAsString(
              jsonEncode({
                'seed': seed,
                'meleeFrames': meleeFrames,
                'nearContactBonds': bonds,
                'positions': [
                  for (final e in mummies) [e.position.x, e.position.y],
                ],
                'target': [game.myPlayer.position.x, game.myPlayer.position.y],
              }),
            );
          }
        });
        await tester.pump();
        if (seed == 19) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('navigation-capture')),
            );
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('build/diagnostics/navigation-native-art.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        if (seed == 19) {
          await tester.runAsync(() async {
            final checkpoint = game.checkpoint();
            final health = game.gameState.health;
            expect(game.restoreRun(checkpoint), isTrue);
            await game.ready();
            expect(game.gameState.health, health);
            expect(game.minionNavigation.memories, isNotEmpty);
            game.resumeGame();
            for (var i = 0; i < 30; i++) {
              game.update(1 / 60);
            }
            expect(game.liveEnemies.length, 37);
          });
        }
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'static cover alone routes a real mummy, without temporary solids',
    (tester) async {
      final game = await mount(tester);
      await tester.runAsync(() async {
        game.geometry = ArenaGeometry(
          game.map.bounds,
          obstacles: [const Rect.fromLTRB(-46, -52, 46, 0)],
        );
        game.myPlayer.position.setValues(300, -26);
        final e = Enemy2Component(position: Vector2(-250, -26));
        await game.world.add(e);
        await game.ready();
        for (var frame = 0; frame < 900; frame++) {
          game.update(1 / 60);
          if (frame % 60 == 0) await game.ready();
        }
        expect(e.position.x, greaterThan(200));
        expect(e.isAttacking, isTrue);
        final serial = e.statusClock;
        game.update(.05);
        expect(
          e.statusClock - serial,
          closeTo(.05, .000001),
          reason: 'Managed update must execute exactly once',
        );
      });
      await tester.pumpWidget(const SizedBox());
    },
  );
}
