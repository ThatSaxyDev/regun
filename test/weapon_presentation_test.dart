import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/data/enemies.dart';
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
      'bullet impacts shove within occupancy, resist mass and cannot stack-lock',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
          child: const MaterialApp(
              home: BaseView(loadout: Loadout(training: true)))));
      game = tester
          .widget<RiverpodAwareGameWidget>(find.byType(RiverpodAwareGameWidget))
          .game! as RegunGame;
      await game.loaded;
      await tester.pump();
      await game.ready();
      game.update(2);
      final target = Enemy2Component(position: Vector2(300, 0));
      final blocker = Enemy2Component(position: Vector2(495, 0));
      await game.world.addAll([target, blocker]);
      await game.ready();
      final health = target.combatHealth.current;
      expect(game.hitEnemy(target, 1, direction: Vector2(1, 0)), isTrue);
      expect(target.combatHealth.current, health - 1);
      expect(target.impactStride, lessThan(1));
      final start = target.position.clone();
      for (var i = 0; i < 12; i++) {
        target.receiveBulletImpact(Vector2(1, 0), WeaponType.shotgun);
        target.update(.01);
        if (i == 1) expect(target.position.x, greaterThan(start.x));
      }
      expect(target.position.distanceTo(blocker.position),
          greaterThanOrEqualTo(89.9));
      expect(target.position.x - start.x, greaterThan(10));
      expect(target.impactStride, 1); // Repeated pellets cannot prolong it.
      target.update(.2);
      blocker.position.setFrom(target.position + Vector2(95, 0));
      game.crowdOccupancy.rebuild(game.liveEnemies, game.crowdRadius);
      target.receiveBulletImpact(Vector2(1, 0), WeaponType.revolver);
      expect(target.impactStride, lessThan(1)); // Recovers for the next round.
      target.update(.11);
      expect(target.impactStride, 1);
      expect(target.position.distanceTo(blocker.position),
          greaterThanOrEqualTo(93.9));

      for (final kind in [
        EnemyKind.shield,
        EnemyKind.nest,
        EnemyKind.sentinel
      ]) {
        final enemy =
            ArenaEnemy(kind, position: Vector2(-300, kind.index * 150.0));
        await game.world.add(enemy);
        await game.ready();
        enemy.receiveBulletImpact(Vector2(1, 0), WeaponType.revolver);
        expect(enemy.impactStride,
            kind == EnemyKind.shield ? greaterThan(.7) : equals(1));
      }
      game.spawnBoss(BossKind.demon);
      await game.ready();
      final boss = game.activeBoss! as CombatEnemy;
      boss.receiveBulletImpact(Vector2(1, 0), WeaponType.revolver);
      expect(boss.impactStride, 1); // Keep planted warning/attack geometry.

      final wall = game.geometry.obstacles.first;
      target.position
          .setValues(wall.left - game.crowdRadius(target) - 1, wall.center.dy);
      game.crowdOccupancy.rebuild(game.liveEnemies, game.crowdRadius);
      target.update(.25);
      target.receiveBulletImpact(Vector2(1, 0), WeaponType.revolver);
      target.update(.1);
      expect(target.position.x,
          lessThanOrEqualTo(wall.left - game.crowdRadius(target) + .01));
    });
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

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
        for (final font in ['PressStart2P', 'Orbitron']) {
          await (FontLoader(font)
                ..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf')))
              .load();
        }
        await tester.pumpWidget(ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(audio)],
            child: MaterialApp(
                key: UniqueKey(),
                home: RepaintBoundary(
                    key: const Key('weapon-world'),
                    child: BaseView(loadout: Loadout(weapon: type))))));
        game = tester
            .widget<RiverpodAwareGameWidget>(
                find.byType(RiverpodAwareGameWidget))
            .game! as RegunGame;
        await game.loaded;
        await tester.pump();
        await game.ready();
        game.update(2); // Finish deployment before exercising combat.
        final target =
            Enemy2Component(position: game.myPlayer.position + Vector2(180, 0));
        await game.world.add(target);
        await game.ready();
        final ammo = game.gameState.noOfBullets;
        game.weaponJoystick.delta.setValues(60, 0);
        game.spawnShotgunBullets();
        game.weaponJoystick.delta.setZero();
        await game.ready();
        final shots = game.world.children.whereType<BulletComponent>().toList();
        expect(shots, hasLength(type == WeaponType.shotgun ? 3 : 1));
        if (type == WeaponType.shotgun) {
          expect(shots.map((s) => s.direction.y).toSet(), hasLength(3));
          expect(shots[1].direction.y, closeTo(0, .001));
          expect(
              shots.first.direction.y, closeTo(-shots.last.direction.y, .001));
        }
        if (type == WeaponType.carbine) {
          final origins = <Vector2>[shots.single.position.clone()];
          final headings = <double>[shots.single.direction.y];
          for (var round = 0; round < 6; round++) {
            game.weaponJoystick.delta.setValues(60, 0);
            game.spawnShotgunBullets();
            game.weaponJoystick.delta.setZero();
            await game.ready();
            final bullet =
                game.world.children.whereType<BulletComponent>().last;
            origins.add(bullet.position.clone());
            headings.add(bullet.direction.y);
            expect(bullet.direction.x, greaterThan(.999));
            expect(bullet.direction.y.abs(), lessThan(.035));
            final start = bullet.position.clone();
            final heading = bullet.direction.clone();
            bullet.update(.005);
            expect(
                (bullet.position - start - heading * bullet.speed * .005)
                    .length,
                lessThan(.001));
            expect(bullet.direction, heading);
            bullet.removeFromParent();
            await game.ready();
          }
          expect(headings.toSet().length, greaterThan(1));
          expect(origins.map((p) => p.y).toSet().length, greaterThan(1));
          expect(origins.every((p) => (p - origins.first).length < 7), isTrue);
        }
        expect(shots.every((s) => s.weapon == type), isTrue);
        expect(game.gameState.noOfBullets,
            ammo - (type == WeaponType.carbine ? 7 : 1));
        expect(audio.sounds, contains('shot_${type.name}_0.wav'));
        for (final shot in shots) {
          shot.update(.04);
        }
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('weapon-world')));
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/rounds-${type.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        shots[shots.length ~/ 2].update(.3);
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
        game.gameNotifier.maxBulletsIncrease();
        game.gameNotifier.advanceTime(.16);
        await tester.pump();
        expect(find.text('MAG READY'), findsOneWidget);
        final refillBoundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('weapon-world')));
        final refillImage = await refillBoundary.toImage(pixelRatio: 2);
        final refillBytes =
            await refillImage.toByteData(format: ui.ImageByteFormat.png);
        await File('build/test-previews/refill-${type.name}.png')
            .writeAsBytes(refillBytes!.buffer.asUint8List());
        refillImage.dispose();
        game.gameNotifier.advanceTime(.16);
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
