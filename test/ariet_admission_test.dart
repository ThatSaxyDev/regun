import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/ariet_boss.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/game.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/systems/encounter_director.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Audio extends SoloudPlay {
  @override
  Future<void> play(String name) async {}
  @override
  Future<void> playMusic(String name) async {}
  @override
  void pauseMusic(bool value) {}
}

void main() {
  test('normal boss bag includes Ariet once per complete rotation', () {
    final d = EncounterDirector(), random = Random(95);
    final rotation = [
      for (var i = 0; i < BossKind.active.length; i++) d.chooseBoss(random),
    ];
    expect(rotation.toSet(), BossKind.active.toSet());
    expect(rotation.where((b) => b == BossKind.ariet), hasLength(1));
    expect(BossKind.ariet.expansion, isFalse);
  });

  testWidgets(
    'normal Ariet saves owned escorts, resumes safely and awards one victory after crash',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<RegunGame> mount({Map<String, dynamic>? saved}) async {
        late RegunGame g;
        await tester.runAsync(() async {
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
              child: MaterialApp(
                home: BaseView(
                  reviewControlledSpawns: true,
                  resumeSnapshot: saved,
                ),
              ),
            ),
          );
          g =
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
          if (saved == null) {
            g.update(2);
            await g.ready();
          }
        });
        return g;
      }

      Future<void> advance(RegunGame g, double seconds) async {
        await tester.runAsync(() async {
          for (var i = 0; i < (seconds * 120).ceil(); i++) {
            g.update(1 / 120);
            if (i % 30 == 0) await g.ready();
          }
          await g.ready();
        });
      }

      var g = await mount();
      for (var i = 0; i < 60; i++) {
        g.gameNotifier.healthIncrease();
      }
      await tester.runAsync(() async {
        g.spawnBoss(BossKind.ariet);
        expect(
          RunCheckpoint.valid(g.checkpoint()),
          isTrue,
          reason: 'pending atlas autosave',
        );
        await g.ready();
      });
      var boss = g.activeBoss! as ArietBoss;
      expect(g.arietTrial, isFalse);
      expect(g.bossReveal.active, isFalse);
      expect(g.encounterCameraZoom, .74);
      await advance(g, 3);
      boss.fight.escortQuota = 2;
      boss.fight.deploymentSpent = false;
      expect(boss.takeDamage(82), isTrue);
      for (var i = 0; i < 25 && !boss.escorts.any((e) => e.prepared); i++) {
        await advance(g, 1);
      }
      expect(boss.escorts.where((e) => e.prepared), hasLength(1));
      final hp = boss.combatHealth.current, elapsed = boss.fight.elapsed;
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        g.render(ui.Canvas(rec));
        final pic = rec.endRecording(), image = await pic.toImage(844, 390);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/ariet-normal').createSync(recursive: true);
        File('build/ariet-normal/normal-one-escort.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
        pic.dispose();
      });
      final saved = g.checkpoint();
      expect(
        (saved['enemies'] as List).where((e) => e['kind'] == 'ariet'),
        hasLength(1),
      );
      expect(
        (saved['enemies'] as List).any((e) => e['kind'] == 'arietEscort'),
        isFalse,
      );
      expect(RunCheckpoint.valid(saved), isTrue);
      g = await mount(saved: saved);
      boss = g.activeBoss! as ArietBoss;
      expect(boss.combatHealth.current, hp);
      expect(boss.fight.elapsed, elapsed);
      expect(boss.fight.totalDrops, 1);
      expect(boss.fight.escortQuota, 2);
      expect(boss.escorts.where((e) => e.prepared), hasLength(1));
      expect(
        boss.fight.rounds,
        isEmpty,
        reason: 'continue discards transient hostile attacks',
      );
      g.resumeGame();
      expect(boss.takeDamage(100000), isTrue);
      await advance(g, .5);
      expect(g.gameState.bosses, 0);
      final dying = g.checkpoint();
      expect(RunCheckpoint.valid(dying), isTrue);
      g = await mount(saved: dying);
      boss = g.activeBoss! as ArietBoss;
      expect(boss.combatHealth.current, 0);
      expect(boss.fight.defeated, isTrue);
      g.resumeGame();
      await advance(g, 5);
      expect(g.gameState.bosses, 1);
      expect(g.gameState.pendingCores, 1);
      expect(g.bossWinCounts, {'ariet': 1});
      expect(g.activeBoss, isNull);
      expect(g.arietCandidate, isNull);
      final score = g.gameState.score;
      await advance(g, 1);
      expect(g.gameState.score - score, lessThanOrEqualTo(3));
      expect(g.gameState.bosses, 1);
      expect(g.bossWinCounts, {'ariet': 1});
      expect(g.encounterCameraZoom, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
