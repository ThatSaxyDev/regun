import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/data/weapon_power_balance.dart';
import 'package:regun/systems/weapon_reaction.dart';

import 'dart:io';
import 'dart:math' as math;

import 'package:regun/presentation/weapon_art_spec.dart';

import 'dart:convert';

import 'package:regun/components/weapons/weapon_art.dart';

import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'package:flutter/rendering.dart';

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/burster_walk.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/systems/arsenal_system.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/systems/freeze_state.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Audio extends SoloudPlay {
  final cues = <String>[];
  final loops = <String>{};
  @override
  Future<void> play(String asset) async {
    cues.add(asset);
  }

  @override
  Future<void> startWeaponLoop(String owner, String asset) async {
    loops.add(owner);
  }

  @override
  void stopWeaponLoop(String owner) {
    loops.remove(owner);
  }
}

class _Target extends EnemyComponent {
  final reactions = <WeaponReaction>[];
  @override
  void receiveWeaponImpact(Vector2 direction, WeaponReaction reaction) {
    reactions.add(reaction);
    super.receiveWeaponImpact(direction, reaction);
  }

  _Target(Vector2 at) : super(position: at) {
    restoreHealth(1000, maximum: 1000);
  }
  @override
  void update(double dt) {
    super.update(0);
    if (game.gameState.gameplayState == GameplayState.playing) {
      freezeState.advance(dt);
    }
  }

  @override
  double get impactResponse => .01;
}

class _PullTarget extends _Target {
  _PullTarget(super.at);
  @override
  double get impactResponse => 1;
}

class _PlantedTarget extends _Target {
  _PlantedTarget(super.at);
  @override
  double get impactResponse => 0;
}

// Controlled walk-through probe: no pursuit/force confounds ground exposure.
class _CrossingTarget extends _Target {
  _CrossingTarget(super.at, this.speed);
  final double speed;
  @override
  void update(double dt) {
    super.update(dt);
    position.x -= speed * (game.arsenal?.sporeStride(this) ?? 1) * dt;
  }
}

class _PowerProbe extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy {
  _PowerProbe(Vector2 at)
    : super(position: at, size: Vector2.all(85), anchor: Anchor.center);
  @override
  double get impactResponse => 0;
  @override
  Future<void> onLoad() async {
    initializeHealth(1000);
  }

