import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_3_component.dart';
import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/components/weapons/grenade_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/presentation/grenade_art.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Audio extends SoloudPlay {
  final sounds = <String>[];
  @override
  Future<void> play(String name) async {
    sounds.add(name);
  }

  @override
  Future<void> playMusic(String theme) async {}
  @override
  void pauseMusic(bool paused) {}
}

void main() {
  testWidgets(
    'tap grenade, freeze/save/restore, blast body edges and fixed ranged remains',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = _Audio();
      late RegunGame game;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(audio)],
            child: const MaterialApp(
              home: BaseView(loadout: Loadout(training: true)),
            ),
          ),
        );
        final fonts = FontLoader('PressStart2P')
          ..addFont(rootBundle.load('assets/fonts/PressStart2P-Regular.ttf'));
        await fonts.load();
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
        game.update(1 / 60);
        await tester.pump();
        final ammo = game.gameState.noOfBullets;
        final factor = game.canvasSize.y / game.camera.viewport.virtualSize.y;
        final inset =
            (game.canvasSize - game.camera.viewport.virtualSize * factor) / 2;
        final touch = (game.grenadeButtonComponent.position * factor + inset)
            .toOffset();
        await tester.tapAt(touch);
        game.update(0);
        await game.ready();
        expect(game.grenades.charges, 1);
        expect(game.gameState.noOfBullets, ammo);
        expect(game.weaponJoystick.relativeDelta.isZero(), isTrue);
        final shot = game.world.children.whereType<GrenadeComponent>().single;
        game.pauseGame();
        final before = shot.checkpoint();
        final charge = game.grenades.remaining;
        game.update(5);
        expect(shot.checkpoint(), before);
        expect(game.grenades.remaining, charge);
        expect(game.throwGrenade(), isFalse);
        game.resumeGame();
        game.update(.3);
        expect(game.throwGrenade(), isTrue);
        game.update(0);
        await game.ready();
        expect(game.grenades.charges, 0);
        expect(game.throwGrenade(), isFalse);
        final snapshot = game.checkpoint();
        expect(RunCheckpoint.valid(snapshot), isTrue);
        expect(
          RunCheckpoint.valid({
            ...snapshot,
            'grenadeProjectiles': [
              {'age': double.nan},
            ],
          }),
          isFalse,
        );
        game.restartGame();
        await game.ready();
        expect(game.restoreRun(snapshot), isTrue);
        await game.ready();
        expect(game.grenades.charges, 0);
        expect(game.world.children.whereType<GrenadeComponent>().length, 2);
        game.resumeGame();
        for (var i = 0; i < 100; i++) { game.update(1 / 60); }
        await game.ready();
        expect(game.world.children.whereType<GrenadeComponent>(), isEmpty);
        expect(audio.sounds.where((s) => s == 'blast.wav').length, 2);
        final actors = [
          Enemy2Component(position: Vector2(150, 120)),
          Enemy2Component(position: Vector2(205, -40)),
          Enemy2Component(position: Vector2(245, 80)),
        ];
        await game.world.addAll(actors);
        await game.ready();
        // Position after occupancy mounting; bodies just outside the radius still intersect.
        for (var i = 0; i < actors.length; i++) {
          actors[i].position.setValues(
            [150.0, 205.0, 245.0][i],
            [120.0, -40.0, 80.0][i],
          );
        }
        game.explode(Vector2(20, 0), radius: 185, damage: 4.5);
        expect(actors[0].combatHealth.current, 1.5);
        expect(actors[1].combatHealth.current, 1.5);
        expect(actors[2].combatHealth.current, 6);
        final ranged = Enemy3Component(position: Vector2(350, 200));
        await game.world.add(ranged);
        await game.ready();
        ranged.update(0);
        final facing = ranged.isFlippedHorizontally;
        game.hitEnemy(ranged, 100);
        await game.ready();
        final corpse = game.world.children
            .whereType<CombatEffect>()
            .where((e) => e.remains != null)
            .single;
        expect(
          identical(
            corpse.remains,
            RegunArt.shared.rawSprite('enemies/ranged_remains', 0),
          ),
          isTrue,
        );
        expect(corpse.flipRemains, facing);
        game.myPlayer.position.x = 600;
        ranged.update(.1);
        expect(ranged.isFlippedHorizontally, facing);
        game.restartGame();
        await game.ready();
        expect(game.grenades.charges, 2);
        expect(game.world.children.whereType<GrenadeComponent>(), isEmpty);
        // Render the exact control states and new remains, not a separate mockup.
        final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xff18141b), BlendMode.src);
        for (var i = 0; i < 3; i++) {
          canvas.save();
          canvas.translate(24 + i * 136, 20);
          GrenadeButtonPainter(
            charges: 2 - i,
            progress: .45,
            remaining: i == 0 ? 0 : 9.9,
            pressed: i == 1,
          ).paint(canvas, const Size.square(112));
          canvas.restore();
        }
        final sprite = RegunArt.shared.rawSprite('enemies/ranged_remains', 0);
        sprite.render(
          canvas,
          position: Vector2(250, 230),
          size: Vector2(160, 160 * sprite.srcSize.y / sprite.srcSize.x),
          anchor: Anchor.center,
        );
        final picture = recorder.endRecording(),
            im = await picture.toImage(480, 320),
            data = await im.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/ordnance.png')
            .writeAsBytes(data!.buffer.asUint8List());
        im.dispose();
        picture.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    },
  );
}
