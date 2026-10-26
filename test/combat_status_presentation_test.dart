import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/combat_status_art.dart';
import 'package:regun/presentation/guard_feedback.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

import 'support_integration_test.dart' show Quiet;

class DelayedStatusArt extends RegunArt {
  final pending = <Completer<void>>[];
  int owners = 0;
  @override
  Future<void> acquire(String name) async {
    owners++;
    final c = Completer<void>();
    pending.add(c);
    try {
      await c.future;
    } catch (_) {
      owners--;
      rethrow;
    }
  }

  @override
  void release(String name) {
    owners--;
  }
}

void main() {
  test(
    'status fire pending restart/failure/dispose does not leak leases',
    () async {
      final art = DelayedStatusArt(),
          status = CombatStatusArt(art: DelayedStatusArt());
      status.clear();
      final owner = CombatStatusArt(art: art);
      owner.prewarmFire();
      owner.clear();
      owner.prewarmFire();
      art.pending[0].complete();
      await Future<void>.delayed(Duration.zero);
      expect(art.owners, 1);
      expect(art.pending.length, 2);
      art.pending[1].completeError(StateError('decode'));
      await Future<void>.delayed(Duration.zero);
      expect(art.owners, 0);
      owner.prewarmFire();
      expect(
        art.pending.length,
        2,
        reason: 'failure fallback must not retry every frame',
      );
      owner.prewarmFire(retry: true);
      art.pending[2].complete();
      await Future<void>.delayed(Duration.zero);
      expect(art.owners, 1);
      owner.clear();
      expect(art.owners, 0);
    },
  );

  test('guard transitions require accepted serials; generation/restore never replays', () {
    final f = GuardFeedback();
    f.sync(1, 0, 0, 0);
    expect(f.breakAge, -1);
    f.sync(1, 1, 0, .1);
    expect(f.breakAge, 0);
    f.sync(1, 1, 0, 0);
    expect(f.breakAge, 0);
    f.sync(1, 1, 0, .2);
    expect(f.breakAge, .2);
    f.sync(1, 1, 1, 1);
    expect(f.breakAge, -1);
    expect(f.reformAge, 0);
    f.sync(2, 0, 0, 0);
    expect(f.reformAge, -1);
    expect(f.breakAge, -1);
  });
  testWidgets('real fire and guard lifecycle on both arena floors', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = Platform.environment['REGUN_STATUS_CLIPS'] == '1';
    await tester.runAsync(() async {
      for (final arena in ArenaType.values) {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [soloudPlayProvider.overrideWithValue(Quiet())],
            child: MaterialApp(
              home: BaseView(
                loadout: Loadout(
                  training: true,
                  arena: arena,
                  character: CharacterType.warden,
                ),
                reviewControlledSpawns: true,
              ),
            ),
          ),
        );
        final game =
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
        game.update(.01);
        game.myPlayer.position.setZero();
        game.setTrainingDamage(true);
        final enemy = Enemy2Component(position: Vector2(210, 0));
        await game.world.add(enemy);
        await game.ready();
        enemy.ignite(.1);
        game.statusArt.prewarmFire();
        await RegunArt.shared.acquire(CombatStatusArt.flame);
        RegunArt.shared.release(CombatStatusArt.flame);
        expect(game.gameState.guard, isTrue);
        final folder = Directory('build/combat-status-clips/${arena.name}');
        if (capture) await folder.create(recursive: true);
        for (var frame = 0; frame < 150; frame++) {
          if (frame == 45) {
            final hp = game.gameState.health;
            expect(game.damagePlayer(), isTrue);
            expect(game.gameState.health, hp);
            expect(game.gameState.guard, isFalse);
            expect(game.gameNotifier.guardAbsorptions, 1);
          }
          if (frame == 46) {
            expect(
              game.damagePlayer(),
              isFalse,
              reason: 'contact cooldown does not break twice',
            );
          }
          game.update(1 / 30);
          await game.ready();
          if (capture) {
            final recorder = ui.PictureRecorder();
            game.render(Canvas(recorder));
            final picture = recorder.endRecording();
            final im = await picture.toImage(844, 390);
            final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
            await File('${folder.path}/${frame.toString().padLeft(4, '0')}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            im.dispose();
            picture.dispose();
          }
        }
        expect(enemy.burning, isFalse);
        expect(game.gameState.guard, isFalse);
        game.pauseGame();
        final progress = game.gameNotifier.guardRechargeProgress;
        game.update(40);
        expect(game.gameNotifier.guardRechargeProgress, progress);
        enemy.removeFromParent();
        await game.ready();
        game.resumeGame();
        for (var i = 0; i < 400; i++) {
          game.update(.05);
          await game.ready();
        }
        expect(game.gameState.guard, isTrue);
        expect(game.gameNotifier.guardRecharges, 1);
        game.myPlayer.guardFeedback.sync(
          game.gameNotifier.guardGeneration,
          game.gameNotifier.guardAbsorptions,
          game.gameNotifier.guardRecharges,
          0,
        );
        expect(game.myPlayer.guardFeedback.reformAge, greaterThanOrEqualTo(0));
        if (capture) {
          for (var frame = 0; frame < 24; frame++) {
            game.update(1 / 30);
            await game.ready();
            final recorder = ui.PictureRecorder();
            game.render(Canvas(recorder));
            final pic = recorder.endRecording();
            final im = await pic.toImage(844, 390);
            final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '${folder.path}/recharged-${frame.toString().padLeft(4, '0')}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            im.dispose();
            pic.dispose();
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(RegunArt.shared.contains(CombatStatusArt.flame), isFalse);
    });
    expect(tester.takeException(), isNull);
  });
}
