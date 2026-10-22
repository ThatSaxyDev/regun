import 'dart:math' as math;

import 'package:regun/presentation/weapon_art_spec.dart';

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
import 'package:regun/components/enemies/enemy_3_projectile.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/components/weapons/weapon_art.dart';
import 'package:regun/components/weapons/weapon_impact.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/systems/weapon_ballistics.dart';
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
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
            child: const MaterialApp(
              home: BaseView(
                loadout: Loadout(training: true, arena: ArenaType.foundry),
              ),
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
        final target = Enemy2Component(position: Vector2(300, 0));
        final blocker = Enemy2Component(position: Vector2(495, 0));
        await game.world.addAll([target, blocker]);
        await game.ready();
        final health = target.combatHealth.current;
        expect(game.hitEnemy(target, 1, direction: Vector2(1, 0)), isTrue);
        expect(target.combatHealth.current, health - 1);
        expect(target.impactStride, lessThan(1));
        final start = target.position.clone();
        for (var i = 0; i < 20; i++) {
          target.receiveBulletImpact(Vector2(1, 0), WeaponType.shotgun);
          target.update(.01);
          if (i == 1) expect(target.position.x, greaterThan(start.x));
        }
        expect(
          target.position.distanceTo(blocker.position),
          greaterThanOrEqualTo(89.9),
        );
        expect(target.position.x - start.x, greaterThan(10));
        expect(target.impactStride, 1); // Repeated pellets cannot prolong it.
        target.update(.2);
        blocker.position.setFrom(target.position + Vector2(95, 0));
        game.crowdOccupancy.rebuild(game.liveEnemies, game.crowdRadius);
        target.receiveBulletImpact(Vector2(1, 0), WeaponType.revolver);
        expect(
          target.impactStride,
          lessThan(1),
        ); // Recovers for the next round.
        target.update(.17);
        expect(target.impactStride, 1);
        expect(
          target.position.distanceTo(blocker.position),
          greaterThanOrEqualTo(93.9),
        );

        for (final kind in [
          EnemyKind.shield,
          EnemyKind.nest,
          EnemyKind.sentinel,
        ]) {
          final enemy = ArenaEnemy(
            kind,
            position: Vector2(-300, kind.index * 150.0),
          );
          await game.world.add(enemy);
          await game.ready();
          enemy.receiveBulletImpact(Vector2(1, 0), WeaponType.revolver);
          expect(
            enemy.impactStride,
            kind == EnemyKind.shield ? greaterThan(.65) : equals(1),
          );
        }
        game.spawnBoss(BossKind.demon);
        await game.ready();
        final boss = game.activeBoss! as CombatEnemy;
        boss.receiveBulletImpact(Vector2(1, 0), WeaponType.revolver);
        expect(boss.impactStride, 1); // Keep planted warning/attack geometry.

        final wall = game.geometry.obstacles.first;
        target.position.setValues(
          wall.left - game.crowdRadius(target) - 1,
          wall.center.dy,
        );
        game.crowdOccupancy.rebuild(game.liveEnemies, game.crowdRadius);
        target.update(.25);
        target.receiveBulletImpact(Vector2(1, 0), WeaponType.revolver);
        target.update(.1);
        expect(
          target.position.x,
          lessThanOrEqualTo(wall.left - game.crowdRadius(target) + .01),
        );
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'each weapon fires its own visuals/audio, hits once, and clears hit feedback',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final type in WeaponType.values.where(
        (w) => !w.usesArsenalRuntime,
      )) {
        SharedPreferences.setMockInitialValues({});
        final audio = _Audio();
        late RegunGame game;
        await tester.runAsync(() async {
          for (final font in ['PressStart2P', 'Orbitron']) {
            await (FontLoader(font)
                  ..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf')))
                .load();
          }
          await tester.pumpWidget(
            ProviderScope(
              overrides: [soloudPlayProvider.overrideWithValue(audio)],
              child: MaterialApp(
                key: UniqueKey(),
                home: RepaintBoundary(
                  key: const Key('weapon-world'),
                  child: BaseView(loadout: Loadout(weapon: type)),
                ),
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
          game.update(2); // Finish deployment before exercising combat.
          final target = Enemy2Component(
            position: game.myPlayer.position + Vector2(180, 0),
          );
          await game.world.add(target);
          await game.ready();
          final ammo = game.gameState.noOfBullets;
          game.weaponJoystick.delta.setValues(60, 0);
          game.spawnShotgunBullets();
          game.weaponJoystick.delta.setZero();
          await game.ready();
          final shots = game.world.children
              .whereType<BulletComponent>()
              .toList();
          expect(shots, hasLength(type == WeaponType.shotgun ? 3 : 1));
          if (type == WeaponType.shotgun) {
            expect(shots.map((s) => s.direction.y).toSet(), hasLength(3));
            expect(shots[1].direction.y, closeTo(0, .001));
            expect(
              shots.first.direction.y,
              closeTo(-shots.last.direction.y, .001),
            );
          }
          if (type == WeaponType.carbine) {
            final origins = <Vector2>[shots.single.position.clone()];
            final headings = <double>[shots.single.direction.y];
            for (var round = 0; round < 6; round++) {
              game.weaponJoystick.delta.setValues(60, 0);
              game.spawnShotgunBullets();
              game.weaponJoystick.delta.setZero();
              await game.ready();
              final bullet = game.world.children
                  .whereType<BulletComponent>()
                  .last;
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
                lessThan(.001),
              );
              expect(bullet.direction, heading);
              bullet.removeFromParent();
              await game.ready();
            }
            expect(headings.toSet().length, greaterThan(1));
            expect(origins.map((p) => p.y).toSet().length, greaterThan(1));
            expect(
              origins.every((p) => (p - origins.first).length < 7),
              isTrue,
            );
          }
          expect(shots.every((s) => s.weapon == type), isTrue);
          expect(
            game.gameState.noOfBullets,
            ammo - (type == WeaponType.carbine ? 7 : 1),
          );
          expect(audio.sounds, contains('shot_${type.name}_0.wav'));
          for (final shot in shots) {
            shot.update(.04);
          }
          await tester.pump();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('weapon-world')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/test-previews').create(recursive: true);
          await File('build/test-previews/rounds-${type.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
          shots[shots.length ~/ 2].update(.3);
          await game.ready();
          expect(
            game.world.children.whereType<WeaponImpact>().any(
              (f) => f.weapon == type,
            ),
            isTrue,
          );
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
            find.byKey(const Key('weapon-world')),
          );
          final refillImage = await refillBoundary.toImage(pixelRatio: 2);
          final refillBytes = await refillImage.toByteData(
            format: ui.ImageByteFormat.png,
          );
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
    },
  );

  testWidgets('damage cues track health loss, settings, protection and pause', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
          child: const MaterialApp(
            home: RepaintBoundary(key: Key('damage-world'), child: BaseView()),
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
      expect(game.damagePlayer(), isFalse); // Deployment is protected.
      game.update(2);
      game.preferences.haptics = true;
      game.preferences.reducedMotion = false;
      expect(game.damagePlayer(), isTrue);
      await tester.pump();
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(find.text('-1'), findsOneWidget);
      expect(find.byKey(const Key('health-loss-heart')), findsOneWidget);
      expect(game.damageFeedback.healthLost.value, 1);
      expect(game.damagePlayer(), isFalse); // Contact cannot spam the cue.
      expect(haptics, hasLength(1));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('damage-world')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/player-damage.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      game.pauseGame();
      final remaining = game.damageFeedback.remaining;
      game.update(.3);
      expect(game.damageFeedback.remaining, remaining);
      game.resumeGame();
      game.damageFeedback.update(.51);
      await tester.pump();
      expect(find.text('-1'), findsNothing);
      game.gameNotifier.advanceTime(.6);
      game.preferences.haptics = false;
      game.preferences.reducedMotion = true;
      expect(game.damagePlayer(), isTrue);
      await tester.pump();
      expect(haptics, hasLength(1));
      expect(game.damageFeedback.healthLost.value, 1);
      expect(find.text('-1'), findsOneWidget);
      game.restartGame();
      await game.ready();
      expect(game.damageFeedback.healthLost.value, 0);
      game.update(2);
      game.gameNotifier.resetRun(
        loadout: const Loadout(character: CharacterType.warden),
      );
      game.preferences.haptics = true;
      expect(game.damagePlayer(), isTrue); // Armour absorbs the hit.
      expect(game.damageFeedback.healthLost.value, 0);
      expect(haptics, hasLength(1));
      game.gameNotifier.advanceTime(.6);
      expect(game.damagePlayer(amount: 2), isTrue);
      expect(game.damageFeedback.healthLost.value, 2);
      await tester.pump();
      expect(find.text('-2'), findsOneWidget);
      expect(haptics, hasLength(2));
    });
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'distance damage is frame independent and secondary shots stay unchanged',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      for (final weapon in WeaponType.values) {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            ProviderScope(
              key: ValueKey(weapon),
              overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
              child: MaterialApp(
                home: BaseView(
                  loadout: Loadout(weapon: weapon, training: true),
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
          for (final distance in [50.0, 300.0, 700.0]) {
            for (final dt in [.01, 1.0]) {
              final target = Enemy2Component(
                position: Vector2(distance + 50, 0),
              );
              await game.world.add(target);
              await game.ready();
              // Place its near body surface at exactly the authored distance.
              target.position.x = distance + game.enemyRadius(target) + 5;
              final before = target.combatHealth.current;
              final bullet = BulletComponent(
                position: Vector2.zero(),
                direction: Vector2(1, 0),
                speed: 1000,
                maxTravelDistance: 1000,
                damage: 2,
                weapon: weapon,
              );
              await game.world.add(bullet);
              await game.ready();
              for (var i = 0; i < 101 && !bullet.isRemoving; i++) {
                bullet.update(dt);
              }
              expect(
                before - target.combatHealth.current,
                closeTo(
                  2 * WeaponBallistics.of(weapon).multiplier(distance),
                  .001,
                ),
                reason: '${weapon.name}, distance $distance, dt $dt',
              );
              target.removeFromParent();
              await game.ready();
            }
          }
          final secondaryTarget = Enemy2Component(position: Vector2(100, 0));
          await game.world.add(secondaryTarget);
          await game.ready();
          final health = secondaryTarget.combatHealth.current;
          final secondary = BulletComponent(
            position: Vector2.zero(),
            direction: Vector2(1, 0),
            damage: 2,
            primary: false,
            weapon: weapon,
          );
          await game.world.add(secondary);
          await game.ready();
          secondary.update(.3);
          expect(
            health - secondaryTarget.combatHealth.current,
            closeTo(2, .001),
          );
          secondaryTarget.removeFromParent();
          await game.ready();
          if (weapon == WeaponType.carbine) {
            final curve = WeaponBallistics.of(weapon);
            for (final ricochet in [false, true]) {
              final first = Enemy2Component(position: Vector2(200, 0));
              final second = Enemy2Component(position: Vector2(600, 0));
              await game.world.addAll([first, second]);
              await game.ready();
              final h1 = first.combatHealth.current;
              final h2 = second.combatHealth.current;
              final bullet = BulletComponent(
                position: Vector2.zero(),
                direction: Vector2(1, 0),
                damage: 1,
                speed: 1000,
                weapon: weapon,
                maxTravelDistance: 1000,
                pierce: ricochet ? 0 : 1,
                bounces: ricochet ? 1 : 0,
              );
              await game.world.add(bullet);
              await game.ready();
              bullet.update(.8);
              if (ricochet) bullet.update(.8);
              expect(
                h1 - first.combatHealth.current,
                closeTo(
                  curve.multiplier(200 - game.enemyRadius(first) - 5),
                  .001,
                ),
              );
              expect(
                h2 - second.combatHealth.current,
                closeTo(
                  (ricochet ? .7 : 1) *
                      curve.multiplier(600 - game.enemyRadius(second) - 5),
                  .001,
                ),
              );
              first.removeFromParent();
              second.removeFromParent();
              await game.ready();
            }
            final beyond = Enemy2Component(position: Vector2(650, 0));
            await game.world.add(beyond);
            await game.ready();
            final health = beyond.combatHealth.current;
            final limited = BulletComponent(
              position: Vector2.zero(),
              direction: Vector2(1, 0),
              damage: 3,
              weapon: weapon,
              maxTravelDistance: 400,
            );
            await game.world.add(limited);
            await game.ready();
            limited.update(2); // A large frame cannot hit past maximum range.
            expect(beyond.combatHealth.current, health);
            expect(limited.isRemoving, isTrue);
            beyond.removeFromParent();
            await game.ready();
          }
        });
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('held aim waits for full reloads and hostile dart pauses', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    for (final weapon in WeaponType.values.where(
      (w) => w != WeaponType.carbine && !w.usesArsenalRuntime,
    )) {
      late RegunGame game;
      final audio = _Audio();
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(weapon),
            overrides: [soloudPlayProvider.overrideWithValue(audio)],
            child: MaterialApp(
              home: BaseView(loadout: Loadout(weapon: weapon, training: true)),
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
        while (game.gameState.noOfBullets > 0) {
          game.gameNotifier.decreaseBullets();
        }
        game.gameNotifier.reloadBullets();
        final fullDuration =
            (game.gameNotifier.checkpoint()['reloadDurationMs'] as num)
                .toDouble() /
            1000;
        var elapsed = 0.0;
        while (elapsed + .01 < fullDuration - .00001) {
          game.weaponJoystick.delta.setValues(60, 0);
          game.update(.01);
          elapsed += .01;
          expect(game.shotsFired, 0, reason: weapon.name);
          expect(game.gameState.noOfBullets, 0);
          expect(game.gameState.reloading, isTrue);
        }
        game.weaponJoystick.delta.setValues(60, 0);
        game.update(fullDuration - elapsed + .001);
        expect(game.shotsFired, 1, reason: weapon.name);
        expect(game.gameState.noOfBullets, weapon.capacity - 1);
        expect(game.gameState.reloading, isFalse);
        final dart = Enemy3Projectile(position: Vector2(400, 100));
        await game.world.add(dart);
        await game.ready();
        game.gameNotifier.pauseGame();
        final start = dart.position.clone();
        dart.update(1);
        expect(dart.position, start);
        game.gameNotifier.playGame();
        dart.update(.1);
        expect(dart.position.distanceTo(start), closeTo(30, .001));
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'render distinct firing and mechanical reload stages for review',
    (tester) async {
      await tester.runAsync(() async {
        await RegunArt.shared.load();
        await (FontLoader('PressStart2P')..addFont(
              rootBundle.load('assets/fonts/PressStart2P-Regular.ttf'),
            ))
            .load();
        final leased = WeaponType.values
            .where((w) => w.hasLeasedArt)
            .map((w) => w.atlasName)
            .toList();
        for (final name in leased) {
          await RegunArt.shared.acquire(name);
        }
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
                color: Color(0xffE5DDD1),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          title.paint(canvas, Offset(16, type.index * 160.0 + 12));
          for (var col = 0; col < 4; col++) {
            canvas.save();
            canvas.translate(110 + col * 210.0, type.index * 160.0 + 90);
            canvas.scale(math.min(2.6, 180 / WeaponArtSpec.of(type).width));
            paintWeapon(
              canvas,
              type,
              recoil: col == 0 ? 1 : 0,
              reload: col == 0 ? -1 : [.15, .55, .94][col - 1],
            );
            canvas.restore();
          }
        }
        canvas.save();
        canvas.translate(90, WeaponType.values.length * 160 + 40.0);
        RegunArt.shared
            .rawSprite('items/items', 0)
            .render(canvas, size: Vector2.all(72), anchor: Anchor.center);
        canvas.translate(240, 0);
        canvas.scale(3);
        Enemy3Projectile.paintDart(canvas);
        canvas.restore();
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          900,
          WeaponType.values.length * 160 + 100,
        );
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/weapon-identity.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
        for (final name in leased.reversed) {
          RegunArt.shared.release(name);
        }
      });
    },
  );
}
