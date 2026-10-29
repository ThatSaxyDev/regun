import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support_integration_test.dart' show Quiet;

Future<void> capture(RegunGame g, String name) async {
  final recorder = ui.PictureRecorder();
  g.render(Canvas(recorder));
  final picture = recorder.endRecording(),
      image = await picture.toImage(844, 390);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('build/boss-arrivals/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

void main() {
  testWidgets(
    'both mechanical arrivals pan, freeze with pause, return wide and never pan on death',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        for (final arena in ArenaType.values) {
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [soloudPlayProvider.overrideWithValue(Quiet())],
              child: MaterialApp(
                home: BaseView(
                  loadout: Loadout(training: true, arena: arena),
                  reviewControlledSpawns: true,
                ),
              ),
            ),
          );
          final g =
              tester
                      .widget<RiverpodAwareGameWidget>(
                        find.byType(RiverpodAwareGameWidget),
                      )
                      .game!
                  as RegunGame;
          await g.loaded;
          await tester.pump();
          await g.ready();
          g.pauseEngine();
          g.update(2);
          for (final kind in [BossKind.walker, BossKind.ariet]) {
            g.myPlayer.position.setValues(-1600, -700);
            if (kind == BossKind.walker) {
              g.practiceWalker();
            } else {
              g.practiceAriet();
            }
            await g.ready();
            final actor = g.mechanicalArrival.actor!;
            expect(
              actor.position.distanceTo(g.myPlayer.position),
              greaterThanOrEqualTo(700),
            );
            final radius = kind == BossKind.walker ? 220.0 : 230.0;
            expect(
              g.geometry.solids.any(
                (r) => r.inflate(radius).contains(actor.position.toOffset()),
              ),
              isFalse,
            );
            final before = g.camera.viewfinder.position.clone();
            for (var i = 0; i < 144; i++) {
              g.update(1 / 60);
            }
            expect(
              g.camera.viewfinder.position.distanceTo(before),
              greaterThan(100),
            );
            expect(g.inputBlocked, isTrue);
            await capture(g, '${arena.name}-${kind.name}-arrival');
            final focus = g.camera.viewfinder.position.clone(),
                elapsed = g.mechanicalArrival.elapsed;
            g.pauseGame();
            g.update(8);
            expect(g.camera.viewfinder.position, focus);
            expect(g.mechanicalArrival.elapsed, elapsed);
            g.resumeGame();
            for (var i = 0; i < 90; i++) {
              g.update(1 / 60);
            }
            expect(g.mechanicalArrival.active, isFalse);
            final playerCamera = g.map.bounds.cameraPosition(
              g.myPlayer.position,
              g.camera.viewport.virtualSize / g.camera.viewfinder.zoom,
            );
            expect(
              g.camera.viewfinder.position.distanceTo(playerCamera),
              lessThan(.01),
            );
            expect(
              g.camera.viewfinder.zoom,
              closeTo(kind == BossKind.ariet ? .74 : .8, .001),
            );
            await capture(g, '${arena.name}-${kind.name}-returned');
            final enemy = actor as CombatEnemy;
            expect(enemy.takeDamage(100000), isTrue);
            expect(g.encounterCameraZoom, 1);
            for (var i = 0; i < 120; i++) {
              g.update(1 / 60);
            }
            expect(g.mechanicalArrival.active, isFalse);
            expect(g.camera.viewfinder.zoom, greaterThan(.99));
            final centered = g.map.bounds.cameraPosition(
              g.myPlayer.position,
              g.camera.viewport.virtualSize / g.camera.viewfinder.zoom,
            );
            expect(
              g.camera.viewfinder.position.distanceTo(centered),
              lessThan(.01),
            );
          }
        }
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
