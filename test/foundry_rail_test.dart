import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/systems/foundry_rail.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BossTarget extends ArenaEnemy {
  _BossTarget({required super.position}) : super(EnemyKind.shield);

  @override
  bool get isBoss => true;
}

void main() {
  test('staggered carts warn before departure and never move together', () {
    const track = Rect.fromLTWH(0, 0, 140, 2000);
    const west = FoundryRail(track);
    const east = FoundryRail(track, offset: FoundryRail.stagger);
    expect(west.warning(3.19), isFalse);
    expect(west.warning(3.21), isTrue);
    expect(west.moving(4.46), isTrue);
    expect(west.bodyAt(7.36).bottom, track.bottom);
    expect(west.bodyAt(13.46).top, track.top);
    for (var frame = 0; frame < 1200; frame++) {
      final time = frame / 60;
      expect(west.moving(time) && east.moving(time), isFalse);
    }
  });

  test('swept collision catches crossing bodies and excludes the bypass', () {
    const old = Rect.fromLTWH(-59, 0, 118, 178);
    final next = old.translate(0, 300);
    expect(
      FoundryRail.strikes(old, next, Vector2(0, 225), Vector2(0, 225), 25),
      isTrue,
    );
    expect(
      FoundryRail.strikes(old, next, Vector2(-180, 225), Vector2(180, 225), 25),
      isTrue,
    );
    expect(
      FoundryRail.strikes(old, next, Vector2(90, 225), Vector2(90, 225), 25),
      isFalse,
    );
    expect(
      FoundryRail.strikes(old, old, Vector2.zero(), Vector2.zero(), 25),
      isFalse,
    );
  });

  testWidgets(
    'Foundry cart is solid, kills enemies, damages the player and pauses',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1500, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await LocalPreferences.shared.load();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(SoloudPlay())],
            child: const MaterialApp(
              home: BaseView(
                loadout: Loadout(training: true, arena: ArenaType.foundry),
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
        game.update(2);
        await game.ready();

        expect(game.foundryRails, hasLength(2));
        final rail = game.foundryRails.first;
        game.director.elapsed = 4.50;
        final body = rail.bodyAt(game.director.elapsed);
        expect(game.geometry.solids, contains(body));
        game.setTrainingDamage(true);
        game.myPlayer.position.setValues(body.center.dx - 65, body.bottom + 95);
        final enemy = ArenaEnemy(
          EnemyKind.shield,
          elite: true,
          position: Vector2(body.center.dx + 65, body.bottom + 102),
        );
        await game.world.add(enemy);
        await game.ready();
        final health = game.gameState.health;
        game.update(.29);
        expect(game.gameState.health, health - 2);
        expect(enemy.combatHealth.isDead, isTrue);

        game.camera.viewfinder.position.setValues(
          body.center.dx,
          body.bottom + 140,
        );
        final recorder = ui.PictureRecorder();
        game.render(Canvas(recorder));
        final picture = recorder.endRecording();
        final image = await picture.toImage(1500, 700);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/foundry-rail.png')
            .writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
        picture.dispose();

        // A leaping enemy still has a physical body on the swept lane.
        final next = rail.bodyAt(game.director.elapsed);
        game.myPlayer.position.setValues(
          next.center.dx - 230,
          next.bottom + 190,
        );
        final runner = ArenaEnemy(
          EnemyKind.runner,
          position: Vector2(next.center.dx - 65, next.bottom + 65),
        );
        await game.world.add(runner);
        await game.ready();
        runner.phase = 2;
        expect(game.isAirborneActor(runner), isTrue);
        game.update(.12);
        expect(runner.combatHealth.isDead, isTrue);

        final boss = _BossTarget(position: Vector2(0, 150));
        await game.world.add(boss);
        await game.ready();
        final bossHealth = boss.combatHealth.current;
        expect(boss.crushByArena(), isFalse);
        expect(boss.combatHealth.current, bossHealth);

        game.pauseGame();
        final elapsed = game.director.elapsed;
        game.update(1);
        expect(game.director.elapsed, elapsed);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
