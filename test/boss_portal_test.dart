import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/presentation/boss_portal.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/utils/soloud_play.dart';

import 'support_integration_test.dart' show Quiet;

void main() {
  testWidgets(
    'all boss portals hold combat, follow pause, depart without corpse pan and restore safely',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = Platform.environment['REGUN_BOSS_PORTAL_CLIPS'] == '1';
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
          g.update(.01);
          for (final kind in _legacyBosses) {
            g.myPlayer.position.setZero();
            g.practiceBoss(kind);
            await g.ready();
            final before = g.checkpoint();
            expect(
              g.damagePlayer(),
              isFalse,
              reason: 'held reveal blocks incoming damage',
            );
            expect(
              g.throwGrenade(),
              isFalse,
              reason: 'held reveal blocks combat input',
            );
            expect(
              RunCheckpoint.valid(before),
              isTrue,
              reason: 'saved pending entry ${kind.name}',
            );
            expect(g.bossReveal.active, isTrue, reason: 'entry ${kind.name}');
            final folder = Directory(
              'build/boss-portals/${arena.name}-${kind.name}',
            );
            if (capture) await folder.create(recursive: true);
            for (var f = 0; f < 150; f++) {
              if (f == 12) {
                final snap = g.checkpoint(),
                    at = g.camera.viewfinder.position.clone();
                g.pauseGame();
                final elapsed = g.bossReveal.elapsed;
                g.update(8);
                expect(g.bossReveal.elapsed, elapsed);
                expect(g.camera.viewfinder.position, at);
                g.resumeGame();
                expect(g.checkpoint(), snap);
              }
              if (f == 95) {
                final actor = g.activeBoss!;
                // Body may be off screen: defeat must never aim the camera at its location.
                if (kind == BossKind.shadow) {
                  actor.position.setValues(1800, 800);
                }
                final center = g.camera.viewfinder.position.clone();
                final hp = g.gameState.health;
                expect(
                  (actor as CombatEnemy).takeDamage(100000),
                  isTrue,
                  reason:
                      'defeat ${kind.name} phase ${g.gameState.gameplayState}',
                );
                await g.ready();
                expect(g.gameState.health, hp + 2);
                expect(g.world.children.whereType<BossDeparture>(), isNotEmpty);
                expect(g.camera.viewfinder.position, center);
              }
              if (f < 75) {
                final elapsed = g.gameState.survivalSeconds;
                g.update(1 / 30);
                await g.ready();
                if (g.bossReveal.active) {
                  expect(g.gameState.survivalSeconds, elapsed);
                  expect(
                    g.checkpoint(),
                    before,
                    reason: 'the complete saved simulation is frozen',
                  );
                }
              } else {
                g.update(1 / 30);
                await g.ready();
              }
              if (f == 84) {
                expect(g.bossReveal.active, isFalse);
                expect(g.camera.viewfinder.zoom, closeTo(.88, .001));
              }
              if (f > 95) {
                final expected = g.map.bounds.cameraPosition(
                  g.myPlayer.position,
                  g.camera.viewport.virtualSize / g.camera.viewfinder.zoom,
                );
                expect(
                  g.camera.viewfinder.position.distanceTo(expected),
                  lessThan(.001),
                  reason: 'defeat camera always remains player anchored',
                );
              }
              if (capture) {
                final rec = ui.PictureRecorder();
                g.render(Canvas(rec));
                final pic = rec.endRecording();
                final im = await pic.toImage(844, 390);
                final bytes = await im.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File('${folder.path}/${f.toString().padLeft(4, '0')}.png')
                    .writeAsBytes(bytes!.buffer.asUint8List());
                im.dispose();
                pic.dispose();
              }
            }
            expect(g.world.children.whereType<BossDeparture>(), isEmpty);
            expect(g.camera.viewfinder.zoom, greaterThan(.99));
          }
          // A pair shares one safe presentation and keeps the wide view until both die.
          g.spawnBoss(BossKind.bellkeeper);
          g.spawnBoss(BossKind.marshal, companion: true);
          await g.ready();
          expect(g.bossReveal.actors.length, 2);
          final save = g.checkpoint();
          expect(RunCheckpoint.valid(save), isTrue);
          g.update(3);
          g.update(.01);
          expect(g.bossReveal.active, isFalse);
          final pair = g.bosses.toList();
          (pair[0] as CombatEnemy).takeDamage(100000);
          g.update(.1);
          expect(g.camera.viewfinder.zoom, closeTo(.88, .001));
          g.restartGame();
          await g.ready();
          expect(g.restoreRun(save), isTrue, reason: 'restore pair');
          await g.ready();
          expect(
            g.bossReveal.active,
            isFalse,
            reason: 'Continue settles the reveal, never replays it',
          );
          g.resumeGame();
          g.update(.1);
          expect(g.bosses.length, 2);
          // Reduced Motion keeps the camera on the player through entrance as well.
          g.preferences.reducedMotion = true;
          g.practiceBoss(BossKind.marshal);
          await g.ready();
          final at = g.camera.viewfinder.position.clone();
          g.update(.2);
          expect(g.camera.viewfinder.position.distanceTo(at), lessThan(.001));
          g.update(.6);
          expect(g.bossReveal.active, isFalse);
          g.preferences.reducedMotion = false;
          await tester.pumpWidget(const SizedBox.shrink());
        }
        for (final kind in _legacyBosses.where((k) => k.expansion)) {
          expect(RegunArt.shared.contains('bosses/${kind.name}'), isFalse);
        }
      });
      expect(tester.takeException(), isNull);
    },
  );
}

final _legacyBosses = BossKind.active
    .where((kind) => kind != BossKind.walker)
    .toList();