  @override
  void onCombatDeath() {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalPreferences.shared.load();
    await RegunArt.shared.load();
    for (final font in ['PressStart2P', 'Orbitron']) {
      await (FontLoader(
        font,
      )..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf'))).load();
    }
  });
  Future<RegunGame> mount(
    WidgetTester tester,
    WeaponType weapon,
    _Audio audio, {
    CharacterType character = CharacterType.rook,
    ArenaType arena = ArenaType.breach,
  }) async {
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(audio)],
          child: MaterialApp(
            home: RepaintBoundary(
              key: const Key("weapon-review"),
              child: BaseView(
                key: ValueKey(weapon),
                loadout: Loadout(
                  weapon: weapon,
                  training: true,
                  character: character,
                  arena: arena,
                ),
              ),
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
      await game.ready();
    });
    return game;
  }

  Future<void> advance(
    RegunGame game,
    double seconds, {
    bool held = true,
  }) async {
    for (var t = 0.0; t < seconds - 1e-7; t += .025) {
      game.weaponJoystick.delta.setValues(held ? 70 : 0, 0);
      game.update((seconds - t).clamp(0, .025));
      await game.ready();
    }
    if (held && game.loadout.weapon.firesOnRelease) {
      game.arsenal!.releaseAim(Vector2(1, 0));
      game.weaponJoystick.delta.setZero();
      for (
        var i = 0;
        i < (game.loadout.weapon == WeaponType.anchorEngine ? 84 : 40);
        i++
      ) {
        game.update(.025);
        await game.ready();
      }
    }
  }

  void grant(RegunGame game, PowerUp power) {
    final snapshot = game.gameNotifier.checkpoint();
    snapshot['state'] = game.gameState
        .copyWith(
          gameplayState: GameplayState.powerup,
          powerUpChoices: [power],
          evolutionChoices: const [],
          offerId: game.gameState.offerId + 1,
        )
        .toJson();
    game.gameNotifier.restoreCheckpoint(snapshot);
    game.gameNotifier.playGame();
    game.gameNotifier.applyPowerUp(power, offerId: game.gameState.offerId);
  }

  testWidgets(
    'new Pump blast kills a fresh close Mummy without extra pellets',
    (tester) async {
      final game = await mount(tester, WeaponType.shotgun, _Audio());
      await tester.runAsync(() async {
        game.geometry = ArenaGeometry(game.map.bounds, obstacles: []);
        final mummy = Enemy2Component(
          position: game.myPlayer.position + Vector2(130, 0),
        );
        game.world.add(mummy);
        await game.ready();
        expect(mummy.combatHealth.current, 6);
        game.weaponJoystick.delta.setValues(70, 0);
        expect(game.spawnShotgunBullets(), true);
        game.weaponJoystick.delta.setZero();
        await advance(game, .5, held: false);
        expect(mummy.combatHealth.isDead, true);
        expect(game.shotsFired, 1);
        expect(game.gameState.noOfBullets, 4);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final weapon in [
    WeaponType.scrapMortar,
    WeaponType.rivetDriver,
    WeaponType.cinderHose,
    WeaponType.prismCutter,
  ]) {
    testWidgets('${weapon.name} paid damage survives forty cosmetic effects', (
      tester,
    ) async {
      final game = await mount(tester, weapon, _Audio());
      await tester.runAsync(() async {
        game.geometry = ArenaGeometry(game.map.bounds, obstacles: []);
        final landing = weapon == WeaponType.scrapMortar
            ? game.arsenal!.mortarTarget(
                Vector2(1, 0),
                released: Vector2(.4, 0),
              )
            : game.myPlayer.position + Vector2(130, 0);
        final target = _Target(landing);
        game.world.add(target);
        await game.ready();
        for (var i = 0; i < 40; i++) {
          game.addCombatEffect(
            CombatEffect(
              position: game.myPlayer.position.clone(),
              duration: 10,
            ),
          );
        }
        await game.ready();
        expect(game.runtimeCounts['effects'], 40);
        final ammo = game.gameState.noOfBullets;
        if (weapon == WeaponType.scrapMortar) {
          expect(game.arsenal!.releaseAim(Vector2(.4, 0)), true);
          await advance(game, .3, held: false);
          expect(target.combatHealth.current, 1000);
          await advance(game, .7, held: false);
          expect(1000 - target.combatHealth.current, closeTo(7.5, .001));
          expect(game.arsenal!.flights, isEmpty);
          await advance(game, .5, held: false);
          expect(1000 - target.combatHealth.current, closeTo(7.5, .001));
        } else if (weapon == WeaponType.rivetDriver) {
          await advance(game, .025);
          await advance(game, .25, held: false);
          expect(game.arsenal!.rivets.length, 1);
          game.requestReload();
          await advance(game, .3, held: false);
          expect(1000 - target.combatHealth.current, closeTo(3.25, .001));
          expect(game.arsenal!.rivets, isEmpty);
        } else {
          await advance(game, .125);
          expect(target.combatHealth.current, lessThan(1000));
        }
        expect(game.gameState.noOfBullets, lessThan(ammo));
        expect(game.runtimeCounts['effects'], lessThanOrEqualTo(40));
      });
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'Spore coverage slows without stacking and clears on exit cover expiry and pause',
    (tester) async {
      final game = await mount(tester, WeaponType.sporeLobber, _Audio());
      await tester.runAsync(() async {
        game.geometry = ArenaGeometry(game.map.bounds, obstacles: []);
        final center = game.myPlayer.position + Vector2(400, 0),
            body = _PullTarget(game.myPlayer.position + Vector2(400, 0));
        game.world.add(body);
        await game.ready();
        final s = game.arsenal!;
        s.patches.addAll([
          SporePatch(1, center.clone(), s.balance.sporeDps),
          SporePatch(2, center.clone(), s.balance.sporeDps),
        ]);
        s.nextAttack = 3;
        await advance(game, .025, held: false);
        expect(s.sporeStride(body), .75);
        final before = body.position.clone();
        game.moveActor(body, Vector2(0, 1), 60, 1);
        expect(body.position.y - before.y, closeTo(45, .01));
        body.receiveWeaponImpact(
          Vector2(1, 0),
          const WeaponReaction(0, .2, slow: .9),
        );
        final braked = body.position.clone();
        game.moveActor(body, Vector2(0, 1), 60, .1);
        expect(body.position.y - braked.y, lessThan(2));
        body.position.setFrom(center + Vector2(250, 0));
        expect(s.sporeStride(body), 1);
        body.position.setFrom(center + Vector2(40, 0));
        game.geometry = ArenaGeometry(
          game.map.bounds,
          obstacles: [Rect.fromLTWH(center.x + 10, center.y - 50, 10, 100)],
        );
        expect(s.sporeStride(body), 1);
        game.geometry = ArenaGeometry(game.map.bounds, obstacles: []);
        body.position.setFrom(center);
        final duration = s.patches.first.remaining;
        game.pauseGame();
        game.update(1);
        expect(s.patches.first.remaining, duration);
        game.gameNotifier.playGame();
        final health = body.combatHealth.current;
        await advance(game, .25, held: false);
        expect(health - body.combatHealth.current, closeTo(.6, .001));
        // Identical overlaps neither double damage nor compound braking.
        expect(s.sporeStride(body), .75);
        for (final patch in s.patches) {
          patch.remaining = 0;
        }
        expect(s.sporeStride(body), 1);
        await advance(game, .025, held: false);
        expect(s.patches, isEmpty);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Spore resists elites and planted bodies and does not retime a committed leap',
    (tester) async {
      final game = await mount(tester, WeaponType.sporeLobber, _Audio());
      await tester.runAsync(() async {
        game.geometry = ArenaGeometry(game.map.bounds, obstacles: []);
        final center = game.myPlayer.position + Vector2(400, 0);
        final elite = ArenaEnemy(
          EnemyKind.burster,
          elite: true,
          position: center + Vector2(-60, -60),
        );
        final nest = ArenaEnemy(
          EnemyKind.nest,
          position: center + Vector2(60, 60),
        );
        final body = _PullTarget(center + Vector2(60, -60));
        game.world.addAll([elite, nest, body]);
        await game.ready();
        game.arsenal!.patches.add(SporePatch(1, center, 2.4));
        await advance(game, .025, held: false);
        expect(game.arsenal!.sporeStride(elite), .85);
        expect(game.arsenal!.sporeStride(nest), 1);
        final before = body.position.clone();
        game.moveActor(body, Vector2(1, 0), 60, .2, avoidCrowd: false);
        expect(body.position.x - before.x, closeTo(12, .01));
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'weapon balance Continue preserves legacy numbers and paid patches exactly',
    (tester) async {
      final game = await mount(tester, WeaponType.sporeLobber, _Audio());
      await tester.runAsync(() async {
        final s = game.arsenal!;
        s.patches.add(
          SporePatch(1, game.myPlayer.position + Vector2(200, 0), 2.4)
            ..remaining = 2.8,
        );
        s.nextAttack = 2;
        final fresh = game.checkpoint();
        expect(RunCheckpoint.valid(fresh), true);
        game.gameNotifier.restoreCheckpoint(fresh);
        s.restore(Map<String, dynamic>.from(fresh['arsenal'] as Map));
        expect(s.patches.single.damage, 2.4);
        expect(s.patches.single.remaining, 2.8);
        expect(s.balance.sporeRadius, 150);
        final old = jsonDecode(jsonEncode(fresh)) as Map<String, dynamic>;
        old.remove('weaponPowerBalance');
        old.remove('balanceSnapshot');
        final oldArsenal = old['arsenal'] as Map<String, dynamic>;
        oldArsenal.remove('powerBalance');
        oldArsenal['patches'][0]['damage'] = .8;
        oldArsenal['patches'][0]['remaining'] = 2.0;
        expect(RunCheckpoint.valid(old), true);
        game.gameNotifier.restoreCheckpoint(old);
        s.restore(oldArsenal);
        expect(s.balance.damage(WeaponType.shotgun), 1.2);
        expect(s.balance.damage(WeaponType.sporeLobber), .5);
        expect(s.balance.sporeRadius, 100);
        expect(s.patches.single.damage, .8);
        expect(s.patches.single.remaining, 2);
        // Re-saving and reloading does not convert or multiply an old paid field.
        final roundTrip = game.checkpoint();
        game.gameNotifier.restoreCheckpoint(roundTrip);
        s.restore(Map<String, dynamic>.from(roundTrip['arsenal'] as Map));
        expect(s.patches.single.damage, .8);
        final invalid =
            jsonDecode(jsonEncode(roundTrip)) as Map<String, dynamic>;
        invalid['weaponPowerBalance'] = 2;
        expect(RunCheckpoint.valid(invalid), false);
        invalid['weaponPowerBalance'] = 3;
        expect(RunCheckpoint.valid(invalid), false);
        game.gameNotifier.resetRun(loadout: game.loadout);
        expect(game.gameNotifier.weaponPower.revision, 3);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'audit all 21 real weapon paths before and after the numerical revision',
    (tester) async {
      final rows = <Map<String, dynamic>>[];
      for (final balance in [
        WeaponPowerBalance.legacy,
        WeaponPowerBalance.current,
      ]) {
        for (final weapon in WeaponType.values) {
          final game = await mount(tester, weapon, _Audio());
          await tester.runAsync(() async {
            game.gameNotifier.weaponPower = balance;
            game.preferences.aimAssist = false;
            game.geometry = ArenaGeometry(game.map.bounds, obstacles: []);
            final distance =
                {
                  WeaponType.shotgun,
                  WeaponType.frostShotgun,
                  WeaponType.cinderHose,
                  WeaponType.cycloneBreacher,
                }.contains(weapon)
                ? 130.0
                : 300.0;
            final target = _PowerProbe(
              game.myPlayer.position + Vector2(distance, 0),
            );
            game.world.add(target);
            await game.ready();
            final startingAmmo = game.gameState.noOfBullets;
            if (!weapon.usesArsenalRuntime && weapon != WeaponType.burstRifle) {
              game.weaponJoystick.delta.setValues(70, 0);
              expect(game.spawnShotgunBullets(), true);
              game.weaponJoystick.delta.setZero();
            } else if (weapon.firesOnRelease) {
              final minRange = math.max(
                55.0,
                WeaponArtSpec.of(weapon)
                        .releaseOffset(const Offset(1, 0))
                        .distance +
                    12,
              );
              final strength =
                  ((distance - minRange) /
                          (game.arsenal!.effectiveRange - minRange))
                      .clamp(0.0, 1.0);
              final input =
                  game.controls.deadZone +
                  strength * (1 - game.controls.deadZone);
              expect(game.arsenal!.releaseAim(Vector2(input, 0)), true);
            } else {
              await advance(
                game,
                weapon == WeaponType.ringCaster
                    ? .8
                    : weapon == WeaponType.railLance
                    ? .66
                    : weapon == WeaponType.beltRepeater
                    ? .425
                    : weapon == WeaponType.burstRifle
                    ? .225
                    : weapon == WeaponType.cinderHose
                    ? .225
                    : .025,
              );
            }
            await advance(game, 4, held: false);
            final damage = 1000 - target.combatHealth.current;
            expect(
              damage,
              greaterThan(0),
              reason: '${weapon.name} revision${balance.revision}',
            );
            rows.add({
              'revision': balance.revision,
              'weapon': weapon.name,
              'distance': distance,
              'damageAfter4s': damage,
              'unitsSpent': startingAmmo - game.gameState.noOfBullets,
              'shotCount': game.shotsFired,
              'effects': game.runtimeCounts['effects'],
            });
          });
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
      await tester.runAsync(() async {
        await Directory('build/balance-review').create(recursive: true);
        await File('build/balance-review/all-weapon-power-revisions.json')
            .writeAsString(
              const JsonEncoder.withIndent('  ').convert({
                'scope': 'Stationary unarmored Rook target; one round/charged shot/burst or short continuous sample and finite secondary completion. Not equal trigger time or a DPS/win-rate comparison. All21 paths use their actual runtime, including burn/echo/return.',
                'rows': rows,
              }),
            );
      });
    },
  );

  testWidgets(
    'a base Spore field kills an ordinary pursuing Mummy without primary procs',
    (tester) async {
      final game = await mount(tester, WeaponType.sporeLobber, _Audio());
      await tester.runAsync(() async {
        game.geometry = ArenaGeometry(game.map.bounds, obstacles: []);
        final at = game.myPlayer.position + Vector2(400, 0);
        final mummy = Enemy2Component(position: at.clone());
        game.world.add(mummy);
        await game.ready();
        game.arsenal!.patches.add(
          SporePatch(1, at, game.arsenal!.balance.sporeDps),
        );
        game.arsenal!.nextAttack = 2;
        await advance(game, 1, held: false);
        expect(mummy.position.x, greaterThan(at.x - 75));
        expect(mummy.combatHealth.current, lessThan(4.3));
        expect(mummy.burning, false);
        expect(mummy.marked, false);
        await advance(game, 1.8, held: false);
        expect(mummy.combatHealth.isDead, true);
        expect(game.shotsFired, 0);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a lethal Bell echo can unregister the final boss safely', (
    tester,
  ) async {
    final game = await mount(tester, WeaponType.mourningBell, _Audio());
    await tester.runAsync(() async {
      game.practiceBoss(BossKind.bellkeeper);
      await game.ready();
      final boss = game.activeBoss!;
      boss.position.setFrom(
        game.arsenal!.muzzle(Vector2(1, 0)) + Vector2(100, 0),
      );
      (boss as CombatEnemy).restoreHealth(8);
      game.weaponJoystick.delta.setValues(70, 0);
      game.arsenal!.advance(.01);
      game.weaponJoystick.delta.setZero();
      expect(boss.combatHealth.current, 2);
      await advance(game, .6, held: false);
      expect(boss.combatHealth.isDead, true);
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('four overlapping fields retain the twelve-target damage bound', (
    tester,
  ) async {
    final game = await mount(tester, WeaponType.sporeLobber, _Audio());
    await tester.runAsync(() async {
      game.geometry = ArenaGeometry(game.map.bounds, obstacles: []);
      final center = game.myPlayer.position + Vector2(500, 0);
      final targets = [
        for (var i = 0; i < 13; i++)
          _PowerProbe(
            center + Vector2((i % 4 - 1.5) * 80, (i ~/ 4 - 1.5) * 80),
          ),
      ];
      game.world.addAll(targets);
      await game.ready();
      // Deliberately saturate one footprint after occupancy's spawn placement;
      // this verifies contact selection rather than the crowd placer.
      for (var i = 0; i < targets.length; i++) {
        targets[i].position.setFrom(
          center + Vector2((i % 4 - 1.5) * 80, (i ~/ 4 - 1.5) * 80),
        );
      }
      for (var i = 0; i < 4; i++) {
        game.arsenal!.patches.add(SporePatch(i + 1, center.clone(), 2.4));
      }
      game.arsenal!.nextAttack = 5;
      await advance(game, .275, held: false);
      expect(targets.where((e) => e.combatHealth.current < 1000).length, 12);
      for (final target in targets.where(
        (e) => e.combatHealth.current < 1000,
      )) {
        expect(1000 - target.combatHealth.current, closeTo(.6, .001));
      }
      expect(game.arsenal!.patches.length, 4);
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Rail sight follows charge direction and cover without spending ammo',
    (tester) async {
      final game = await mount(tester, WeaponType.railLance, _Audio());
      await tester.runAsync(() async {
        game.preferences.aimAssist = false;
        expect(game.arsenal!.targetingBeam, isNull);
        await advance(game, .20);
        game.weaponJoystick.delta.setValues(70, 0);
        final sight = game.arsenal!.targetingBeam!;
        expect(game.shotsFired, 0);
        expect(game.gameState.noOfBullets, 3);
        expect(sight.$2.y, closeTo(sight.$1.y, .001));
        final sightRecorder = ui.PictureRecorder(),
            sightCanvas = Canvas(sightRecorder);
        for (var panel = 0; panel < 2; panel++) {
          game.geometry = ArenaGeometry(
            game.map.bounds,
            obstacles: panel == 0
                ? []
                : [Rect.fromLTWH(sight.$1.x + 350, sight.$1.y - 80, 50, 160)],
          );
          sightCanvas.save();
          sightCanvas.translate(0, panel * 220.0);
          sightCanvas.clipRect(const Rect.fromLTWH(0, 0, 800, 220));
          Sprite(RegunArt.shared.image('arenas/breach_floor'))
              .render(sightCanvas, size: Vector2(800, 220));
          sightCanvas.translate(
            100 - game.myPlayer.position.x * .65,
            110 - game.myPlayer.position.y * .65,
          );
          sightCanvas.scale(.65);
          if (panel == 1) {
            sightCanvas.drawRect(
              Rect.fromLTWH(sight.$1.x + 350, sight.$1.y - 80, 50, 160),
              Paint()..color = const Color(0xff353A32),
            );
          }
          game.world.children
              .whereType<ArsenalOverlay>()
              .firstWhere((e) => e.floor)
              .render(sightCanvas);
          game.myPlayer.renderTree(sightCanvas);
          sightCanvas.restore();
        }
        final sightPicture = sightRecorder.endRecording(),
            sightImage = await sightPicture.toImage(800, 440);
        final sightData = await sightImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/rail-lance-sight.png')
            .writeAsBytes(sightData!.buffer.asUint8List());
        sightImage.dispose();
        sightPicture.dispose();
        final wall = Rect.fromLTWH(sight.$1.x + 150, sight.$1.y - 60, 40, 120);
        game.geometry = ArenaGeometry(game.map.bounds, obstacles: [wall]);
        final clipped = game.arsenal!.targetingBeam!;
        expect(clipped.$2.x, closeTo(wall.left, .2));
        game.geometry = ArenaGeometry(
          game.map.bounds,
          obstacles: [
            Rect.fromLTWH(
              game.myPlayer.position.x + 5,
              game.myPlayer.position.y - 80,
              10,
              160,
            ),
          ],
        );
        expect(game.arsenal!.targetingBeam, isNull);
        expect(game.gameState.noOfBullets, 3);
        game.geometry = ArenaGeometry(game.map.bounds, obstacles: [wall]);
        await advance(game, .50);
        expect(game.shotsFired, 1);
        expect(game.gameState.noOfBullets, 2);
        await advance(game, .01, held: false);
        expect(game.arsenal!.targetingBeam, isNull);
        game.weaponJoystick.delta.setValues(70, 0);
        game.gameNotifier.reloadBullets(manual: true);
        expect(game.arsenal!.targetingBeam, isNull);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('record real base shot damage and spore walk-through exposure', (
    tester,
  ) async {
    final report = <String, dynamic>{
      'scope': 'unupgraded Rook, no defenses, controlled target; not a full-run win test',
      'singleRelease': <Map<String, dynamic>>[],
      'sporeCrossing': <Map<String, dynamic>>[],
    };
    for (final weapon in [
      WeaponType.shotgun,
      WeaponType.carbine,
      WeaponType.revolver,
      WeaponType.railLance,
      WeaponType.scrapMortar,
      WeaponType.sporeLobber,
      WeaponType.anchorEngine,
    ]) {
      for (final distance
          in weapon == WeaponType.shotgun ? [130.0, 330.0] : [300.0]) {
        final game = await mount(tester, weapon, _Audio());
        await tester.runAsync(() async {
          game.preferences.aimAssist = false;
          game.gameNotifier.weaponPower = WeaponPowerBalance.legacy;
          game.geometry = ArenaGeometry(game.map.bounds, obstacles: []);
          final target = _Target(game.myPlayer.position + Vector2(distance, 0));
          game.world.add(target);
          await game.ready();
          if (!weapon.usesArsenalRuntime) {
            game.weaponJoystick.delta.setValues(70, 0);
            expect(game.spawnShotgunBullets(), true);
            game.weaponJoystick.delta.setZero();
          } else if (weapon == WeaponType.railLance) {
            await advance(game, .66);
          } else {
            final minRange = math.max(
              55.0,
              WeaponArtSpec.of(weapon)
                      .releaseOffset(const Offset(1, 0))
                      .distance +
                  12,
            );
            final strength =
                ((distance - minRange) /
                        (game.arsenal!.effectiveRange - minRange))
                    .clamp(0.0, 1.0);
            final input =
                game.controls.deadZone +
                strength * (1 - game.controls.deadZone);
            expect(game.arsenal!.releaseAim(Vector2(input, 0)), true);
          }
          await advance(game, 4, held: false);
          final damage = 1000 - target.combatHealth.current;
          expect(damage, greaterThan(0), reason: weapon.name);
          (report['singleRelease'] as List).add({
            'weapon': weapon.name,
            'distance': distance,
            'damage': damage,
            'mummyHealthCycle1': 6,
            'mummyHealthCycle2': 9.9,
          });
        });
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    for (final speed in [0.0, 60.0, 90.0, 105.0]) {
      final game = await mount(tester, WeaponType.sporeLobber, _Audio());
      await tester.runAsync(() async {
        game.gameNotifier.weaponPower = WeaponPowerBalance.legacy;
        game.geometry = ArenaGeometry(game.map.bounds, obstacles: []);
        final center = game.myPlayer.position + Vector2(350, 0);
        final target = _CrossingTarget(
          center + Vector2(speed == 0 ? 0 : 45, 0),
          speed,
        );
        game.world.add(target);
        await game.ready();
        game.arsenal!.patches.add(SporePatch(987, center, .8, lifetime: 2.5));
        await advance(game, 2.6, held: false);
        (report['sporeCrossing'] as List).add({
          'speed': speed,
          'damage': 1000 - target.combatHealth.current,
          'movementMultiplier': target.impactStride,
        });
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.runAsync(() async {
      await Directory('build/balance-review').create(recursive: true);
      await File('build/balance-review/current-weapon-damage.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    });
  });

  testWidgets(
    'primary stick releases one sniper shot and cancellation spends nothing',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = await mount(tester, WeaponType.longwatchSniper, _Audio());
      game.update(1 / 60);
      await tester.pump();
      final factor = game.canvasSize.y / game.camera.viewport.virtualSize.y;
      final inset =
          (game.canvasSize - game.camera.viewport.virtualSize * factor) / 2;
      final at = (game.weaponJoystick.position * factor + inset).toOffset();
      final aim = await tester.startGesture(at, pointer: 81);
      await aim.moveBy(const Offset(32, 0));
      await aim.moveBy(const Offset(10, 0));
      game.update(.02);
      expect(game.shotsFired, 0);
      await aim.up();
      game.update(.02);
      expect(game.shotsFired, 1);
      await tester.runAsync(() async {
        await advance(game, 1.2, held: false);
      });
      final cancelled = await tester.startGesture(at, pointer: 82);
      await cancelled.moveBy(const Offset(32, 0));
      await cancelled.moveBy(const Offset(10, 0));
      game.update(.02);
      await cancelled.cancel();
      game.update(.02);
      expect(game.shotsFired, 1);
      expect(game.gameState.noOfBullets, 4);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'primary stick quick fires Rail Lance and cancelled touches spend nothing',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = await mount(tester, WeaponType.railLance, _Audio());
      game.update(1 / 60);
      await tester.pump();
      final factor = game.canvasSize.y / game.camera.viewport.virtualSize.y;
      final inset =
          (game.canvasSize - game.camera.viewport.virtualSize * factor) / 2;
      final at = (game.weaponJoystick.position * factor + inset).toOffset();
      final aim = await tester.startGesture(at, pointer: 81);
      await aim.moveBy(const Offset(32, 0));
      await aim.moveBy(const Offset(10, 0));
      game.update(.02);
      expect(game.shotsFired, 0);
      await aim.up();
      game.update(.02);
      expect(game.shotsFired, 1);
      await tester.runAsync(() async {
        await advance(game, 1.2, held: false);
      });
      final cancelled = await tester.startGesture(at, pointer: 82);
      await cancelled.moveBy(const Offset(32, 0));
      await cancelled.moveBy(const Offset(10, 0));
      game.update(.02);
      await cancelled.cancel();
      game.update(.02);
      expect(game.shotsFired, 1);
      expect(game.gameState.noOfBullets, 2);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Cinder stream moves, leaves a fading tail and exports review frames',
    (tester) async {
      final game = await mount(tester, WeaponType.cinderHose, _Audio());
      for (var frame = 0; frame < 8; frame++) {
        await tester.runAsync(() async {
          await advance(game, .1, held: frame < 5);
        });
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('weapon-review')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/test-previews').create(recursive: true);
          await File('build/test-previews/cinder-flow-$frame.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        if (frame == 4) expect(game.arsenal!.flame.tongues, isNotEmpty);
      }
      await tester.runAsync(() async {
        await advance(game, 1, held: false);
      });
      expect(game.arsenal!.flame.tongues, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('freeze cannot be refreshed by overlapping pellets and carries thaw immunity through saves', () {
    final f = FreezeState();
    expect(f.apply(), true);
    expect(f.apply(), false);
    f.advance(.6);
    expect(f.frozen, false);
    expect(f.held, true);
    expect(f.apply(), false);
    final copy = FreezeState()..restore(f.toJson());
    copy.advance(.2);
    expect(copy.held, false);
    expect(copy.apply(), false);
    copy.advance(1);
    expect(copy.apply(), true);
    expect(
      () => FreezeState().restore({
        'remaining': double.nan,
        'recovery': 0,
        'immunity': 0,
      }),
      throwsFormatException,
    );
  });
  test(
    'all twenty-one have meaningful upgrade capabilities and packaged cues',
    () {
      expect(WeaponType.values.length, 24);
      for (final w in WeaponType.values) {
        for (final p in PowerUp.values) {
          if (!weaponSupportsPowerUp(w, p)) {
            expect(
              eligiblePowerUps(GameState(), weapon: w),
              isNot(contains(p)),
              reason: "${w.name}/${p.name}",
            );
          }
        }
        for (final cue in ['shot_${w.name}_0.wav', 'impact_${w.name}.wav']) {
          expect(File('assets/audio/$cue').existsSync(), true, reason: cue);
        }
      }
      expect(
        weaponSupportsPowerUp(WeaponType.longwatchSniper, PowerUp.ricochet),
        false,
      );
      expect(
        weaponSupportsPowerUp(WeaponType.prismCutter, PowerUp.quickTrigger),
        false,
      );
      expect(
        weaponSupportsPowerUp(
          WeaponType.frostShotgun,
          PowerUp.numberOfBulletsPerShotIncrease,
        ),
        true,
      );
    },
  );
  testWidgets(
    'Twin Verdict pairs once, breaks on miss/reload and separates barrels',
    (tester) async {
      final game = await mount(tester, WeaponType.twinVerdict, _Audio());
      await tester.runAsync(() async {
        final target = _Target(game.myPlayer.position + Vector2(140, 0));
        game.world.add(target);
        await game.ready();
        await advance(game, .55);
        game.weaponJoystick.delta.setZero();
        await advance(game, .2, held: false);
        expect(1000 - target.combatHealth.current, closeTo(8.4, 1e-6));
        final endgame = game.arsenal!.endgame;
        endgame.acceptPair(target, 100);
        expect(endgame.pairMultiplier(target, 101), 1.8);
        endgame.acceptPair(target, 101);
        expect(endgame.pairMultiplier(target, 101), 1);
        expect(endgame.pairMultiplier(target, 102), 1);
        endgame.acceptPair(target, 102);
        endgame.miss(103);
        expect(endgame.pairMultiplier(target, 105), 1);
        endgame.acceptPair(target, 104);
        game.requestReload();
        game.arsenal!.advance(.02);
        expect(endgame.pairMultiplier(target, 105), 1);
        endgame.acceptPair(target, 106);
        expect(endgame.pairMultiplier(target, 107), 1);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Twin brands then shatters once into two cover-respecting secondary victims',
    (tester) async {
      final audio = _Audio();
      final game = await mount(tester, WeaponType.twinVerdict, audio);
      await tester.runAsync(() async {
        final at = game.myPlayer.position, host = _Target(at + Vector2(150, 0));
        final others = [
          _Target(at + Vector2(250, 24)),
          _Target(at + Vector2(300, -36)),
          _Target(at + Vector2(330, 43)),
        ];
        final outsider = _Target(at + Vector2(150, 170));
        await game.world.addAll([host, ...others, outsider]);
        await game.ready();
        await advance(game, .55);
        await advance(game, .2, held: false);
        expect(host.combatHealth.current, closeTo(991.6, 1e-6));
        expect(
          others
              .take(2)
              .every((t) => (t.combatHealth.current - 997.84).abs() < 1e-6),
          true,
        );
        expect(others.last.combatHealth.current, 1000);
        expect(outsider.combatHealth.current, 1000);
        expect(game.shotsFired, 2);
        final s = game.arsenal!, origin = host.position.clone();
        game.geometry = ArenaGeometry(
          game.geometry.bounds,
          obstacles: [Rect.fromLTWH(origin.x + 50, origin.y - 150, 20, 300)],
        );
        s.endgame.acceptPair(host, 100, direction: Vector2(1, 0), amount: 2.5);
        s.endgame.acceptPair(host, 101, direction: Vector2(1, 0), amount: 4.5);
        expect(others.first.combatHealth.current, closeTo(997.84, 1e-6));
        // The same original shot cannot create another burst through a ricochet.
        s.endgame.acceptPair(host, 101, direction: Vector2(1, 0), amount: 4.5);
        expect(others.first.combatHealth.current, closeTo(997.84, 1e-6));
        expect(audio.loops, isEmpty);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Twin opening kill cocks the opposite barrel without an unbounded kill chain',
    (tester) async {
      final audio = _Audio();
      final game = await mount(tester, WeaponType.twinVerdict, audio);
      await tester.runAsync(() async {
        final at = game.myPlayer.position;
        final weak = _Target(at + Vector2(150, 0)),
            next = _Target(at + Vector2(260, 0)),
            spill = _Target(at + Vector2(350, 0));
        await game.world.addAll([weak, next, spill]);
        await game.ready();
        weak.restoreHealth(2);
        await advance(game, .55);
        await advance(game, .2, held: false);
        expect(weak.combatHealth.isDead, true);
        expect(next.combatHealth.current, closeTo(994.6, 1e-6));
        expect(spill.combatHealth.current, closeTo(997.84, 1e-6));
        expect(
          audio.cues.where((c) => c == 'verdict_twinVerdict.wav').length,
          1,
        );
        expect(game.arsenal!.endgame.brandReady, false);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Flak bursts immediately on a sub-pixel range remainder and only once',
    (tester) async {
      final audio = _Audio();
      final game = await mount(tester, WeaponType.flakRegent, audio);
      await tester.runAsync(() async {
        final s = game.arsenal!;
        final f =
            ArsenalFlight(
                1,
                ArsenalFlightKind.flak,
                Vector2(1200, 50),
                Vector2(1, 0),
                2.4,
                1050,
                650,
              )
              ..patchDamage = .45
              ..travelled = 649.99998;
        s.flights.add(f);
        s.nextAttack = 2;
        await advance(game, .025, held: false);
        expect(f.spent, true);
        expect(s.flights, isEmpty);
        final count = game.projectileCount;
        s.endgame.advanceFlak(f, .2);
        expect(game.projectileCount, count);
        await advance(game, .3, held: false);
        expect(game.projectileCount, 0);
        expect(audio.loops, isEmpty);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'player Guard adds one quiet foot badge with no surrounding chain fragments',
    (tester) async {
      final game = await mount(tester, WeaponType.flakRegent, _Audio());
      await tester.runAsync(() async {
        Future<ui.Image> render() async {
          final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
          canvas.drawColor(const Color(0xff242B25), BlendMode.src);
          game.myPlayer.render(canvas);
          final picture = recorder.endRecording();
          final image = await picture.toImage(100, 100);
          picture.dispose();
          return image;
        }

        final plain = await render();
        final saved = game.gameNotifier.checkpoint();
        saved['state'] = game.gameState.copyWith(guard: true).toJson();
        game.gameNotifier.restoreCheckpoint(saved);
        final guarded = await render();
        final a = (await plain.toByteData())!.buffer.asUint8List(),
            b = (await guarded.toByteData())!.buffer.asUint8List();
        var changed = 0;
        for (var y = 0; y < 100; y++) {
          for (var x = 0; x < 100; x++) {
            final at = (y * 100 + x) * 4;
            if (a[at] != b[at] ||
                a[at + 1] != b[at + 1] ||
                a[at + 2] != b[at + 2]) {
              changed++;
              expect(x, inInclusiveRange(75, 91));
              expect(y, inInclusiveRange(71, 87));
            }
          }
        }
        expect(changed, greaterThan(20));
        await Directory('build/test-previews').create(recursive: true);
        final png = await guarded.toByteData(format: ui.ImageByteFormat.png);
        await File('build/test-previews/player-guard-clean.png')
            .writeAsBytes(png!.buffer.asUint8List());
        plain.dispose();
        guarded.dispose();
        expect(game.gameState.guard, true);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Bell exports initial and echo pressure fronts without changing committed hits',
    (tester) async {
      final game = await mount(tester, WeaponType.mourningBell, _Audio());
      await tester.runAsync(() async {
        final at = game.myPlayer.position;
        await game.world.addAll([
          for (var i = 0; i < 3; i++)
            _Target(at + Vector2(240, (i - 1) * 80.0)),
        ]);
        await game.ready();
        await advance(game, .06);
        game.weaponJoystick.delta.setZero();
      });
      for (var frame = 0; frame < 2; frame++) {
        if (frame == 1) {
          await tester.runAsync(() async {
            await advance(game, .55, held: false);
          });
        }
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('weapon-review')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.5),
              bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/test-previews/bell-pressure-$frame.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Flak reserves all four fragments before ammo and excludes the direct owner',
    (tester) async {
      final game = await mount(tester, WeaponType.flakRegent, _Audio());
      await tester.runAsync(() async {
        final added = <BulletComponent>[];
        for (var i = 0; i < RegunGame.maxProjectiles - 3; i++) {
          final bullet = BulletComponent(
            position: game.myPlayer.position.clone(),
            direction: Vector2(1, 0),
            speed: 0,
            damage: 0,
          );
          expect(game.addProjectile(bullet), true);
          added.add(bullet);
        }
        await game.ready();
        game.weaponJoystick.delta.setValues(70, 0);
        game.arsenal!.advance(.01);
        expect(game.shotsFired, 0);
        expect(game.gameState.noOfBullets, 16);
        for (final b in added) {
          b.removeFromParent();
        }
        await game.ready();
        final target = _Target(game.myPlayer.position + Vector2(140, 0));
        game.world.add(target);
        await game.ready();
        game.arsenal!.advance(.01);
        game.weaponJoystick.delta.setZero();
        expect(game.arsenal!.projectileReservations, 4);
        await advance(game, .8, held: false);
        expect(1000 - target.combatHealth.current, closeTo(3, 1e-6));
        expect(game.arsenal!.flights, isEmpty);
        expect(game.projectileCount, 0);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Anchor overlap pulls one bounded intent, leaves planted bodies and saves crush once',
    (tester) async {
      final game = await mount(tester, WeaponType.anchorEngine, _Audio());
      await tester.runAsync(() async {
        // Isolate the measured pull from ambient practice body occupancy.
        final center = game.myPlayer.position + Vector2(700, 0);
        final mobile = _PullTarget(center + Vector2(120, 0));
        final planted = _PlantedTarget(center + Vector2(0, 130));
        await game.world.addAll([mobile, planted]);
        await game.ready();
        final start = mobile.position.clone(), fixed = planted.position.clone();
        for (var id = 1; id <= 2; id++) {
          game.arsenal!.endgame.plantAnchor(
            ArsenalFlight(
              id,
              ArsenalFlightKind.anchor,
              center.clone(),
              Vector2(1, 0),
              8,
              600,
              600,
            ),
          );
        }
        game.arsenal!.nextAttack = 3;
        await advance(game, 1, held: false);
        expect(mobile.position.distanceTo(start), inInclusiveRange(40, 55));
        expect(planted.position, fixed);
        for (final a in game.arsenal!.endgame.anchors) {
          expect(a.owners.values.every((v) => v <= 55.001), true);
        }
        await advance(game, .10, held: false);
        final hp = mobile.combatHealth.current;
        final saved = game.arsenal!.checkpoint();
        game.arsenal!.restore(saved);
        await advance(game, .45, held: false);
        expect(mobile.combatHealth.current, hp);
        game.pauseGame();
        final age = game.arsenal!.endgame.anchors.first.age;
        game.update(1);
        expect(game.arsenal!.endgame.anchors.first.age, age);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Faultline commits three sections, clips cover and preserves one-hit ledgers through Continue',
    (tester) async {
      final game = await mount(tester, WeaponType.faultlineDriver, _Audio());
      await tester.runAsync(() async {
        final s = game.arsenal!, origin = s.muzzle(Vector2(1, 0));
        final near = _Target(origin + Vector2(230, 0)),
            far = _Target(origin + Vector2(500, 0));
        await game.world.addAll([near, far]);
        await game.ready();
        expect(s.releaseAim(Vector2(1, 0)), true);
        expect(near.combatHealth.current, 992);
        expect(far.combatHealth.current, 1000);
        final saved = s.checkpoint();
        s.restore(saved);
        await advance(game, .3, held: false);
        expect(near.combatHealth.current, 992);
        expect(far.combatHealth.current, 992);
        expect(s.endgame.lanes.single.owners.length, 2);
        final malformed = s.checkpoint();
        (malformed['endgame']['lanes'][0]['owners'] as List).add([
          1,
          double.nan,
        ]);
        expect(
          () => ArsenalSystem.validate(malformed, WeaponType.faultlineDriver),
          throwsFormatException,
        );
        await advance(game, 1, held: false);
        game.geometry = ArenaGeometry(
          game.geometry.bounds,
          obstacles: [Rect.fromLTWH(origin.x + 300, origin.y - 100, 40, 200)],
        );
        expect(s.releaseAim(Vector2(1, 0)), true);
        await advance(game, .3, held: false);
        expect(far.combatHealth.current, 992);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Bell echoes only original owners still in its original cone, capped at five',
    (tester) async {
      final game = await mount(tester, WeaponType.mourningBell, _Audio());
      await tester.runAsync(() async {
        final s = game.arsenal!, origin = s.muzzle(Vector2(1, 0));
        final targets = [
          for (var i = 0; i < 7; i++)
            _Target(origin + Vector2(100 + i * 25, 0)),
        ];
        final outsider = _Target(origin + Vector2(0, 250));
        await game.world.addAll([...targets, outsider]);
        await game.ready();
        game.weaponJoystick.delta.setValues(70, 0);
        s.advance(.01);
        game.weaponJoystick.delta.setZero();
        expect(s.endgame.echoes.single.owners.length, 5);
        expect(
          targets.take(5).every((t) => t.combatHealth.current == 994),
          true,
        );
        targets.first.position.setFrom(origin + Vector2(0, -300));
        outsider.position.setFrom(origin + Vector2(100, 10));
        s.restore(s.checkpoint());
        await advance(game, .6, held: false);
        expect(targets.first.combatHealth.current, 994);
        expect(targets[1].combatHealth.current, 992);
        expect(targets[1].reactions.map((r) => r.distance), [112, 34]);
        expect(outsider.combatHealth.current, 1000);
        expect(targets.last.combatHealth.current, 1000);
        final hp = targets[1].combatHealth.current;
        s.restore(s.checkpoint());
        await advance(game, .2, held: false);
        expect(targets[1].combatHealth.current, hp);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Cyclone volleys are centered, cap at nine and reserve all pellets before spending',
    (tester) async {
      final game = await mount(tester, WeaponType.cycloneBreacher, _Audio());
      await tester.runAsync(() async {
        final s = game.arsenal!;
        expect(s.pelletCount, 5);
        for (var i = 0; i < 8; i++) {
          grant(game, PowerUp.numberOfBulletsPerShotIncrease);
        }
        expect(s.pelletCount, 9);
        final bullets = <BulletComponent>[];
        for (var i = 0; i < RegunGame.maxProjectiles - 8; i++) {
          final b = BulletComponent(
            position: game.myPlayer.position.clone(),
            direction: Vector2(1, 0),
            speed: 0,
          );
          game.addProjectile(b);
          bullets.add(b);
        }
        await game.ready();
        game.weaponJoystick.delta.setValues(70, 0);
        s.advance(.01);
        expect(game.shotsFired, 0);
        expect(game.gameState.noOfBullets, 8);
        for (final b in bullets) {
          b.removeFromParent();
        }
        await game.ready();
        s.advance(.01);
        expect(game.shotsFired, 1);
        expect(game.projectileCount, 9);
        await game.ready();
        final rounds = game.world.children
            .whereType<BulletComponent>()
            .toList();
        expect(rounds.any((b) => b.direction.y.abs() < 1e-9), true);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'walking weight preserves saved/upgraded baseline and dash speed',
    (tester) async {
      final game = await mount(tester, WeaponType.anchorEngine, _Audio());
      await tester.runAsync(() async {
        expect(game.gameState.movementSpeed, 300);
        expect(game.playerWalkSpeed, 279);
        final start = game.myPlayer.position.clone();
        game.movementJoystick.delta.setValues(90, 0);
        game.myPlayer.update(.1);
        expect(game.myPlayer.position.distanceTo(start), closeTo(27.9, .001));
        final before = game.myPlayer.position.clone();
        game.boostButtonComponent.tapped = true;
        game.myPlayer.dashDirection.setValues(1, 0);
        game.myPlayer.update(.1);
        expect(game.myPlayer.position.distanceTo(before), closeTo(145, .001));
        game.boostButtonComponent.tapped = false;
        for (var i = 0; i < 8; i++) {
          grant(game, PowerUp.walkingSpeedIncrease);
        }
        expect(game.gameState.movementSpeed, 510);
        expect(game.playerWalkSpeed, closeTo(474.3, 1e-8));
        final saved = game.checkpoint();
        expect((saved['state'] as Map)['movementSpeed'], 510);
        game.pauseGame();
        expect(await game.changeTrainingWeapon(WeaponType.carbine), true);
        expect(game.gameState.movementSpeed, 510);
        expect(game.playerWalkSpeed, 510);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'render all six on three survivors in four facings and both reload modes',
    (tester) async {
      final recorder = ui.PictureRecorder(),
          reloadRecorder = ui.PictureRecorder();
      final canvas = Canvas(recorder), reloadCanvas = Canvas(reloadRecorder);
      canvas.drawColor(const Color(0xff242B25), BlendMode.src);
      reloadCanvas.drawColor(const Color(0xff242B25), BlendMode.src);
      final weapons = WeaponType.values.skip(15).toList();
      for (var row = 0; row < weapons.length; row++) {
        for (final character in CharacterType.values) {
          final game = await mount(
            tester,
            weapons[row],
            _Audio(),
            character: character,
          );
          await tester.runAsync(() async {
            final headings = [
              Vector2(1, 0),
              Vector2(0, 1),
              Vector2(-1, 0),
              Vector2(0, -1),
            ];
            for (var facing = 0; facing < 4; facing++) {
              game.weaponJoystick.delta.setFrom(headings[facing] * 90);
              game.myPlayer.update(0);
              canvas.save();
              canvas.translate(
                30 + (character.index * 4 + facing) * 130.0,
                35 + row * 150.0,
              );
              game.myPlayer.render(canvas);
              canvas.restore();
            }
            if (character == CharacterType.rook) {
              for (var col = 0; col < 8; col++) {
                reloadCanvas.save();
                reloadCanvas.translate(75 + col * 150.0, 75 + row * 135.0);
                reloadCanvas.scale(1.6);
                paintWeapon(
                  reloadCanvas,
                  weapons[row],
                  reload: [.1, .42, .82, .94][col % 4],
                  tactical: col >= 4,
                );
                reloadCanvas.restore();
              }
            }
          });
          await tester.pumpWidget(const SizedBox());
        }
      }
      await tester.runAsync(() async {
        await Directory('build/test-previews').create(recursive: true);
        for (final entry in [
          (
            recorder,
            'endgame-survivor-mounts',
            CharacterType.values.length * 4 * 130 + 60,
            900,
          ),
          (reloadRecorder, 'endgame-reload-modes', 1240, 810),
        ]) {
          final picture = entry.$1.endRecording();
          final image = await picture.toImage(entry.$3, entry.$4);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/test-previews/${entry.$2}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        }
      });
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'base and VIII endgame reload cycles retain finite budgets and record pack damage',
    (tester) async {
      final rows = <Map<String, dynamic>>[];
      for (final weapon in WeaponType.values.skip(15)) {
        for (final developed in [false, true]) {
          final game = await mount(
            tester,
            weapon,
            _Audio(),
            arena: developed ? ArenaType.foundry : ArenaType.breach,
          );
          await tester.runAsync(() async {
            if (developed) {
              for (final p in [
                PowerUp.heavyLoad,
                PowerUp.quickTrigger,
                PowerUp.maxBulletsIncrease,
                PowerUp.fastReload,
                PowerUp.numberOfBulletsPerShotIncrease,
                PowerUp.bulletsPhaseThrough,
                PowerUp.ricochet,
                PowerUp.bulletRangeIncrease,
                PowerUp.rapidFire,
                PowerUp.walkingSpeedIncrease,
              ]) {
                if (weaponSupportsPowerUp(weapon, p)) {
                  for (var rank = 0; rank < 8; rank++) {
                    grant(game, p);
                  }
                }
              }
            }
            // Keep this fixed-build benchmark out of upgrade pickers when
            // the denser Training crowd supplies XP during the simulation.
            final fixedBuild = game.gameNotifier.checkpoint();
            fixedBuild['state'] = game.gameState
                .copyWith(noOfCoinsToUpgrade: 1000000, xP: 0)
                .toJson();
            game.gameNotifier.restoreCheckpoint(fixedBuild);
            game.gameNotifier.playGame();
            final targets = [
              for (var i = 0; i < 5; i++)
                _Target(
                  game.myPlayer.position +
                      Vector2(110 + i * 110, (i % 3 - 1) * 35.0),
                ),
            ];
            await game.world.addAll(targets);
            await game.ready();
            var peakProjectiles = 0, peakEffects = 0;
            for (var frame = 0; frame < 400; frame++) {
              game.weaponJoystick.delta.setValues(90, 0);
              if (weapon.firesOnRelease && frame % 12 == 11) {
                game.arsenal!.releaseAim(Vector2(1, 0));
                game.weaponJoystick.delta.setZero();
              }
              game.update(.05);
              await game.ready();
              final projectiles = game.projectileCount,
                  effects = game.runtimeCounts['effects']!;
              if (projectiles > peakProjectiles) peakProjectiles = projectiles;
              if (effects > peakEffects) peakEffects = effects;
              expect(projectiles, lessThanOrEqualTo(RegunGame.maxProjectiles));
              expect(effects, lessThanOrEqualTo(40));
            }
            expect(game.shotsFired, greaterThan(weapon.capacity));
            final snapshot = game.checkpoint();
            ArsenalSystem.validate(
              Map<String, dynamic>.from(snapshot['arsenal'] as Map),
              weapon,
            );
            expect(
              RunCheckpoint.valid(snapshot),
              true,
              reason: '${weapon.name} / $developed',
            );
            rows.add({
              'weapon': weapon.name,
              'build': developed ? 'VIII' : 'base',
              'seconds': 20,
              'shots': game.shotsFired,
              'packDamage': targets.fold<double>(
                0,
                (sum, t) => sum + 1000 - t.combatHealth.current,
              ),
              'peakProjectiles': peakProjectiles,
              'peakEffects': peakEffects,
              'walkSpeed': game.playerWalkSpeed,
            });
            game.weaponJoystick.delta.setZero();
            await advance(game, 5, held: false);
            expect(
              game.arsenal!.endgame.effectCount,
              0,
              reason:
                  '${weapon.name} / $developed / ${game.gameState.gameplayState}',
            );
          });
          await tester.pumpWidget(const SizedBox());
          expect(tester.takeException(), isNull);
        }
      }
      await tester.runAsync(() async {
        await File('build/test-previews/endgame-pack-cycles.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(rows));
      });
    },
  );
  for (final weapon in WeaponType.values.where((w) => w.usesArsenalRuntime)) {
    testWidgets(
      '${weapon.name}: real firing, damage, pause, reload, save and bounded cleanup',
      (tester) async {
        final audio = _Audio();
        final game = await mount(tester, weapon, audio);
        await tester.runAsync(() async {
          final targets = [
            _Target(game.myPlayer.position + Vector2(100, 0)),
            _Target(
              game.myPlayer.position +
                  Vector2(
                    {
                          WeaponType.scrapMortar,
                          WeaponType.anchorEngine,
                        }.contains(weapon)
                        ? 600
                        : 260,
                    0,
                  ),
            ),
          ];
          await game.world.addAll(targets);
          await game.ready();
          await advance(game, 1.3);
          expect(game.shotsFired, greaterThan(0));
          expect(
            targets
                .expand((t) => t.reactions)
                .any(
                  (r) =>
                      r.distance ==
                      (weapon == WeaponType.railLance
                          ? game.arsenal!.balance.railReaction.distance
                          : WeaponReaction.of(weapon).distance),
                ),
            isTrue,
            reason:
                '${weapon.name} must deliver its primary force through real firing',
          );
          expect(
            targets.any((t) => t.combatHealth.current < 1000),
            true,
            reason: weapon.name,
          );
          expect(
            game.runtimeCounts['playerProjectiles']!,
            lessThanOrEqualTo(RegunGame.maxProjectiles),
          );
          expect(game.runtimeCounts['effects']!, lessThanOrEqualTo(40));
          if (weapon == WeaponType.frostShotgun) {
            expect(game.gameState.noOfBullets, 3);
          }
          final save = game.checkpoint();
          expect(RunCheckpoint.valid(save), true, reason: weapon.name);
          final durable = Map<String, dynamic>.from(save['arsenal'] as Map);
          ArsenalSystem.validate(durable, weapon);
          final before = game.arsenal!.clock;
          game.pauseGame();
          game.update(1);
          expect(game.arsenal!.clock, before);
          expect(audio.loops, isEmpty);
          game.gameNotifier.playGame();
          game.arsenal!.restore(durable);
          await advance(game, 1, held: false);
          game.requestReload();
          await advance(game, 5, held: false);
          expect(game.gameState.reloading, false);
          expect(game.gameState.noOfBullets, game.gameState.maxBullets);
          await advance(game, 4, held: false);
          expect(game.arsenal!.flights, isEmpty);
          expect(game.arsenal!.rivets, isEmpty);
          expect(game.arsenal!.patches, isEmpty);
          expect(audio.loops, isEmpty);
          expect(RegunArt.shared.decodedBytes, lessThan(32 * 1024 * 1024));
        });
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Aim Assist respects the selected range and solid cover', (
    tester,
  ) async {
    final game = await mount(tester, WeaponType.railLance, _Audio());
    await tester.runAsync(() async {
      final target = _Target(game.myPlayer.position + Vector2(300, 60));
      game.world.add(target);
      await game.ready();
      game.preferences.aimAssist = true;
      expect(
        game.assistedWeaponDirection(Vector2(1, 0), range: 1000).y,
        greaterThan(0),
      );
      expect(game.assistedWeaponDirection(Vector2(1, 0), range: 100).y, 0);
      final origin = game.myPlayer.position;
      game.geometry = ArenaGeometry(
        game.map.bounds,
        obstacles: [Rect.fromLTWH(origin.x + 150, origin.y - 50, 50, 150)],
      );
      expect(game.assistedWeaponDirection(Vector2(1, 0), range: 1000).y, 0);
      game.preferences.aimAssist = false;
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'largest boss pair plus Cinder packet and moving fire art fit 32 MiB',
    () async {
      final names = [
        'bosses/marshal',
        'bosses/sovereign',
        'weapons/cinder_hose',
        'effects/cinder_flame',
      ];
      for (final name in names) {
        await RegunArt.shared.acquire(name);
      }
      expect(RegunArt.shared.decodedBytes, lessThanOrEqualTo(32 * 1024 * 1024));
      for (final name in names.reversed) {
        RegunArt.shared.release(name);
      }
    },
  );
  testWidgets(
    'Rail Lance waits .65 active seconds while preserving its repeated firing cycle',
    (tester) async {
      final game = await mount(tester, WeaponType.railLance, _Audio());
      await tester.runAsync(() async {
        final damage = game.gameNotifier.weaponPower.damage(
          WeaponType.railLance,
        );
        await advance(game, .64);
        expect(game.shotsFired, 0);
        expect(game.gameState.noOfBullets, 3);
        expect(game.arsenal!.visualCharge, closeTo(.64 / .65, .015));
        game.pauseGame();
        final charge = game.arsenal!.charge;
        await advance(game, 1);
        expect(game.arsenal!.charge, charge);
        game.resumeGame();
        // Resuming clears aim intent; charge must be deliberately rebuilt.
        await advance(game, .64);
        expect(game.shotsFired, 0);
        await advance(game, .02);
        expect(game.shotsFired, 1);
        expect(game.gameState.noOfBullets, 2);
        expect(
          game.gameNotifier.weaponPower.damage(WeaponType.railLance),
          damage,
        );
        await advance(game, .9);
        expect(game.shotsFired, 1);
        await advance(game, .21);
        expect(game.shotsFired, 2);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Rail Lance full charge widens the lane, rewards aiming and staggers survivors',
    (tester) async {
      final game = await mount(tester, WeaponType.railLance, _Audio());
      await tester.runAsync(() async {
        final arsenal = game.arsenal!;
        final origin = arsenal.muzzle(Vector2(1, 0));
        final first = _PullTarget(origin + Vector2(160, 0));
        final edge = _PullTarget(origin + Vector2(300, 0));
        final outside = _PullTarget(origin + Vector2(440, 0));
        final planted = _PlantedTarget(origin + Vector2(580, 0));
        await game.world.addAll([first, edge, outside, planted]);
        await game.ready();
        edge.position.y += game.enemyRadius(edge) + 6;
        outside.position.y += game.enemyRadius(outside) + 9;
        await advance(game, .66);
        expect(game.shotsFired, 1);
        final bullet = game.world.children.whereType<BulletComponent>().single;
        expect(bullet.damage, closeTo(14.0625, 1e-8));
        expect(bullet.bulletRadius, 7);
        expect(bullet.reaction!.stagger, .23);
        await advance(game, .45, held: false);
        expect(1000 - first.combatHealth.current, closeTo(14.0625, .001));
        expect(1000 - edge.combatHealth.current, closeTo(14.0625 * .65, .001));
        expect(outside.combatHealth.current, 1000);
        expect(planted.combatHealth.current, lessThan(1000));
        expect(first.impactHeld, true);
        expect(edge.reactions.single.stagger, .23);
        expect(planted.impactHeld, false);
        expect(planted.position.distanceTo(origin + Vector2(580, 0)), 0);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Rail Lance quick release and older snapshots retain distinct shot power',
    (tester) async {
      for (final revision in [2, 3]) {
        final game = await mount(tester, WeaponType.railLance, _Audio());
        await tester.runAsync(() async {
          game.gameNotifier.weaponPower = WeaponPowerBalance.read(revision);
          final arsenal = game.arsenal!;
          expect(arsenal.releaseAim(Vector2(1, 0)), true);
          await game.ready();
          final quick = game.world.children.whereType<BulletComponent>().single;
          expect(quick.damage, revision == 3 ? 11.25 : 9);
          expect(quick.bulletRadius, revision == 3 ? 7 : 5);
          expect(quick.reaction!.stagger, revision == 3 ? .23 : .13);
          await advance(game, 1.11, held: false);
          await advance(game, .66);
          final charged = game.world.children
              .whereType<BulletComponent>()
              .single;
          expect(charged.damage, revision == 3 ? 14.0625 : 9);
          final saved = game.checkpoint();
          expect(RunCheckpoint.valid(saved), true);
          game.gameNotifier.restoreCheckpoint(saved);
          arsenal.restore(Map<String, dynamic>.from(saved['arsenal']));
          expect(arsenal.balance.revision, revision);
          expect(
            arsenal.balance.railChargeMultiplier,
            revision == 3 ? 1.25 : 1,
          );
        });
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'Rail Lance quick release fires once and preserves its firing interval',
    (tester) async {
      final game = await mount(tester, WeaponType.railLance, _Audio());
      await tester.runAsync(() async {
        final rail = game.arsenal!;
        await advance(game, .12);
        expect(game.shotsFired, 0);
        expect(rail.releaseAim(Vector2(1, 0)), true);
        game.weaponJoystick.delta.setZero();
        expect(game.shotsFired, 1);
        expect(game.gameState.noOfBullets, 2);
        expect(rail.charge, 0);
        expect(rail.releaseAim(Vector2(1, 0)), false);
        // Recovery alone must not allow flicks to bypass the full cycle.
        await advance(game, .5, held: false);
        expect(rail.releaseAim(Vector2(1, 0)), false);
        final saved = rail.checkpoint();
        rail.restore(saved);
        expect(rail.releaseAim(Vector2(1, 0)), false);
        game.pauseGame();
        await advance(game, 2, held: false);
        expect(rail.releaseAim(Vector2(1, 0)), false);
        game.resumeGame();
        await advance(game, .61, held: false);
        // Even a flick between simulation frames can release a shot.
        expect(rail.releaseAim(Vector2(0, 1)), true);
        expect(game.shotsFired, 2);
        expect(game.gameState.noOfBullets, 1);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Rail Lance automatic discharge cannot double fire on release or cancellation',
    (tester) async {
      final game = await mount(tester, WeaponType.railLance, _Audio());
      await tester.runAsync(() async {
        final rail = game.arsenal!;
        await advance(game, .66);
        expect(game.shotsFired, 1);
        expect(rail.releaseAim(Vector2(1, 0)), false);
        await advance(game, 1.11, held: false);
        await advance(game, .2);
        rail.cancelAim();
        game.weaponJoystick.delta.setZero();
        await advance(game, .5, held: false);
        expect(rail.charge, 0);
        expect(game.shotsFired, 1);
        expect(rail.releaseAim(Vector2.zero()), false);
        game.requestReload();
        expect(rail.releaseAim(Vector2(1, 0)), false);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'charge cancellation spends no ammo, and Frost freezes a living enemy',
    (tester) async {
      final rail = await mount(tester, WeaponType.railLance, _Audio());
      await tester.runAsync(() async {
        await advance(rail, .5);
        expect(rail.shotsFired, 0);
        await advance(rail, .05, held: false);
        expect(rail.arsenal!.charge, 0);
        expect(rail.gameState.noOfBullets, 3);
      });
      final frost = await mount(tester, WeaponType.frostShotgun, _Audio());
      await tester.runAsync(() async {
        final target = _Target(frost.myPlayer.position + Vector2(130, 0));
        await frost.world.add(target);
        await frost.ready();
        await advance(frost, .20);
        expect(target.freezeState.frozen, true);
        expect(target.freeze(), false);
        expect(
          frost.world.children.whereType<BulletComponent>().length,
          lessThanOrEqualTo(3),
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'blocked discs expire their reservations and another blade can fire',
    (tester) async {
      final game = await mount(tester, WeaponType.reaperDisc, _Audio());
      await tester.runAsync(() async {
        final edge = game.geometry.bounds.floor.right - 1;
        for (var i = 1; i <= 3; i++) {
          game.arsenal!.flights.add(
            ArsenalFlight(
              i,
              ArsenalFlightKind.disc,
              Vector2(edge, i * 40.0),
              Vector2(1, 0),
              1.5,
              700,
              500,
            )..travelled = 499.99999,
          );
        }
        game.arsenal!.nextAttack = 4;
        expect(game.arsenal!.flightCount, 3);
        await advance(game, 3, held: false);
        expect(game.arsenal!.flights, isEmpty);
        game.weaponJoystick.delta.setValues(70, 0);
        game.update(.02);
        expect(game.shotsFired, 1);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final weapon in [WeaponType.scrapMortar, WeaponType.sporeLobber]) {
    testWidgets(
      '${weapon.name} waits for release and chooses near or far landing',
      (tester) async {
        final game = await mount(tester, weapon, _Audio());
        await tester.runAsync(() async {
          for (var i = 0; i < 20; i++) {
            game.weaponJoystick.delta.setValues(70, 0);
            game.update(.025);
          }
          expect(game.shotsFired, 0);
          expect(game.gameState.noOfBullets, weapon.capacity);
          final near = game.arsenal!.mortarTarget(
            Vector2(1, 0),
            released: Vector2(.25, 0),
          );
          final far = game.arsenal!.mortarTarget(
            Vector2(1, 0),
            released: Vector2(1, 0),
          );
          expect(near.distanceTo(game.myPlayer.position), lessThan(170));
          expect(far.distanceTo(game.myPlayer.position), greaterThan(450));
          expect(game.arsenal!.releaseAim(Vector2(.25, 0)), true);
          final flight = game.arsenal!.flights.single;
          expect(flight.destination.distanceTo(near), lessThan(.001));
          expect(game.arsenal!.releaseAim(Vector2(1, 0)), false);
          final saved = game.checkpoint();
          expect(RunCheckpoint.valid(saved), true);
        });
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'Sniper fires on release and kills weak bodies with innate piercing',
    (tester) async {
      final game = await mount(tester, WeaponType.longwatchSniper, _Audio());
      await tester.runAsync(() async {
        final targets = [
          for (var i = 0; i < 3; i++)
            _Target(game.myPlayer.position + Vector2(170 + i * 100, 0))
              ..restoreHealth(5, maximum: 5),
        ];
        await game.world.addAll(targets);
        await game.ready();
        for (var i = 0; i < 20; i++) {
          game.weaponJoystick.delta.setValues(70, 0);
          game.update(.025);
        }
        expect(game.shotsFired, 0);
        expect(game.arsenal!.releaseAim(Vector2(1, 0)), true);
        await game.ready();
        expect(
          game.world.children.whereType<BulletComponent>().single.pierce,
          3,
        );
        await advance(game, .4, held: false);
        expect(targets.every((e) => e.combatHealth.isDead), true);
        expect(game.gameState.noOfBullets, 4);
        game.pauseGame();
        expect(game.arsenal!.releaseAim(Vector2(1, 0)), false);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Repeater spin is audible before the first round and capacity is one hundred',
    (tester) async {
      final audio = _Audio();
      final game = await mount(tester, WeaponType.beltRepeater, audio);
      await tester.runAsync(() async {
        game.weaponJoystick.delta.setValues(70, 0);
        game.update(.02);
        expect(audio.cues, contains('spin_beltRepeater.wav'));
        expect(game.shotsFired, 0);
        expect(game.gameState.maxBullets, 100);
        await advance(game, .8);
        expect(game.shotsFired, greaterThanOrEqualTo(5));
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'returning Reaper follows the moving gun and frees its reservation on catch',
    (tester) async {
      final game = await mount(tester, WeaponType.reaperDisc, _Audio());
      await tester.runAsync(() async {
        final f = ArsenalFlight(
          80,
          ArsenalFlightKind.disc,
          game.myPlayer.position + Vector2(400, 0),
          Vector2(-1, 0),
          1.5,
          700,
          500,
        )..returning = true;
        f.destination.setFrom(game.myPlayer.position);
        game.arsenal!.flights.add(f);
        game.myPlayer.position.add(Vector2(0, 180));
        game.update(.025);
        expect(
          f.destination.distanceTo(
            game.arsenal!.muzzle(game.myPlayer.aimDirection),
          ),
          lessThan(.001),
        );
        expect(f.direction.y, greaterThan(0));
        game.myPlayer.position.add(Vector2(0, 50));
        await advance(game, 1, held: false);
        expect(game.arsenal!.flights, isEmpty);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Spore ground rupture survives visual saturation and fires exactly once',
    (tester) async {
      final audio = _Audio();
      final game = await mount(tester, WeaponType.sporeLobber, audio);
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          game.addCombatEffect(
            CombatEffect(
              position: game.myPlayer.position.clone(),
              duration: 10,
            ),
          );
        }
        await game.ready();
        expect(game.runtimeCounts['effects'], 40);
        game.arsenal!.flights.add(
          ArsenalFlight(
            90,
            ArsenalFlightKind.spore,
            game.myPlayer.position + Vector2(100, 0),
            Vector2(1, 0),
            2,
            600,
            20,
          )..patchDamage = .8,
        );
        await advance(game, .1, held: false);
        expect(game.arsenal!.patches.length, 1);
        expect(game.runtimeCounts['effects'], lessThanOrEqualTo(40));
        expect(game.arsenal!.flights, isEmpty);
        expect(
          audio.cues.where((s) => s == 'impact_sporeLobber.wav').length,
          1,
        );
        await advance(game, .2, held: false);
        expect(game.arsenal!.patches.length, 1);
        expect(
          audio.cues.where((s) => s == 'impact_sporeLobber.wav').length,
          1,
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Repeater accelerates, samples bounded barrel recoil and resets on release',
    (tester) async {
      final game = await mount(tester, WeaponType.beltRepeater, _Audio());
      await tester.runAsync(() async {
        final jitters = <String>{};
        final system = game.arsenal!;
        var fired = 0;
        for (var i = 0; i < 200; i++) {
          game.weaponJoystick.delta.setValues(70, 0);
          game.update(.025);
          await game.ready();
          if (game.shotsFired != fired) {
            fired = game.shotsFired;
            jitters.add(system.muzzleJitter.toString());
            expect(system.muzzleJitter.x.abs(), lessThanOrEqualTo(2));
            expect(system.muzzleJitter.y.abs(), lessThanOrEqualTo(4));
          }
        }
        expect(jitters.length, greaterThan(20));
        expect(system.beltCadence, lessThan(.062));
        expect(game.gameState.noOfBullets, greaterThan(0));
        game.pauseGame();
        final time = system.sustainedFire;
        game.update(3);
        expect(system.sustainedFire, time);
        game.resumeGame();
        await advance(game, .1, held: false);
        expect(system.sustainedFire, 0);
        expect(system.beltCadence, .085);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Sniper takes two frontal shield hits while Frost exceeds Pump raw damage',
    (tester) async {
      final game = await mount(tester, WeaponType.longwatchSniper, _Audio());
      await tester.runAsync(() async {
        final shield = ArenaEnemy(
          EnemyKind.shield,
          position: game.myPlayer.position + Vector2(-250, 0),
        );
        await game.world.add(shield);
        await game.ready();
        expect(shield.combatHealth.maximum, 8);
        game.hitEnemy(
          shield,
          WeaponType.longwatchSniper.damage,
          direction: Vector2(-1, 0),
          armorPiercing: true,
        );
        expect(shield.combatHealth.isDead, false);
        expect(shield.combatHealth.current, closeTo(3.2, .001));
        game.hitEnemy(
          shield,
          WeaponType.longwatchSniper.damage,
          direction: Vector2(-1, 0),
          armorPiercing: true,
        );
        expect(shield.combatHealth.isDead, true);
        expect(
          WeaponType.frostShotgun.damage,
          greaterThan(WeaponType.shotgun.damage),
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Rivet crowd charges retain planted splash when their host dies',
    (tester) async {
      final game = await mount(tester, WeaponType.rivetDriver, _Audio());
      await tester.runAsync(() async {
        final host = _Target(game.myPlayer.position + Vector2(250, 0));
        final nearby = _Target(game.myPlayer.position + Vector2(350, 0));
        await game.world.addAll([host, nearby]);
        await game.ready();
        game.arsenal!.lodge(host);
        game.arsenal!.lodge(host);
        game.arsenal!.lodge(host);
        expect(game.arsenal!.rivets.length, 2);
        host.takeDamage(2000);
        await game.ready();
        final before = nearby.combatHealth.current;
        await advance(game, .2, held: false);
        expect(game.arsenal!.rivets, isEmpty);
        expect(nearby.combatHealth.current, before - 5);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'render ordinary shield and burster warning footprints below actors',
    (tester) async {
      final game = await mount(tester, WeaponType.shotgun, _Audio());
      await tester.runAsync(() async {
        for (final kind in [EnemyKind.shield, EnemyKind.burster]) {
          final e = ArenaEnemy(
            kind,
            position:
                game.myPlayer.position +
                Vector2(kind == EnemyKind.shield ? -240 : 240, -100),
          );
          await game.world.add(e);
          await game.ready();
          e.phase = 1;
          e.clock = .5;
        }
      });
      await tester.runAsync(() async {
        final runner = ArenaEnemy(
          EnemyKind.runner,
          position: game.myPlayer.position + Vector2(-350, 140),
        );
        await game.world.add(runner);
        await game.ready();
        runner.clock = 1.3;
        game.update(.02);
      });
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('weapon-review')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2),
            bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('build/test-previews/enemy-area-warnings.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Burster boots cycle from travelled distance and hold during freeze and wind-up',
    (tester) async {
      final game = await mount(tester, WeaponType.shotgun, _Audio());
      await tester.runAsync(() async {
        final burster = ArenaEnemy(
          EnemyKind.burster,
          position: game.myPlayer.position + Vector2(400, -100),
        );
        await game.world.add(burster);
        await game.ready();
        final start = burster.position.clone();
        await advance(game, .2, held: false);
        expect(
          burster.walkDistance,
          closeTo(burster.position.distanceTo(start), .1),
        );
        expect(burster.walkDistance, greaterThan(14));
        final frame = BursterWalk.frame(
          burster.walkDirection.toOffset(),
          burster.walkDistance,
        );
        expect(frame % 4, 1);
        burster.freeze();
        final held = burster.walkDistance;
        await advance(game, .2, held: false);
        expect(burster.walkDistance, held);
        burster.freezeState.advance(1);
        burster.phase = 1;
        burster.clock = 0;
        await advance(game, .2, held: false);
        expect(burster.walkDistance, held);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('sniper release uses exactly the swayed assisted sight heading', (
    tester,
  ) async {
    final game = await mount(tester, WeaponType.longwatchSniper, _Audio());
    await tester.runAsync(() async {
      for (var i = 0; i < 200; i++) {
        game.weaponJoystick.delta.setValues(70, 0);
        game.update(.025);
        await game.ready();
      }
      expect(game.shotsFired, 0);
      expect(game.arsenal!.sniperSway.fatigue, closeTo(5, .001));
      final direction = game.arsenal!.aimedDirection(Vector2(1, 0));
      expect(direction.y.abs(), greaterThan(0));
      game.arsenal!.releaseAim(Vector2(1, 0));
      await game.ready();
      final shot = game.world.children.whereType<BulletComponent>().single;
      expect(shot.direction.distanceTo(direction), lessThan(1e-10));
      expect(game.arsenal!.sniperSway.active, false);
      await advance(game, .5, held: false);
      expect(game.arsenal!.sniperSway.fatigue, lessThan(5));
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Training weapon change stays paused and keeps the encounter and build',
    (tester) async {
      final game = await mount(tester, WeaponType.reaperDisc, _Audio());
      await tester.runAsync(() async {
        final at = game.myPlayer.position.clone();
        final health = game.gameState.health;
        final checkpoint = game.gameNotifier.checkpoint();
        game.gameNotifier.restoreCheckpoint({
          ...checkpoint,
          'state': game.gameState
              .copyWith(shotDamage: 1.7, currentLevel: 4)
              .toJson(),
        });
        game.pauseGame();
        expect(
          await game.changeTrainingWeapon(WeaponType.longwatchSniper),
          true,
        );
        expect(game.gameState.gameplayState, GameplayState.paused);
        expect(game.gameState.shotDamage, 1.7);
        expect(game.gameState.currentLevel, 4);
        expect(game.gameState.health, health);
        expect(game.myPlayer.position, at);
        expect(game.gameState.noOfBullets, 5);
        expect(game.loadout.weapon, WeaponType.longwatchSniper);
        expect(await game.changeTrainingWeapon(WeaponType.prismCutter), true);
        expect(game.gameState.maxBullets, 18);
      });
      await tester.pump();
      expect(find.text('WEAPON PRACTICE'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
