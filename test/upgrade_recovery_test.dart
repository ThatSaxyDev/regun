import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_3_projectile.dart';
import 'package:regun/components/enemies/shadow_boss_component.dart';
import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/attack_vfx.dart';
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
  Future<void> playMusic(String name) async {}
  @override
  void pauseMusic(bool paused) {}
}

void main() {
  testWidgets(
    'upgrade confirmation creates room once, clears current bullets without invulnerability',
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
        game.myPlayer.aimDirection.setValues(-1,0);
        game.movementJoystick.delta.setValues(0,-70);
        game.myPlayer.weaponHeading.idle=0;
        game.myPlayer.update(.6);expect(game.myPlayer.aimDirection.x,-1);
        game.myPlayer.update(.1);expect(game.myPlayer.aimDirection.y,lessThan(0));
        game.weaponJoystick.delta.setValues(70,0);game.myPlayer.update(0);
        expect(game.myPlayer.aimDirection.x,1);
        game.resetInput();game.myPlayer.position.setZero();
        game.gameNotifier.advanceTime(3);
        game.setTrainingDamage(true);
        final enemy = Enemy2Component(position: Vector2(180, 0));
        final distant = Enemy2Component(position: Vector2(650, 0));
        final nearShot = Enemy3Projectile(position: Vector2(90, 70)),
            farShot = Enemy3Projectile(position: Vector2(650, 90));
        await game.world.addAll([enemy, distant, nearShot, farShot]);
        await game.ready();
        game.spawnBoss(BossKind.shadow);
        await game.ready();
        final boss = game.activeBoss! as ShadowBossComponent;
        boss.position.setValues(-230, 0);
        final bossAt = boss.position.clone(),
            bossHealth = boss.combatHealth.current;
        expect(game.gameNotifier.offerSupplyUpgrade(), isTrue);
        game.update(.01);
        expect(enemy.combatHealth.current, 6);
        expect(nearShot.isRemoving, isFalse);
        final token = game.gameState.offerId,
            choice = game.gameState.powerUpChoices.firstWhere(
              (p) => p != PowerUp.scrapArmour,
            );
        game.gameNotifier.applyPowerUp(choice, offerId: token);
        final pending = game.checkpoint();
        expect(pending['upgradePulsePending'], isTrue);
        game.pauseGame();
        game.update(2);
        expect(audio.sounds.where((s) => s == 'upgrade_pulse.wav'), isEmpty);
        game.resumeGame();
        game.update(0);
        await game.ready();
        expect(enemy.combatHealth.current, 5);
        expect(distant.combatHealth.current, 6);
        expect(nearShot.isRemoved || nearShot.isRemoving, isTrue);
        expect(farShot.isRemoving, isFalse);
        expect(boss.combatHealth.current, bossHealth - 1);
        expect(boss.position, bossAt);
        final before = enemy.position.clone();
        for (var i = 0; i < 15; i++) {
          game.update(1 / 60);
        }
        await game.ready();
        expect(enemy.position.x, greaterThan(before.x + 50));
        expect(audio.sounds.where((s) => s == 'upgrade_pulse.wav').length, 1);
        game.gameNotifier.applyPowerUp(choice, offerId: token);
        game.update(0);
        expect(enemy.combatHealth.current, 5);
        expect(audio.sounds.where((s) => s == 'upgrade_pulse.wav').length, 1);
        final health = game.gameState.health;
        expect(game.damagePlayer(cause: 'new incoming shot'), isTrue);
        expect(
          game.gameState.health,
          health - 1,
          reason: 'No post-upgrade invulnerability',
        );
        final lateShot = Enemy3Projectile(position: Vector2(100, 90));
        await game.world.add(lateShot);
        await game.ready();
        game.update(0);
        expect(
          lateShot.isRemoving,
          isFalse,
          reason: 'Clear is instantaneous, not an ongoing shield',
        );
        final effects = game.world.children
            .whereType<CombatEffect>()
            .where((e) => e.upgradePulse)
            .toList();
        expect(effects.length, 1);
        final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xff29292b), BlendMode.src);
        for (var i = 0; i < 3; i++) {
          canvas.save();
          canvas.translate(150 + i * 300, 150);
          AttackVfx.upgradePulse(
            canvas,
            Offset.zero,
            125,
            progress: [.1, .4, .7][i],
          );
          canvas.restore();
        }
        final picture = recorder.endRecording(),
            image = await picture.toImage(900, 300),
            bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/upgrade-pulse.png')
            .writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
        picture.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      });
      expect(tester.takeException(), isNull);
    },
  );
}
