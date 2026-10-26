import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_3_component.dart';
import 'package:regun/components/enemies/shadow_boss_component.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/systems/supply_drops.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Audio extends SoloudPlay {
  final sounds = <String>[];
  @override
  Future<void> play(String asset) async {
    sounds.add(asset);
  }

  @override
  Future<void> playMusic(String theme) async {}
  @override
  void pauseMusic(bool paused) {}
}

void main() {
  testWidgets(
    'Breach drops crush ordinary roles, lightly hit bosses, capture and persist',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late RegunGame game;
      final audio = _Audio();
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(audio)],
            child: const MaterialApp(
              home: BaseView(loadout: Loadout(training: true)),
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
        game.update(2);
        expect(game.geometry.obstacles, isEmpty);
        expect(game.supplyDrops.drop, isNull);
        final actors = <PositionComponent>[
          EnemyComponent(),
          Enemy2Component(),
          Enemy3Component(),
          for (final kind in EnemyKind.values.skip(3)) ArenaEnemy(kind),
        ];
        game.spawnBoss(BossKind.shadow);
        final safe = Enemy2Component(position: Vector2(170, 0));
        await game.world.addAll([...actors, safe]);
        await game.ready();
        final boss = game.activeBoss! as ShadowBossComponent;
        boss.position.setZero();
        for (final actor in actors) {
          actor.position.setZero();
        }
        safe.position.setValues(170, 0);
        game.landSupplyDrop(Offset.zero);
        for (final actor in actors) {
          expect(
            (actor as CombatEnemy).combatHealth.isDead,
            isTrue,
            reason: actor.runtimeType.toString(),
          );
        }
        expect(
          boss.combatHealth.current,
          closeTo(boss.combatHealth.maximum * .97 - 8, .001),
        );
        expect(safe.combatHealth.isDead, isTrue);
        game.restartGame();
        await game.ready();
        game.update(2);
        game.supplyDrops.drop = SupplyDrop(const Offset(450, 0));
        game.update(.01); // Begin leased art loading while the warning waits.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await game.ready();
        expect(RegunArt.shared.contains('arenas/supply_pod'), isTrue);
        game.myPlayer.position.setValues(450, 0);
        game.update(1.8);
        game.update(.65);
        expect(game.supplyDrops.drop!.phase, SupplyPhase.active);
        final time = game.supplyDrops.drop!.life;
        game.pauseGame();
        game.update(20);
        expect(game.supplyDrops.drop!.life, time);
        game.resumeGame();
        game.update(3);
        final snapshot = game.checkpoint();
        game.restartGame();
        await game.ready();
        expect(game.restoreRun(snapshot), isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(game.supplyDrops.drop!.capture, closeTo(3, .05));
        game.resumeGame();
        game.update(5.01);
        expect(game.gameState.gameplayState, GameplayState.powerup);
        expect(game.gameNotifier.supplyOffer, isTrue);
        expect(game.supplyDrops.drop!.claimed, isTrue);
        expect(
          audio.sounds.where((s) => s == 'supply_claim.wav'),
          hasLength(1),
        );
        final frame = game.supplyDrops.drop!.elapsed;
        game.update(20);
        expect(game.supplyDrops.drop!.elapsed, frame);
        game.gameNotifier.applyPowerUp(
          game.gameState.powerUpChoices.first,
          offerId: game.gameState.offerId,
        );
        game.update(
          2,
        ); // Confirmation holds the claimed linger/breakdown clocks.
        game.update(4.3);
        expect(game.supplyDrops.drop, isNull);
        expect(RegunArt.shared.contains('arenas/supply_pod'), isFalse);
        game.restartGame();
        await game.ready();
        game.update(2);
        expect(game.supplyDrops.drop, isNull);
        expect(game.supplyDrops.nextIn, greaterThan(20));
        game.supplyDrops.drop = SupplyDrop(const Offset(450, 0));
        game.update(.01);
        game.restartGame(); // Cancel during pending atlas acquisition.
        await game.ready();
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(RegunArt.shared.contains('arenas/supply_pod'), isFalse);
        game.startBossRush();
        game.update(35);
        expect(game.supplyDrops.drop, isNull);
        expect(RegunArt.shared.contains('arenas/supply_pod'), isFalse);
        game.practiceSupplyDrop();
        game.update(.01);
        expect(game.bossRush, isFalse);
        expect(game.supplyDrops.drop!.phase, SupplyPhase.warning);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'render warning, landing dust, active field and breakdown in arena',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
            child: const MaterialApp(
              home: BaseView(loadout: Loadout(training: true)),
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
        for (final font in [
          ('PressStart2P', 'PressStart2P-Regular.ttf'),
          ('Orbitron', 'Orbitron-Bold.ttf'),
        ]) {
          await (FontLoader(
            font.$1,
          )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
        }
        await RegunArt.shared.acquire('arenas/supply_pod');
        await RegunArt.shared.acquire('effects/landing_dust');
        final stages = [
          (SupplyPhase.warning, .8),
          (SupplyPhase.falling, .3),
          (SupplyPhase.active, .1),
          (SupplyPhase.active, 4.0),
          (SupplyPhase.opened, 1.0),
          (SupplyPhase.breaking, .6),
        ];
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        for (var i = 0; i < stages.length; i++) {
          final d = SupplyDrop(Offset.zero)
            ..phase = stages[i].$1
            ..elapsed = stages[i].$2
            ..inside = i == 3
            ..capture = i == 3 ? 4 : 0
            ..claimed = i >= 4;
          game.supplyDrops.drop = d;
          game.myPlayer.position.setValues(i == 3 ? -110 : -220, 35);
          game.camera.viewfinder.position.setZero();
          canvas.save();
          canvas.translate((i % 2) * 750.0, (i ~/ 2) * 350.0);
          canvas.clipRect(const Rect.fromLTWH(0, 0, 750, 350));
          canvas.scale(750 / game.canvasSize.x, 350 / game.canvasSize.y);
          game.render(canvas);
          canvas.restore();
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(1500, 1050);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/supply-drops.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
        game.supplyDrops.drop = SupplyDrop(Offset.zero)
          ..phase = SupplyPhase.active
          ..inside = true
          ..capture = 4
          ..elapsed = 4
          ..life = 4;
        game.myPlayer.position.setValues(-110, 35);
        final areaRecorder = ui.PictureRecorder();
        game.render(Canvas(areaRecorder));
        final areaPicture = areaRecorder.endRecording();
        final areaImage = await areaPicture.toImage(1500, 700);
        final areaBytes = await areaImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        await File('build/test-previews/supply-area.png')
            .writeAsBytes(areaBytes!.buffer.asUint8List());
        areaImage.dispose();
        areaPicture.dispose();
        RegunArt.shared.release('arenas/supply_pod');
        RegunArt.shared.release('effects/landing_dust');
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
