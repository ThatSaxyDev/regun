import 'package:regun/components/weapons/bullet_component.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/data/weapon_power_balance.dart';
import 'package:regun/game.dart';
import 'package:regun/models/live_balance.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/systems/arsenal_system.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/systems/frontier_components.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Quiet extends SoloudPlay {
  final cues = <String>[];
  @override
  Future<void> play(String asset) async {
    cues.add(asset);
  }
}

class _Body extends EnemyComponent {
  _Body(Vector2 at) : super(position: at) {
    restoreHealth(1000, maximum: 1000);
  }
  @override
  void update(double dt) => super.update(0);
  @override
  double get impactResponse => 0;
}

void main() {
  setUpAll(() async {
    for (final font in ['PressStart2P', 'Orbitron']) {
      await (FontLoader(
        font,
      )..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf'))).load();
    }
  });
  Future<RegunGame> mount(
    WidgetTester tester,
    WeaponType weapon, {
    bool training = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: MaterialApp(
            home: RepaintBoundary(
              key: const Key('frontier-review'),
              child: BaseView(
                key: ValueKey(weapon),
                loadout: Loadout(weapon: weapon, training: training),
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
      game.geometry = ArenaGeometry(game.map.bounds, obstacles: []);
      game.preferences.aimAssist = false;
    });
    return game;
  }

  Future<_Body> body(RegunGame g, Vector2 offset) async {
    final e = _Body(g.myPlayer.position + offset);
    g.world.add(e);
    await g.ready();
    e.position.setFrom(g.myPlayer.position + offset);
    return e;
  }

  void step(RegunGame g, double time, {bool held = false}) {
    g.weaponJoystick.delta.setValues(held ? 70 : 0, 0);
    for (double at = 0; at < time - 1e-8; at += .01) {
      g.arsenal!.advance((time - at).clamp(0, .01));
    }
  }

  bool fire(RegunGame g) {
    g.weaponJoystick.delta.setValues(70, 0);
    final result = g.arsenal!.frontier.fire();
    g.weaponJoystick.delta.setZero();
    return result;
  }

  Map<String, dynamic> copy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value));

  for (final layout in [
    (844.0, 390.0, 1.0),
    (844.0, 390.0, 1.5),
    (568.0, 320.0, 1.0),
    (844.0, 390.0, 2.0),
  ]) {
    testWidgets('upgrade offers keep bottom actions accessible at $layout', (
      tester,
    ) async {
      tester.view.physicalSize = Size(layout.$1, layout.$2);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = layout.$3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final g = await mount(tester, WeaponType.shotgun, training: false);
      for (var i = 0; i < 8; i++) {
        g.gameNotifier.increaseXP();
      }
      final saved = g.gameNotifier.checkpoint();
      saved['state'] = g.gameState
          .copyWith(
            powerUpChoices: [
              PowerUp.heavyLoad,
              PowerUp.maxBulletsIncrease,
              PowerUp.ricochet,
            ],
          )
          .toJson();
      g.gameNotifier.restoreCheckpoint(saved);
      g.gameNotifier.playGame();
      await tester.pump();
      final reroll = find.byKey(const Key('upgrade-reroll'));
      expect(reroll.hitTestable(), findsOneWidget);
      expect(tester.getRect(reroll).bottom, lessThanOrEqualTo(layout.$2));
      if (layout.$1 == 844 && layout.$3 == 1) {
        for (var i = 0; i < 3; i++) {
          expect(find.text('BAN').at(i).hitTestable(), findsOneWidget);
        }
      }
      await tester.ensureVisible(find.text('BAN').last);
      await tester.pump();
      expect(find.text('BAN').last.hitTestable(), findsOneWidget);
      expect(reroll.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (layout.$3 == 1) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('frontier-review')),
          );
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/frontier-review').create(recursive: true);
          await File('build/frontier-review/upgrades-${layout.$1.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final count = g.gameState.rerolls;
      await tester.tap(reroll);
      await tester.pump();
      expect(g.gameState.rerolls, count - 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'Revolver owns an innate ricochet without buying an upgrade, and admin values stack with ranks',
    (tester) async {
      final g = await mount(tester, WeaponType.revolver);
      await tester.runAsync(() async {
        final first = await body(g, Vector2(180, 0));
        final second = await body(g, Vector2(320, 100));
        final third = await body(g, Vector2(450, 100));
        expect(g.gameState.rank(PowerUp.ricochet), 0);
        expect(g.gameState.ranks, isEmpty);
        expect(g.gameNotifier.weaponPower.ricochets(WeaponType.revolver), 1);
        expect(
          eligiblePowerUps(g.gameState, weapon: WeaponType.revolver),
          contains(PowerUp.bankShot),
        );
        bool shoot() {
          g.weaponJoystick.delta.setValues(70, 0);
          final fired = g.spawnShotgunBullets();
          g.weaponJoystick.delta.setZero();
          return fired;
        }

        expect(shoot(), true);
        await g.ready();
        expect(g.world.children.whereType<BulletComponent>().single.bounces, 1);
        for (var i = 0; i < 100; i++) {
          g.update(.01);
          await g.ready();
        }
        expect(first.combatHealth.current, lessThan(1000));
        expect(second.combatHealth.current, lessThan(1000));
        expect(third.combatHealth.current, 1000);
        expect(g.gameState.rank(PowerUp.ricochet), 0);
        expect(g.gameState.noOfBullets, 5);
        for (final value in [0, 2]) {
          for (final b
              in g.world.children.whereType<BulletComponent>().toList()) {
            b.removeFromParent();
          }
          await g.ready();
          g.gameNotifier.weaponPower = WeaponPowerBalance.live(
            LiveBalance.create(20 + value, {
              ...LiveBalance.bundled.values,
              'weapons.revolver.ricochets': value,
            }),
          );
          expect(shoot(), true);
          await g.ready();
          expect(
            g.world.children.whereType<BulletComponent>().single.bounces,
            value,
          );
          expect(
            g.gameState.rankValues(
              PowerUp.ricochet,
              0,
              WeaponType.revolver,
              g.loadout.character,
              g.gameNotifier.weaponPower,
            )['Total enemy ricochets'],
            value,
          );
          expect(
            g.gameState.rankValues(
              PowerUp.ricochet,
              1,
              WeaponType.revolver,
              g.loadout.character,
              g.gameNotifier.weaponPower,
            )['Total enemy ricochets'],
            value + 1,
          );
        }
        expect(
          frontierComponents(
            'revolver',
            LiveBalance.bundled.values,
          )['Innate enemy ricochets'],
          1,
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Houndrack seeks its original acquisition, then expires', (
    tester,
  ) async {
    final g = await mount(tester, WeaponType.houndrack);
    await tester.runAsync(() async {
      final target = await body(g, Vector2(400, 70));
      expect(fire(g), true);
      final f = g.arsenal!.frontier.shots.single;
      expect(f.target, target.combatId);
      expect(g.gameState.noOfBullets, 39);
      step(g, .1);
      expect(f.direction.y, greaterThan(0));
      expect(f.direction.y, greaterThan(.1));
      expect(f.direction.y, lessThanOrEqualTo(.451));
      final paid = f.target;
      final blocker = await body(g, Vector2(200, -20));
      step(g, .1);
      expect(f.target, paid);
      step(g, 3.2);
      expect(g.arsenal!.frontier.shots, isEmpty);
      expect(blocker.combatHealth.current, 1000);
      expect(target.combatHealth.current, lessThan(1000));
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'rocket flight limit rejects before ammo and impact excludes direct owner from splash',
    (tester) async {
      final g = await mount(tester, WeaponType.houndrack);
      await tester.runAsync(() async {
        final direct = await body(g, Vector2(200, 0));
        final neighbor = await body(g, Vector2(200, 65));
        expect(fire(g), true);
        step(g, .4);
        expect(1000 - direct.combatHealth.current, closeTo(1.1, .001));
        expect(1000 - neighbor.combatHealth.current, closeTo(.45, .001));
        g.arsenal!.frontier.clear();
        g.gameNotifier.weaponPower = WeaponPowerBalance.live(
          LiveBalance.create(5, {
            ...LiveBalance.bundled.values,
            'effects.houndrack.rocketLimit': 1,
          }),
        );
        expect(fire(g), true);
        final ammo = g.gameState.noOfBullets;
        expect(fire(g), false);
        expect(g.gameState.noOfBullets, ammo);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('live behavior edits drive paid shots and zero disables splash', (
    tester,
  ) async {
    final g = await mount(tester, WeaponType.houndrack);
    await tester.runAsync(() async {
      g.gameNotifier.weaponPower = WeaponPowerBalance.live(
        LiveBalance.create(6, {
          ...LiveBalance.bundled.values,
          'effects.houndrack.rocketSplashDamage': 0,
          'effects.houndrack.rocketTurnRate': 0,
        }),
      );
      final direct = await body(g, Vector2(200, 0));
      final neighbor = await body(g, Vector2(200, 65));
      expect(fire(g), true);
      step(g, .4);
      expect(direct.combatHealth.current, lessThan(1000));
      expect(neighbor.combatHealth.current, 1000);
    });
    await tester.pumpWidget(const SizedBox.shrink());
    final orbGame = await mount(tester, WeaponType.stormOrb);
    await tester.runAsync(() async {
      orbGame.gameNotifier.weaponPower = WeaponPowerBalance.live(
        LiveBalance.create(7, {
          ...LiveBalance.bundled.values,
          'effects.stormorb.orbArcDamage': 2.5,
          'effects.stormorb.orbTargets': 1,
        }),
      );
      final near = await body(orbGame, Vector2(140, 100));
      final farther = await body(orbGame, Vector2(160, 100));
      expect(fire(orbGame), true);
      step(orbGame, .01);
      expect(1000 - near.combatHealth.current, closeTo(2.5, .001));
      expect(farther.combatHealth.current, 1000);
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'orb damages on passage, obeys pulse target cap and solid cover',
    (tester) async {
      final g = await mount(tester, WeaponType.stormOrb);
      await tester.runAsync(() async {
        final pack = <_Body>[];
        for (var i = 0; i < 5; i++) {
          pack.add(await body(g, Vector2(140 + i * 8, 100)));
        }
        expect(fire(g), true);
        step(g, .01);
        expect(pack.where((e) => e.combatHealth.current < 1000).length, 3);
        final before = pack.map((e) => e.combatHealth.current).toList();
        step(g, .1);
        expect(pack.map((e) => e.combatHealth.current).toList(), before);
        final c = g.myPlayer.position;
        g.geometry = ArenaGeometry(
          g.map.bounds,
          obstacles: [Rect.fromLTWH(c.x + 80, c.y + 30, 250, 15)],
        );
        step(g, .5);
        expect(pack.map((e) => e.combatHealth.current).toList(), before);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'rockets visibly accelerate, acquire wider targets and keep full near/far damage',
    (tester) async {
      final g = await mount(tester, WeaponType.houndrack);
      await tester.runAsync(() async {
        final offAxis = await body(g, Vector2(350, 180));
        expect(fire(g), true);
        final rocket = g.arsenal!.frontier.shots.single;
        expect(rocket.target, offAxis.combatId);
        step(g, .01);
        final first = rocket.travelled;
        step(g, .01);
        final earlyStep = rocket.travelled - first;
        step(g, .3);
        final before = rocket.travelled;
        step(g, .01);
        expect(rocket.travelled - before, greaterThan(earlyStep * 1.6));
        step(g, 1.2);
        expect(offAxis.combatHealth.current, closeTo(998.9, .001));
        offAxis.removeFromParent();
        await g.ready();
        for (final distance in [180.0, 600.0]) {
          final target = await body(g, Vector2(distance, 0));
          fire(g);
          step(g, 1.5);
          expect(1000 - target.combatHealth.current, closeTo(1.1, .001));
          target.removeFromParent();
          await g.ready();
        }
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'orb crosses multiple bodies, adds bonus damage once and persists its ledger',
    (tester) async {
      final g = await mount(tester, WeaponType.stormOrb);
      await tester.runAsync(() async {
        final pack = [
          await body(g, Vector2(160, 0)),
          await body(g, Vector2(280, 0)),
          await body(g, Vector2(400, 0)),
        ];
        fire(g);
        step(g, 1.3);
        final orb = g.arsenal!.frontier.shots.single;
        expect(orb.crossed, pack.map((e) => e.combatId).toSet());
        for (final enemy in pack) {
          expect(1000 - enemy.combatHealth.current, greaterThanOrEqualTo(3.8));
        }
        final snapshot = copy(g.arsenal!.checkpoint());
        g.arsenal!.restore(snapshot);
        final restored = g.arsenal!.frontier.shots.single;
        expect(restored.crossed, orb.crossed);
        restored.position.setFrom(pack.first.position);
        restored.tick = .5;
        final health = pack.first.combatHealth.current;
        step(g, .01);
        expect(pack.first.combatHealth.current, health);
        final malformed = copy(snapshot);
        malformed['frontier']['shots'][0]['crossed'] = [1, 1];
        expect(
          () => ArsenalSystem.validate(
            malformed,
            WeaponType.stormOrb,
            power: g.gameNotifier.weaponPower,
          ),
          throwsFormatException,
        );
        step(g, 3);
        expect(g.arsenal!.frontier.shots, isEmpty);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'ring launches at the gun, travels on its committed heading and recalls',
    (tester) async {
      final g = await mount(tester, WeaponType.ringCaster);
      await tester.runAsync(() async {
        expect(g.ringArtReady, true);
        fire(g);
        final r = g.arsenal!.frontier.ring!;
        final origin = g.arsenal!.muzzle(Vector2(1, 0));
        expect(r.center.distanceTo(origin), lessThan(.001));
        expect(r.radius, 8);
        step(g, .3, held: true);
        expect(r.center.x, greaterThan(origin.x + 50));
        final before = r.center.clone();
        g.myPlayer.position.y += 100;
        step(g, .01, held: true);
        expect(r.center.y, closeTo(before.y, .001));
        final gun = g.arsenal!.muzzle(g.myPlayer.aimDirection);
        final distance = r.center.distanceTo(gun);
        step(g, .05);
        expect(r.returning, true);
        expect(r.center.distanceTo(gun), lessThan(distance));
        step(g, .5);
        expect(g.arsenal!.frontier.ring, isNull);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'ring has an empty pocket and hits once on each controlled crossing',
    (tester) async {
      final g = await mount(tester, WeaponType.ringCaster);
      await tester.runAsync(() async {
        final outer = await body(g, Vector2(240, 0));
        final pocket = await body(g, Vector2(100, 100));
        expect(fire(g), true);
        step(g, .8, held: true);
        expect(1000 - outer.combatHealth.current, closeTo(4.5, .001));
        final insideHealth = pocket.combatHealth.current;
        step(g, .2, held: true);
        expect(pocket.combatHealth.current, insideHealth);
        expect(outer.combatHealth.current, closeTo(995.5, .001));
        step(g, .6);
        expect(g.arsenal!.frontier.ring, isNull);
        expect(
          1000 - outer.combatHealth.current,
          closeTo(4.5 + 4.5 * 1.25, .001),
        );
        expect(g.gameState.noOfBullets, 3);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'early ring release returns from current radius and never reaches distant enemies',
    (tester) async {
      final g = await mount(tester, WeaponType.ringCaster);
      await tester.runAsync(() async {
        final target = await body(g, Vector2(300, 0));
        expect(fire(g), true);
        step(g, .1, held: true);
        step(g, 1);
        expect(target.combatHealth.current, 1000);
        expect(g.arsenal!.frontier.ring, isNull);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'flight and electrical feedback stay bounded and freeze with combat',
    (tester) async {
      for (final weapon in [WeaponType.houndrack, WeaponType.stormOrb]) {
        final g = await mount(tester, weapon);
        await tester.runAsync(() async {
          await body(g, Vector2(180, 0));
          await body(g, Vector2(240, 70));
          fire(g);
          step(g, 1.2, held: weapon == WeaponType.houndrack);
          final cues = (g.audio as _Quiet).cues;
          final flight = cues
              .where((c) => c == 'flight_${weapon.name}.wav')
              .length;
          expect(flight, greaterThan(0));
          expect(flight, lessThanOrEqualTo(6));
          if (weapon == WeaponType.stormOrb) {
            expect(cues, contains('zap_stormOrb.wav'));
            expect(cues, contains('pass_stormOrb.wav'));
          }
          g.gameNotifier.pauseGame();
          final count = cues.length;
          step(g, 1);
          expect(cues.length, count);
        });
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'old frontier saves remain readable and selected cutter art releases on a training switch',
    (tester) async {
      final g = await mount(tester, WeaponType.ringCaster);
      await tester.runAsync(() async {
        fire(g);
        step(g, .1, held: true);
        final old = copy(g.arsenal!.checkpoint());
        final f = old['frontier'];
        f['schema'] = 1;
        for (final key in ['origin', 'heading', 'gunLaunched']) {
          f['ring'].remove(key);
        }
        ArsenalSystem.validate(
          old,
          WeaponType.ringCaster,
          power: g.gameNotifier.weaponPower,
        );
        g.arsenal!.restore(old);
        expect(g.arsenal!.frontier.ring!.gunLaunched, false);
        g.gameNotifier.pauseGame();
        expect(await g.changeTrainingWeapon(WeaponType.carbine), true);
        expect(g.ringArtReady, false);
        expect(await g.changeTrainingWeapon(WeaponType.ringCaster), true);
        expect(g.ringArtReady, true);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      expect(g.ringArtReady, false);
    },
  );

  for (final weapon in [
    WeaponType.houndrack,
    WeaponType.stormOrb,
    WeaponType.ringCaster,
  ]) {
    testWidgets(
      '${weapon.name} saves paid phases, freezes pause and rejects malformed state',
      (tester) async {
        final g = await mount(tester, weapon);
        await tester.runAsync(() async {
          await body(g, Vector2(240, 80));
          expect(fire(g), true);
          step(g, .12, held: weapon == WeaponType.ringCaster);
          final before = copy(g.arsenal!.checkpoint());
          g.gameNotifier.pauseGame();
          step(g, 1);
          expect(g.arsenal!.checkpoint(), before);
          final save = g.checkpoint();
          expect(RunCheckpoint.valid(copy(save)), true);
          g.arsenal!.restore(copy(before));
          expect(g.arsenal!.checkpoint(), before);
          final bad = copy(before);
          final frontier = bad['frontier'] as Map;
          if (weapon == WeaponType.ringCaster) {
            frontier['ring']['outward'] = [1, 1];
          } else {
            frontier['shots'][0]['direction'] = [double.nan, 0];
          }
          expect(
            () => ArsenalSystem.validate(
              bad,
              weapon,
              power: g.gameNotifier.weaponPower,
            ),
            throwsFormatException,
          );
          g.gameNotifier.playGame();
          step(g, 4);
          expect(g.arsenal!.frontier.shots, isEmpty);
          expect(g.arsenal!.frontier.ring, isNull);
        });
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('ring emerges slowly from the muzzle before opening downrange', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await mount(tester, WeaponType.ringCaster);
    await tester.runAsync(() async {
      fire(g);
    });
    var previousRear = double.negativeInfinity;
    for (final phase in [
      ('launch', .03, true),
      ('opening', .27, true),
      ('open', .8, true),
      ('recall', .18, false),
    ]) {
      await tester.runAsync(() async {
        step(g, phase.$2, held: phase.$3);
      });
      final r = g.arsenal!.frontier.ring!;
      if (phase.$3) {
        final rear = r.center.x - r.radius;
        expect(rear, greaterThan(previousRear));
        previousRear = rear;
      }
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('frontier-review')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/frontier-review').create(recursive: true);
        await File('build/frontier-review/ring-${phase.$1}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'all three render actual loaded art and moving effects for review',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final weapon in [
        WeaponType.houndrack,
        WeaponType.stormOrb,
        WeaponType.ringCaster,
      ]) {
        final g = await mount(tester, weapon);
        await tester.runAsync(() async {
          await body(
            g,
            weapon == WeaponType.houndrack
                ? Vector2(400, 60)
                : Vector2(200, 90),
          );
          fire(g);
          step(
            g,
            weapon == WeaponType.ringCaster ? .65 : .35,
            held: weapon != WeaponType.stormOrb,
          );
        });
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('frontier-review')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/frontier-review').create(recursive: true);
          await File('build/frontier-review/${weapon.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  test(
    'admin component values and supported upgrades use actual profile policy',
    () {
      final v = LiveBalance.bundled.values;
      expect(frontierComponents('houndrack', v)['Guidance (rad/s)'], 4.5);
      expect(frontierComponents('stormOrb', v)['Arc damage per tick'], 1.2);
      expect(
        frontierComponents('ringCaster', v)['Return damage per body'],
        5.625,
      );
      for (final w in [
        WeaponType.houndrack,
        WeaponType.stormOrb,
        WeaponType.ringCaster,
      ]) {
        expect(
          weaponSupportsPowerUp(w, PowerUp.numberOfBulletsPerShotIncrease),
          false,
        );
        expect(weaponSupportsPowerUp(w, PowerUp.ricochet), false);
        expect(w.availableOnline, false);
      }
      expect(
        weaponSupportsPowerUp(WeaponType.ringCaster, PowerUp.rapidFire),
        false,
      );
    },
  );
}
