import 'dart:io';
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
    _Audio audio,
  ) async {
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
                loadout: Loadout(weapon: weapon, training: true),
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
      for (var i = 0; i < 40; i++) {
        game.update(.025);
        await game.ready();
      }
    }
  }

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
    'all fifteen have meaningful upgrade capabilities and packaged cues',
    () {
      expect(WeaponType.values.length, 15);
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
                  Vector2(weapon == WeaponType.scrapMortar ? 620 : 260, 0),
            ),
          ];
          await game.world.addAll(targets);
          await game.ready();
          await advance(game, 1.3);
          expect(game.shotsFired, greaterThan(0));
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
      await game.world.add(target);
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
    'charge cancellation spends no ammo, and Frost freezes a living enemy',
    (tester) async {
      final rail = await mount(tester, WeaponType.railLance, _Audio());
      await tester.runAsync(() async {
        await advance(rail, .3);
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
        expect(WeaponType.frostShotgun.damage, WeaponType.shotgun.damage + 1);
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
        expect(nearby.combatHealth.current, before - 3.5);
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
