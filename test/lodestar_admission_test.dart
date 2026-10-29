import 'package:regun/systems/lodestar/lodestar_combat.dart';

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/lodestar_boss.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/game.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String path) async {}
  @override
  Future<void> playMusic(String path) async {}
  @override
  void pauseMusic(bool paused) {}
  @override
  void configure({required double music, required double sfx}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  WidgetTester? activeTester;
  Future<RegunGame> mount(WidgetTester tester) async {
    activeTester = tester;
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: const MaterialApp(
            home: BaseView(loadout: Loadout(), reviewControlledSpawns: true),
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
    });
    return game;
  }

  Future<LodestarBoss> ready(RegunGame g) async {
    for (var i = 0; i < 100 && g.lodestarCandidate?.prepared != true; i++) {
      await activeTester!.pump(const Duration(milliseconds: 16));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      g.update(1 / 120);
    }
    await g.ready().timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        throw StateError(
          'ready trial=${g.mechanicalTrial} prepared=${g.lodestarCandidate?.prepared} mounted=${g.lodestarCandidate?.isMounted} loaded=${g.lodestarCandidate?.isLoaded} sheet=${g.lodestarCandidate?.assets.sheet != null} arsenal=${g.lodestarCandidate?.assets.arsenal != null} retired=${g.lodestarCandidate?.retired} entrance=${g.playerEntrance.active}',
        );
      },
    );
    expect(g.lodestarCandidate?.prepared, isTrue);
    g.pauseEngine();
    return g.lodestarCandidate!;
  }

  Future<void> advance(RegunGame g, double seconds, {bool held = false}) async {
    for (var t = 0.0; t < seconds - 1e-8; t += .025) {
      g.weaponJoystick.delta.setValues(held ? 70 : 0, 0);
      g.update((seconds - t).clamp(0, .025));
      await g.ready();
    }
  }

  testWidgets(
    'normal Solo Lodestar persists local armor, completes once and resumes director',
    (tester) async {
      final g = await mount(tester);
      Object? failure;
      await tester.runAsync(() async {
        try {
          await advance(g, 3);
          g.spawnBoss(BossKind.lodestar);
          final b = await ready(g);
          expect(g.bosses.single, same(b));
          expect(b.practiceTrial, isFalse);
          await advance(g, 4.2);
          final headHP = b.fight.sections.integrity(LodestarSection.head);
          b.receiveLocalDamage(100000, point: b.fight.rig.poses[0].position);
          expect(b.fight.sections.integrity(LodestarSection.head), headHP);
          for (final s in [
            LodestarSection.accelerator,
            LodestarSection.mortars,
          ]) {
            b.receiveLocalDamage(
              100000,
              point: b.fight.rig.poses[s.index].position,
            );
          }
          expect(b.fight.sections.coreExposed, isTrue);
          final saved = g.checkpoint();
          expect(RunCheckpoint.valid(saved), isTrue);
          g.restartGame();
          await advance(g, 3);
          expect(g.restoreRun(saved), isTrue);
          final restored = await ready(g);
          expect(restored.fight.sections.coreExposed, isTrue);
          expect(restored.fight.sections.integrity(LodestarSection.head), 80);
          expect(
            restored.fight.sections.integrity(LodestarSection.accelerator),
            0,
          );
          expect(g.mechanicalArrival.active, isFalse);
          g.resumeGame();
          await advance(g, 1.6);
          restored.receiveLocalDamage(
            100000,
            point: restored.fight.rig.poses[0].position,
          );
          expect(
            restored.fight.defeated,
            isTrue,
            reason:
                "phase=${restored.fight.phase} depths=${restored.fight.depths} hp=${restored.fight.sections.checkpoint()} source=${restored.lastDamageSource} ready=${restored.readyForFight} state=${g.gameState.gameplayState}",
          );
          expect(g.bossWinCounts['lodestar'], isNull);
          final dying = g.checkpoint();
          expect(
            LodestarCombat.validCheckpoint(restored.checkpointState),
            isTrue,
            reason: "local dying state",
          );
          expect(
            RunCheckpoint.valid(dying),
            isTrue,
            reason:
                "whole dying state ${(dying['enemies'] as List).map((e) => [e['kind'], e['combatId'], e['health']])}",
          );
          await advance(g, 5);
          expect(g.bossWinCounts['lodestar'], 1);
          expect(g.gameState.pendingCores, 1);
          expect(g.director.bossActive, isFalse);
          await advance(g, 1);
          expect(g.bossWinCounts['lodestar'], 1);
        } catch (e, st) {
          failure = "$e\n$st";
        }
      });
      expect(failure, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
