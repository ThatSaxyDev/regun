import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/components/weapons/weapon_art.dart';
import 'package:regun/components/weapons/weapon_impact.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/utils/soloud_play.dart';

class _Audio extends SoloudPlay {
  final sounds = <String>[];
  @override
  Future<void> play(String sound) async {
    sounds.add(sound);
  }

  @override
  Future<void> playMusic(String theme) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool paused) {}
}

void main() {
  testWidgets(
      'each weapon fires its own visuals/audio, hits once, and clears hit feedback',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final type in WeaponType.values) {
      SharedPreferences.setMockInitialValues({});
      final audio = _Audio();
      late RegunGame game;
      await tester.runAsync(() async {
        await tester.pumpWidget(ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(audio)],
            child: MaterialApp(
                key: UniqueKey(),
                home: BaseView(loadout: Loadout(weapon: type)))));
        game = tester
            .widget<RiverpodAwareGameWidget>(
                find.byType(RiverpodAwareGameWidget))
            .game! as RegunGame;
        await game.loaded;
        await tester.pump();
        await game.ready();
        final target =
            Enemy2Component(position: game.myPlayer.position + Vector2(180, 0));
        await game.world.add(target);
        await game.ready();
        final ammo = game.gameState.noOfBullets;
        game.weaponJoystick.delta.setValues(60, 0);
        game.spawnShotgunBullets();
        await game.ready();
        final shots = game.world.children.whereType<BulletComponent>().toList();
        expect(shots, isNotEmpty);
        expect(shots.every((s) => s.weapon == type), isTrue);
        expect(game.gameState.noOfBullets, ammo - 1);
        expect(audio.sounds, contains('shot_${type.name}_0.wav'));
        shots.first.update(.3);
        await game.ready();
        expect(
            game.world.children
                .whereType<WeaponImpact>()
                .any((f) => f.weapon == type),
            isTrue);
        expect(audio.sounds, contains('impact_${type.name}.wav'));
        target.update(.001);
        expect(target.paint.colorFilter, isNotNull);
        target.update(.12);
        expect(target.paint.colorFilter, isNull);
        for (var i = 0; i < 45; i++) {
          game.update(1 / 60);
          await game.ready();
        }
        expect(game.world.children.whereType<WeaponImpact>(), isEmpty);
        expect(game.runtimeCounts['effects']!, lessThanOrEqualTo(40));
        expect(game.claimWeaponImpact(), isTrue);
        final health = game.gameState.health;
        game.damagePlayer();
        expect(game.gameState.health, health - 1);
        expect(game.damageFeedback.remaining, greaterThan(0));
        expect(audio.sounds, contains('hurt_player.wav'));
        game.restartGame();
        await game.ready();
        expect(game.damageFeedback.remaining, 0);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('render distinct firing and mechanical reload stages for review',
      (tester) async {
    await tester.runAsync(() async {
      await RegunArt.shared.load();
      await (FontLoader('PressStart2P')
            ..addFont(rootBundle.load('assets/fonts/PressStart2P-Regular.ttf')))
          .load();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xff141117), BlendMode.src);
      for (final type in WeaponType.values) {
        final title = TextPainter(
            text: TextSpan(
                text: type.title,
                style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 14,
                    color: Color(0xffE5DDD1))),
            textDirection: TextDirection.ltr)
          ..layout();
        title.paint(canvas, Offset(16, type.index * 160.0 + 12));
        for (var col = 0; col < 4; col++) {
          canvas.save();
          canvas.translate(110 + col * 210.0, type.index * 160.0 + 90);
          canvas.scale(2.6);
          paintWeapon(canvas, type,
              recoil: col == 0 ? 1 : 0,
              reload: col == 0 ? -1 : [.15, .55, .94][col - 1]);
          canvas.restore();
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(900, 640);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/weapon-identity.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    });
  });
}
