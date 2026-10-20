import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

class _SilentAudio extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool paused) {}
}

class _DiscardStore extends RunStore {
  @override
  Future<bool> write(Map<String, dynamic> map) => Future.value(true);
  @override
  Future<void> clear({String? expectedRunId}) => Future.value();
}

void main() {
  const enabled = bool.fromEnvironment('REGUN_SOAK');
  for (final minutes in [30, 60]) {
    testWidgets('$minutes minute developed-build component soak',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late RegunGame game;
      await tester.runAsync(() async {
        await tester.pumpWidget(ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(_SilentAudio())],
            child: MaterialApp(
                home: BaseView(
                    runStore: _DiscardStore(),
                    loadout: Loadout(
                        arena: ArenaType.foundry,
                        character: CharacterType.scrapper,
                        weapon: minutes == 30
                            ? WeaponType.arcCaster
                            : WeaponType.shotgun)))));
        game = tester
            .widget<RiverpodAwareGameWidget>(
                find.byType(RiverpodAwareGameWidget))
            .game! as RegunGame;
        await game.loaded;
        await tester.pump();
        await game.ready();
        game.update(2); // Finish deployment before exercising combat.
      });
      final specials = minutes == 30
          ? [
              PowerUp.staticCharge,
              PowerUp.conductiveCore,
              PowerUp.ricochet,
              PowerUp.bankShot,
              PowerUp.orbitDrone,
              PowerUp.targetingLink
            ]
          : [
              PowerUp.hotShot,
              PowerUp.accelerant,
              PowerUp.sprintMine,
              PowerUp.fragmentation,
              PowerUp.orbitDrone,
              PowerUp.targetingLink
            ];
      final ranks = {
        for (final p in powerUps.where((p) => p.group != UpgradeGroup.special))
          p: p.maxRank,
        for (final p in specials) p: 3
      };
      final state = game.gameState.copyWith(
          ranks: ranks,
          evolutions: minutes == 30
              ? {'stormCircuit', 'pinball'}
              : {'firebreak', 'minefield'},
          maxHealth: 6,
          health: 6,
          guard: true,
          maxBullets: 9,
          noOfBullets: 9,
          bulletNumberRange: 4,
          shotDamage: 2.05,
          bulletRange: 800,
          bulletSpeed: 1300,
          fastReload: true,
          fastReloadTime: 1000,
          movementSpeed: 450,
          sprintInvincibility: true,
          bulletsPhaseThrough: true);
      game.gameNotifier.restoreCheckpoint(
          {...game.gameNotifier.checkpoint(), 'state': state.toJson()});
      game.resumeGame();
      final peak = <String, int>{};
      var peakChildren = 0;
      final clock = Stopwatch()..start();
      await tester.runAsync(() async {
        for (var frame = 0; frame < minutes * 60 * 60; frame++) {
          final seconds = frame / 60;
          game.myPlayer.position.setValues(
              math.cos(seconds * 0.18) * 850, math.sin(seconds * 0.18) * 850);
          final target = game.nearestEnemy(game.myPlayer.position);
          final direction = target == null
              ? Vector2(1, 0)
              : (target.position - game.myPlayer.position).normalized();
          game.weaponJoystick.delta.setFrom(direction * 80);
          if (frame % 60 == 0) {
            game.gameNotifier.heal(
                100); // Keep the density test alive; this is not a balance claim.
          }
          if (frame % (3 * 60) == 0) {
            game.myPlayer.dashDirection.setFrom(direction);
            game.combat.onDash();
          }
          if (frame % (30 * 60) == 0) {
            for (var i = 0; i < 40; i++) {
              game.spawnAdd(
                  [
                    EnemyKind.runner,
                    EnemyKind.shield,
                    EnemyKind.burster,
                    EnemyKind.nest,
                    EnemyKind.sentinel
                  ][i % 5],
                  game.myPlayer.position +
                      Vector2(math.cos(i), math.sin(i)) * 600);
            }
          }
          while (game.gameState.gameplayState == GameplayState.powerup) {
            if (game.gameState.evolutionChoices.isNotEmpty) {
              game.gameNotifier.fuse(game.gameState.evolutionChoices.first,
                  offerId: game.gameState.offerId);
            } else {
              game.gameNotifier.applyPowerUp(
                  game.gameState.powerUpChoices.first,
                  offerId: game.gameState.offerId);
            }
          }
          game.update(1 / 60);
          if (frame % 60 == 0) {
            await game.ready();
            for (final entry in game.runtimeCounts.entries) {
              peak[entry.key] = math.max(peak[entry.key] ?? 0, entry.value);
            }
            peakChildren = math.max(peakChildren, game.world.children.length);
          }
        }
      });
      expect(game.gameState.gameplayState, isNot(GameplayState.gameOver));
      expect(game.gameState.bosses, greaterThan(0));
      expect(peak['enemies'], lessThanOrEqualTo(120));
      expect(peak['xp'], lessThanOrEqualTo(80));
      expect(peak['playerProjectiles'], lessThanOrEqualTo(256));
      expect(peak['hostileProjectiles'], lessThanOrEqualTo(128));
      expect(peak['effects'], lessThanOrEqualTo(40));
      expect(peak['mines'], lessThanOrEqualTo(12));
      expect(peak['fire'], lessThanOrEqualTo(12));
      expect(peak['hazards'], lessThanOrEqualTo(8));
      expect(peak['particles'], lessThanOrEqualTo(256));
      expect(peakChildren, lessThan(900));
      debugPrint(
          'SOAK minutes=$minutes wallMs=${clock.elapsedMilliseconds} bosses=${game.gameState.bosses} kills=${game.gameState.kills} peaks=$peak peakChildren=$peakChildren retained=${game.world.children.length}');
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    }, skip: !enabled, timeout: const Timeout(Duration(minutes: 12)));
  }
}
