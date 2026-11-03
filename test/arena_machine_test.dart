import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/systems/arena_machine.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'a restored windup strikes once and a held plate must clear to rearm',
    () {
      const area = Rect.fromLTWH(0, 0, 150, 90);
      final machine = ArenaMachine(ArenaMachineKind.press, area, area);
      expect(machine.advance(.1, occupied: true), isFalse);
      expect(machine.warning, isTrue);
      machine.advance(.35, occupied: true);

      final restored = ArenaMachine(ArenaMachineKind.press, area, area);
      restored.restore(machine.toJson());
      expect(restored.warningProgress, machine.warningProgress);
      expect(restored.advance(.4, occupied: true), isTrue);
      expect(restored.active, isTrue);
      expect(restored.advance(.1, occupied: true), isFalse);
      expect(restored.advance(6, occupied: true), isFalse);
      expect(restored.ready, isFalse);
      restored.advance(.1, occupied: false);
      expect(restored.ready, isTrue);
      restored.advance(.1, occupied: true);
      expect(restored.warning, isTrue);
    },
  );

  Future<void> advance(RegunGame game, double duration) async {
    for (var t = 0.0; t < duration - 1e-8; t += .02) {
      game.update((duration - t).clamp(0.0, .02));
      await game.ready();
    }
  }

  Future<void> capture(
    RegunGame game,
    ArenaMachine machine,
    String stage,
  ) async {
    final at = machine.kind == ArenaMachineKind.sluice
        ? machine.body.bottomCenter.translate(0, 145)
        : machine.body.center;
    game.camera.viewfinder.position.setValues(at.dx, at.dy);
    final recorder = ui.PictureRecorder();
    game.render(Canvas(recorder));
    final picture = recorder.endRecording();
    final image = await picture.toImage(1500, 700);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory('build/test-previews').create(recursive: true);
    await File('build/test-previews/machine-${machine.kind.name}-$stage.png')
        .writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  }

  for (final arena in ArenaType.values) {
    testWidgets('${arena.name} machinery works through the normal run loop', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1500, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await LocalPreferences.shared.load();
        await tester.pumpWidget(
          MaterialApp(
            home: BaseView(
              loadout: Loadout(training: true, arena: arena),
              reviewControlledSpawns: true,
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
        game.update(2);
        await game.ready();

        if (arena == ArenaType.breach) {
          expect(game.arenaMachines, isEmpty);
          game.practiceSupplyDrop();
          await advance(game, .12);
          expect(game.supplyDrops.drop, isNotNull);
          return;
        }

        final machine = game.arenaMachines.first;
        final zone = machine.area;
        expect(game.geometry.solids, contains(machine.body));
        final player = game.myPlayer;
        final enemy = ArenaEnemy(
          EnemyKind.sentinel,
          position: Vector2(zone.center.dx, zone.center.dy),
        );
        final bystander = ArenaEnemy(
          EnemyKind.sentinel,
          position: Vector2(zone.right + 125, zone.center.dy),
        );
        await game.world.addAll([enemy, bystander]);
        await game.ready();

        switch (arena) {
          case ArenaType.foundry:
            player.position.setValues(zone.left - 95, zone.center.dy);
            await advance(game, .03);
            expect(machine.warning, isTrue);
            final saved = machine.toJson();
            game.pauseGame();
            game.update(1);
            expect(machine.toJson(), saved);
            game.resumeGame();
            await capture(game, machine, 'warning');
            await advance(game, .75);
            expect(enemy.combatHealth.isDead, isTrue);
            expect(bystander.combatHealth.isDead, isFalse);
          case ArenaType.floodworks:
            game.director.elapsed = 8;
            player.position.setValues(zone.left + 45, zone.top + 170);
            final from = player.position.y;
            final enemyFrom = enemy.position.y;
            await advance(game, .03);
            expect(machine.warning, isTrue);
            expect(player.position.y, from);
            await advance(game, 1.9);
            expect(player.position.y, greaterThan(from + 20));
            expect(enemy.position.y, greaterThan(enemyFrom + 20));
            expect(bystander.position.y, closeTo(zone.center.dy, .01));
          case ArenaType.relayGraveyard:
            player.position.setValues(zone.center.dx, zone.top + 45);
            await advance(game, .03);
            expect(machine.warning, isTrue);
            player.position.x = zone.right + 145;
            await advance(game, 1.13);
            expect(enemy.impactHeld, isTrue);
            expect(bystander.impactHeld, isFalse);
            expect(enemy.combatHealth.isDead, isFalse);
          case ArenaType.breach:
            fail('Breach is covered by the airdrop branch');
        }
        expect(machine.active, isTrue);
        await capture(game, machine, 'active');
      });
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}
