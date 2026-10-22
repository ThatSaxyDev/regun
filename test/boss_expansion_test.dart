import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/boss_attack.dart';
import 'package:regun/components/enemies/hostile_area.dart';
import 'package:regun/components/weapons/combat_effect.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/components/enemies/boss_encounter.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/expansion_boss.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/components/enemies/shadow_projectile.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/models/combat_health.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/systems/boss_attack_shape.dart';
import 'package:regun/systems/boss_encounter_runtime.dart';
import 'package:regun/systems/encounter_director.dart';
import 'package:regun/systems/run_random.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

class _Audio extends SoloudPlay {
  @override
  Future<void> play(String path) async {}
  @override
  Future<void> playMusic(String path) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool paused) {}
}

class _Store extends RunStore {
  @override
  Future<bool> write(Map<String, dynamic> snapshot) async => true;
  @override
  Future<void> clear({String? expectedRunId}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('ring gap, swept arc and trace share committed, body-safe geometry', () {
    final source = Vector2.zero();
    final ring = BossAttackShape.ring(source, 500, angle: 0);
    source.x = 1000;
    expect(ring.points.first, Vector2.zero());
    expect(ring.hits(Vector2(450, 0), 1, previous: .8), isFalse);
    expect(ring.hits(Vector2(0, 450), 1, previous: .8), isTrue);
    expect(ring.hits(Vector2(0, 100), 1, previous: .8), isFalse);
    final sweep = BossAttackShape.sweep(
      Vector2.zero(),
      500,
      angle: 0,
      arc: 1.57,
    );
    expect(sweep.hits(Vector2(300, 300), 1), isTrue);
    expect(sweep.hits(Vector2(-300, -300), 1), isFalse);
    expect(sweep.hits(Vector2(300, 300), .1), isFalse);
    final annular = BossAttackShape.sweep(
      Vector2.zero(),
      540,
      angle: -1.85,
      arc: 3.7,
      innerRadius: 180,
      width: 30,
    );
    expect(annular.hits(Vector2(130, 0), 1), isFalse);
    expect(annular.hits(Vector2(300, 0), 1), isTrue);
    expect(annular.hits(Vector2(-300, 0), 1), isFalse);
    final trace = BossAttackShape.trace([
      Vector2.zero(),
      Vector2(200, 0),
      Vector2(200, 200),
    ]);
    expect(trace.hits(Vector2(100, 0), .3), isTrue);
    expect(trace.hits(Vector2(100, 0), .9, previous: .8), isFalse);
  });

  test(
    'pair attack ownership waits for lingering hazards and survives one death',
    () {
      final runtime = BossEncounterRuntime();
      final a = PositionComponent(), b = PositionComponent();
      runtime.add(a);
      runtime.add(b);
      expect(runtime.claim(a), isTrue);
      expect(runtime.claim(b), isFalse);
      runtime.release(a);
      runtime.advance((_) => true);
      expect(runtime.claim(b), isFalse);
      runtime.advance((_) => false);
      expect(runtime.claim(b), isTrue);
      runtime.remove(a);
      expect(runtime.live.toList(), [b]);
      expect(runtime.claim(a), isFalse);
      runtime.remove(b);
      expect(runtime.isEmpty, isTrue);
    },
  );

  test(
    'all eight bosses are randomized from the first encounter and saved',
    () {
      final director = EncounterDirector(), rng = RunRandom(61);
      final first = director.chooseBoss(rng);
      final copy = EncounterDirector()..restore(director.toJson());
      final remaining = [for (var i = 0; i < 7; i++) director.chooseBoss(rng)];
      expect({first, ...remaining}.length, 8);
      expect(copy.chooseBoss(RunRandom(999)), remaining.first);
      final openings = {
        for (var seed = 1; seed <= 100; seed++)
          EncounterDirector().chooseBoss(RunRandom(seed)),
      };
      expect(openings, BossKind.values.toSet());
      expect(director.chooseBoss(rng), isNot(remaining.last));
    },
  );

  Future<RegunGame> mount(
    WidgetTester tester, {
    Loadout loadout = const Loadout(training: true),
    Map<String, dynamic>? snapshot,
  }) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
          child: MaterialApp(
            home: RepaintBoundary(
              key: const Key('boss-capture'),
              child: BaseView(
                key: UniqueKey(),
                loadout: loadout,
                runStore: _Store(),
                resumeSnapshot: snapshot,
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
      game.update(2); // Finish deployment before exercising combat.
    });
    return game;
  }

  Future<void> tick(WidgetTester tester, RegunGame game, int frames) =>
      tester.runAsync(() async {
        for (var i = 0; i < frames; i++) {
          game.update(1 / 60);
          if (i % 10 == 0) await game.ready();
        }
        await game.ready();
      });

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('boss-capture')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final font in ['PressStart2P', 'Orbitron']) {
      await (FontLoader(
        font,
      )..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf'))).load();
    }
  });

  testWidgets(
    'five complete boss controllers animate, commit, interrupt and retire safely',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final kind in BossKind.values.where((kind) => kind.expansion)) {
        final game = await mount(tester);
        await tester.runAsync(() async {
          game.practiceBoss(kind);
          await game.ready();
        });
        final boss = game.activeBoss! as ExpansionBoss;
        if (kind == BossKind.bellkeeper) {
          final original = boss.position.clone();
          boss.position.setValues(250, 0);
          boss.sequence = 2;
          final echo = boss.plan();
          expect(echo.cues.length, 2);
          expect(
            game.bossMoveHasEscape(echo.cues),
            isTrue,
            reason:
                'Delayed opposite gaps must not be combined into a solid disk',
          );
          boss.sequence = 0;
          boss.position.setFrom(original);
        }
        for (var attempt = 0; attempt < 60; attempt++) {
          await tick(tester, game, 15);
          if (boss.phase == ExpansionPhase.warning &&
              game.world.children.whereType<BossAttack>().isNotEmpty) {
            break;
          }
        }
        expect(
          boss.sequence,
          greaterThan(0),
          reason: '${kind.name} must actually attack',
        );
        expect(boss.currentMove, isNotNull);
        expect(game.world.children.whereType<BossAttack>(), isNotEmpty);
        final locked = game.world.children
            .whereType<BossAttack>()
            .first
            .shape
            .points
            .map((p) => p.clone())
            .toList();
        game.myPlayer.position.add(Vector2(-80, 90));
        final actual = game.world.children
            .whereType<BossAttack>()
            .first
            .shape
            .points;
        expect(actual, orderedEquals(locked));
        await capture(tester, 'vfx-${kind.name}-warning');
        final elapsed = boss.clock;
        game.pauseGame();
        await tick(tester, game, 120);
        expect(boss.clock, elapsed);
        game.resumeGame();
        if (game.weakPoints.isNotEmpty) {
          final point = game.weakPoints.first;
          final bullet = BulletComponent(
            direction: Vector2(1, 0),
            pierce: 2,
            damage: 1,
            primary: false,
          );
          await tester.runAsync(() async {
            await game.world.add(bullet);
            await game.ready();
          });
          final before = boss.combatHealth.current;
          bullet.onCollisionStart({}, point);
          bullet.onCollisionStart({}, boss);
          expect(
            boss.combatHealth.current,
            closeTo(before - .5, .001),
            reason: 'Piercing cannot hit part and body twice',
          );
          bullet.removeFromParent();
        }
        for (
          var frame = 0;
          frame < 120 && boss.phase == ExpansionPhase.warning;
          frame++
        ) {
          await tick(tester, game, 1);
        }
        expect(boss.phase, ExpansionPhase.active);
        await tick(tester, game, 6);
        await capture(tester, 'vfx-${kind.name}-active');
        expect(boss.body.animation!.loop, isFalse);
        final lastRelease = boss.currentMove!.cues
            .map((cue) => cue.delay + cue.warning)
            .reduce(math.max);
        await tick(tester, game, ((lastRelease + .6 - boss.clock) * 60).ceil());
        if (boss.phase == ExpansionPhase.active) {
          expect(
            boss.body.animation!.loop,
            isTrue,
            reason: 'A long hazard must not freeze the final impact pose',
          );
        } else {
          expect(boss.phase, ExpansionPhase.recovery);
        }
        boss.takeDamage(boss.combatHealth.maximum * .51);
        expect(boss.enraged, isTrue);
        if (game.weakPoints.isNotEmpty) {
          final point = game.weakPoints.first;
          point.takeDamage(20);
          expect(boss.phase, ExpansionPhase.recovery);
          expect(boss.clock, 0);
          expect(point.takeDamage(20), isFalse);
        }
        game.myPlayer.position.setZero();
        await tick(
          tester,
          game,
          9,
        ); // Let hit flash clear before visual inspection.
        await tester.pump();
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('boss-capture')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/test-previews').create(recursive: true);
          await File('build/test-previews/expansion-${kind.name}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        await tick(tester, game, 600);
        expect(boss.phase, isNot(ExpansionPhase.defeated));
        expect(game.runtimeCounts['hazards']!, lessThanOrEqualTo(8));
        expect(
          RegunArt.shared.decodedBytes,
          lessThanOrEqualTo(32 * 1024 * 1024),
        );
        boss.takeDamage(100000);
        expect(game.activeBoss, isNull);
        game.resumeGame();
        // Practice awards a core choice; resolve it before advancing the death clip.
        while (game.gameState.gameplayState == GameplayState.powerup) {
          game.gameNotifier.applyPowerUp(
            game.gameState.powerUpChoices.first,
            offerId: game.gameState.offerId,
          );
        }
        await tick(tester, game, 90);
        expect(game.world.children.whereType<BossAttack>(), isEmpty);
        expect(game.weakPoints, isEmpty);
        expect(RegunArt.shared.contains('bosses/${kind.name}'), isFalse);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'random Boss Rush draws all eight, waits for both deaths and preserves builds',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = await mount(tester);
      game.random.state = 34;
      game.startBossRush();
      final seen = <BossKind>{};
      var pairs = 0;
      for (var round = 0; round < 12; round++) {
        await tick(tester, game, 210);
        final actors = game.bosses.toList();
        expect(actors.length, inInclusiveRange(1, 2));
        final roundBefore = game.bossRushRound;
        seen.addAll(actors.map((a) => (a as BossEncounter).kind));
        expect(
          actors.map((a) => (a as BossEncounter).kind).toSet().length,
          actors.length,
        );
        await tick(tester, game, 420);
        expect(game.gameState.health, game.gameState.maxHealth);
        expect(game.runtimeCounts['hazards']!, lessThanOrEqualTo(8));
        expect(
          RegunArt.shared.decodedBytes,
          lessThanOrEqualTo(32 * 1024 * 1024),
        );
        (actors.first as CombatEnemy).takeDamage(100000);
        if (actors.length == 2) {
          pairs++;
          expect(game.bosses.single, actors.last);
          await tick(tester, game, 190);
          expect(game.bossRushRound, roundBefore);
          (actors.last as CombatEnemy).takeDamage(100000);
        }
        expect(game.bosses, isEmpty);
        expect(game.gameState.gameplayState, GameplayState.playing);
      }
      expect(seen, BossKind.values.toSet());
      expect(pairs, greaterThan(0));
      expect(game.gameState.pendingCores, 0);
      expect(game.gameState.xP, 0);
      game.pauseGame();
      await tester.pump();
      await tester.ensureVisible(find.text('BOSS PRACTICE'));
      await tester.tap(find.text('BOSS PRACTICE'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('RESTART RUSH'), findsOneWidget);
      expect(find.text('NEXT ROUND'), findsOneWidget);
      game.nextBossRushRound();
      await tick(tester, game, 240);
      expect(game.bosses, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'committed attacks warn, absorb one guard hit, freeze and retire',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = await mount(tester, loadout: const Loadout());
      final checkpoint = game.gameNotifier.checkpoint();
      checkpoint['state'] = game.gameState.copyWith(guard: true).toJson();
      game.gameNotifier.restoreCheckpoint(checkpoint);
      game.resumeGame();
      game.gameNotifier.advanceTime(1);
      final owner = CombatHealth(10);
      final attack = BossAttack(
        shape: BossAttackShape.circle(Vector2.zero(), 90),
        owner: owner,
        warning: 1,
        active: 1.5,
        damage: 2,
      );
      await tester.runAsync(() async {
        game.addBossAttack(attack);
        await game.ready();
      });
      await tick(tester, game, 30);
      expect(game.gameState.guard, isTrue);
      game.pauseGame();
      final age = attack.age;
      await tick(tester, game, 120);
      expect(attack.age, age);
      game.resumeGame();
      await tick(tester, game, 45);
      expect(game.gameState.guard, isFalse);
      expect(game.gameState.health, game.gameState.maxHealth);
      await tick(tester, game, 65);
      expect(
        game.gameState.health,
        game.gameState.maxHealth,
        reason: 'A guarded strike cannot damage again after invulnerability expires',
      );
      final next = BossAttack(
        shape: BossAttackShape.circle(Vector2.zero(), 90),
        owner: owner,
        warning: 0,
        active: 2,
        damage: 2,
      );
      await tester.runAsync(() async {
        game.addBossAttack(next);
        await game.ready();
      });
      await tick(tester, game, 1);
      expect(game.gameState.health, game.gameState.maxHealth - 2);
      owner.damage(10);
      await tick(tester, game, 1);
      expect(next.isRemoving || next.isRemoved, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'every new boss supports all weapons, survivors and both arenas',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final arena in ArenaType.values) {
        for (final survivor in CharacterType.values) {
          for (final weapon in WeaponType.values) {
            final game = await mount(
              tester,
              loadout: Loadout(
                training: true,
                arena: arena,
                character: survivor,
                weapon: weapon,
              ),
            );
            for (final kind in BossKind.values.where(
              (kind) => kind.expansion,
            )) {
              late ExpansionBoss boss;
              await tester.runAsync(() async {
                game.startBossRush();
                game.myPlayer.position.setZero();
                game.practiceBoss(kind);
                game.bossRush =
                    true; // Suppress adds/rewards while exercising this kit.
                await game.ready();
                boss = game.activeBoss! as ExpansionBoss;
                boss.position.setValues(250, 0);
                for (var frame = 0; frame < 900; frame++) {
                  final t = frame / 30;
                  game.movementJoystick.delta.setValues(
                    math.cos(t) * 25,
                    math.sin(t) * 25,
                  );
                  final aim = boss.position - game.myPlayer.position;
                  game.weaponJoystick.delta.setFrom(aim.normalized() * 80);
                  if (frame == 300 && !boss.combatHealth.isDead) {
                    boss.takeDamage(
                      math.max(
                        0,
                        boss.combatHealth.current -
                            boss.combatHealth.maximum * .49,
                      ),
                    );
                  }
                  game.update(1 / 30);
                  if (weapon.firesOnRelease && frame % 40 == 20) {
                    game.arsenal!.releaseAim(aim.normalized());
                  }
                  if (frame % 15 == 0) await game.ready();
                }
                game.resetInput();
                await game.ready();
              });
              expect(
                boss.sequence,
                greaterThan(1),
                reason: '$arena/$survivor/$weapon/$kind',
              );
              expect(
                boss.combatHealth.current,
                lessThan(boss.combatHealth.maximum),
              );
              expect(game.runtimeCounts['hazards']!, lessThanOrEqualTo(8));
              expect(game.gameState.health, game.gameState.maxHealth);
              expect(tester.takeException(), isNull);
            }
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets('all distinct boss pairs remain bounded in both arenas', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final arena in ArenaType.values) {
      final game = await mount(
        tester,
        loadout: Loadout(training: true, arena: arena),
      );
      for (var first = 0; first < BossKind.values.length; first++) {
        for (
          var second = first + 1;
          second < BossKind.values.length;
          second++
        ) {
          await tester.runAsync(() async {
            game.startBossRush();
            game.myPlayer.position.setZero();
            game.practiceBoss(BossKind.values[first]);
            game.bossRush = true;
            game.spawnBoss(BossKind.values[second], companion: true);
            await game.ready();
            expect(game.bosses.length, 2);
            for (final actor in game.bosses) {
              final boss = actor as CombatEnemy;
              boss.takeDamage(boss.combatHealth.maximum * .51);
            }
            for (var frame = 0; frame < 900; frame++) {
              final angle = frame / 80;
              game.movementJoystick.delta.setValues(
                math.cos(angle) * 50,
                math.sin(angle) * 50,
              );
              game.update(1 / 30);
              if (frame % 15 == 0) await game.ready();
              expect(game.runtimeCounts['hazards']!, lessThanOrEqualTo(8));
            }
            expect(game.bosses.length, 2);
            final actors = game.bosses.toList();
            (actors.first as CombatEnemy).takeDamage(100000);
            expect(game.bosses.single, actors.last);
            (actors.last as CombatEnemy).takeDamage(100000);
            await game.ready();
            expect(game.bosses, isEmpty);
          });
          expect(
            tester.takeException(),
            isNull,
            reason:
                '$arena/${BossKind.values[first]}/${BossKind.values[second]}',
          );
        }
      }
      game.resetInput();
      await tester.pumpWidget(const SizedBox());
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets(
    'Arc Caster clears three spaced targets and respects walls and proc bounds',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = await mount(
        tester,
        loadout: const Loadout(
          training: true,
          weapon: WeaponType.arcCaster,
          arena: ArenaType.foundry,
        ),
      );
      expect(game.gameState.maxBullets, 6);
      expect(game.gameState.bulletSpeed, 1050);
      final targets = [
        for (var i = 0; i < 3; i++)
          EnemyComponent(position: Vector2(170 + i * 150.0, 0)),
      ];
      await tester.runAsync(() async {
        await game.world.addAll(targets);
        await game.ready();
        game.weaponJoystick.delta.setValues(80, 0);
        game.spawnShotgunBullets();
        game.resetInput();
        await game.ready();
        for (var i = 0; i < 12; i++) {
          game.update(1 / 60);
          await game.ready();
        }
        game.resetInput();
      });
      expect(
        targets.every((e) => e.combatHealth.isDead),
        isTrue,
        reason: 'A base discharge should kill three ordinary scorpions through its two jumps',
      );
      expect(game.gameState.noOfBullets, 5);
      await capture(tester, 'vfx-arc-caster-chain');
      final wall = game.geometry.obstacles.first;
      final across = [
        Enemy2Component(position: Vector2(wall.center.dx, wall.top - 55)),
        Enemy2Component(position: Vector2(wall.center.dx, wall.bottom + 55)),
      ];
      final chain = [
        for (var i = 0; i < 4; i++)
          Enemy2Component(position: Vector2(-350 + i * 150.0, 700)),
      ];
      await tester.runAsync(() async {
        await game.world.addAll([...across, ...chain]);
        await game.ready();
      });
      game.combat.hit(across.first, .1);
      expect(
        across.last.combatHealth.current,
        across.last.combatHealth.maximum,
        reason: 'Chain lightning cannot pass through arena columns',
      );
      game.combat.hit(chain.first, 3);
      expect(chain[1].combatHealth.current, closeTo(6 - 3 * .85, .001));
      expect(chain[2].combatHealth.current, closeTo(6 - 3 * .85 * .85, .001));
      expect(
        chain[3].combatHealth.current,
        6,
        reason: 'Base chains stop after two jumps and do not recursively proc',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'laser renders an unbroken bright core instead of tiled sprites',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xff141117), BlendMode.src);
      AttackVfx.laser(
        canvas,
        const Offset(20, 60),
        const Offset(620, 60),
        24,
        warning: false,
        progress: .5,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(640, 120);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      for (var x = 21; x < 620; x++) {
        final offset = (60 * 640 + x) * 4;
        expect(bytes!.getUint8(offset), greaterThan(220));
        expect(bytes.getUint8(offset + 1), greaterThan(200));
        expect(bytes.getUint8(offset + 2), greaterThan(170));
      }
      image.dispose();
      picture.dispose();
    },
  );

  testWidgets(
    'Marshal beams start at the gun, hit their visible route and freeze',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final arena in ArenaType.values) {
        final game = await mount(tester, loadout: Loadout(arena: arena));
        await tester.runAsync(() async {
          game.myPlayer.position.setValues(-180, 0);
          game.spawnBoss(BossKind.marshal);
          await game.ready();
          final boss = game.activeBoss! as LastMarshalBoss;
          boss.position.setValues(380, 0);
          expect(boss.beginMove(), isTrue);
          await game.ready();
          final shots = game.world.children.whereType<BossAttack>().toList();
          expect(shots, hasLength(2));
          final shot = shots.first;
          expect(shot.material, AttackMaterial.laser);
          expect(shot.priority, greaterThan(boss.priority));
          expect(
            shot.shape.points.first,
            boss.shotOrigin(game.myPlayer.position),
          );
          expect(
            shot.shape.hits(game.myPlayer.position, 1, body: 0),
            isTrue,
            reason:
                'Muzzle offset must not cause the laser to miss its aim point',
          );
          final locked = shot.shape.points
              .map((point) => point.clone())
              .toList();
          final health = game.gameState.health;
          shot.update(shot.warning - .01);
          expect(game.gameState.health, health);
          shot.update(.03);
          expect(game.gameState.health, health - 1);
          shot.update(.06);
          expect(game.gameState.health, health - 1, reason: 'One hit per beam');
          game.myPlayer.position.y += 120;
          expect(shot.shape.points, orderedEquals(locked));
          game.pauseGame();
          final age = shot.age;
          shot.update(.2);
          expect(shot.age, age);
          game.resumeGame();
        });
        await capture(tester, 'marshal-continuous-beam-${arena.name}');
        await tester.runAsync(() async {
          game.preferences.reducedMotion = true;
        });
        await capture(tester, 'marshal-beam-reduced-${arena.name}');
        await tick(tester, game, 120);
        expect(game.runtimeCounts['hazards']!, lessThanOrEqualTo(8));
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'explosions stay grounded, fade and preserve damage on both arenas',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final arena in ArenaType.values) {
        final game = await mount(
          tester,
          loadout: Loadout(training: true, arena: arena),
        );
        await tester.runAsync(() async {
          final target = Enemy2Component(position: Vector2(110, 0));
          await game.world.add(target);
          await game.ready();
          final before = target.combatHealth.current;
          game.explode(Vector2(40, 0), radius: 155, damage: 1);
          await game.ready();
          expect(target.combatHealth.current, before - 1);
          final effect = game.world.children
              .whereType<CombatEffect>()
              .singleWhere((effect) => effect.material == AttackMaterial.ember);
          expect(effect.priority, lessThan(game.myPlayer.priority));
          effect.update(.10);
          game.pauseGame();
          game.update(.20);
          expect(effect.age, .10);
          game.resumeGame();
        });
        await capture(tester, 'explosion-grounded-${arena.name}');
        await tester.runAsync(() async {
          final effect = game.world.children
              .whereType<CombatEffect>()
              .singleWhere((effect) => effect.material == AttackMaterial.ember);
          effect.update(.20);
        });
        await capture(tester, 'explosion-settle-${arena.name}');
        await tester.runAsync(() async {
          game.preferences.reducedMotion = true;
          game.explode(Vector2(-130, 80), radius: 100, damage: 0);
          await game.ready();
        });
        await capture(tester, 'explosion-reduced-${arena.name}');
        await tick(tester, game, 40);
        expect(
          game.world.children.whereType<CombatEffect>().where(
            (effect) => effect.material == AttackMaterial.ember,
          ),
          isEmpty,
        );
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('Magistrate sends multiple straight chains toward the player', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final signatures = <String>{};
    for (final arena in ArenaType.values) {
      final game = await mount(tester, loadout: Loadout(arena: arena));
      await tester.runAsync(() async {
        game.myPlayer.position.setValues(-600, -1400);
        game.spawnBoss(BossKind.magistrate);
        await game.ready();
        final boss = game.activeBoss! as MagistrateBoss;
        boss.position.setValues(-1000, -1400);
        for (final enraged in [false, true]) {
          if (enraged) {
            boss.combatHealth.damage(boss.combatHealth.maximum * .51);
          }
          for (var seed = 1; seed <= 24; seed++) {
            game.random.state = seed;
            final move = boss.plan();
            expect(move.cues.length, enraged ? 7 : 5);
            expect(game.bossMoveHasEscape(move.cues), isTrue);
            signatures.add('${move.cues.length}/${move.name}');
            for (final cue in move.cues) {
              expect(cue.shape.kind, BossShapeKind.line);
              expect(cue.shape.points, hasLength(2));
              expect(cue.shape.points.first, boss.position);
              final ray = (cue.shape.points.last - boss.position).normalized();
              final toward = (game.myPlayer.position - boss.position)
                  .normalized();
              expect(
                ray.dot(toward),
                greaterThan(.62),
                reason: 'Every chain must threaten the player-facing sector',
              );
              expect(
                cue.shape.points.last.distanceTo(boss.position),
                greaterThan(90),
              );
              expect(
                game.segmentBlocked(
                  cue.shape.points.first,
                  cue.shape.points.last,
                ),
                isFalse,
              );
            }
            final committed = move.cues.first.shape.points.last.clone();
            game.myPlayer.position.y += 20;
            expect(move.cues.first.shape.points.last, committed);
            game.myPlayer.position.y -= 20;
          }
        }
        // Capture the complete forward fan, not an off-screen radial pattern.
        boss.position.setValues(380, 0);
        game.myPlayer.position.setValues(-180, 0);
        game.random.state = 11;
        game.addHostileArea(Vector2(-1200, -1000), radius: 50, warning: 2);
        game.addHostileArea(Vector2(-1000, -1000), radius: 50, warning: 2);
        await game.ready();
        expect(
          boss.beginMove(),
          isFalse,
          reason: 'Wait for room for all seven chains instead of dropping some',
        );
        expect(game.world.children.whereType<BossAttack>(), isEmpty);
        for (final hazard
            in game.world.children.whereType<HostileArea>().toList()) {
          hazard.removeFromParent();
        }
        await game.ready();
        expect(boss.beginMove(), isTrue);
        await game.ready();
        for (final attack in game.world.children.whereType<BossAttack>()) {
          attack.update(.4);
        }
      });
      await capture(tester, 'magistrate-forward-fan-${arena.name}');
      await tester.runAsync(() async {
        final boss = game.activeBoss! as MagistrateBoss;
        boss.cancelAttacks();
        // Clipping near the wall shortens spokes without bending them.
        boss.position.setValues(game.geometry.bounds.floor.right - 130, -1400);
        for (final cue in boss.plan().cues) {
          expect(cue.shape.points, hasLength(2));
          expect(cue.shape.points.first, boss.position);
          expect(
            game.geometry.bounds.floor.contains(
              cue.shape.points.last.toOffset(),
            ),
            isTrue,
          );
          expect(
            game.segmentBlocked(cue.shape.points.first, cue.shape.points.last),
            isFalse,
          );
        }
      });
      await tester.pumpWidget(const SizedBox());
    }
    expect(signatures.length, greaterThanOrEqualTo(4));
  });

  testWidgets(
    'Skitter keeps shorter with direct and predicted locked attacks',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = await mount(tester);
      var direct = 0, predicted = 0;
      await tester.runAsync(() async {
        for (var seed = 1; seed <= 24; seed++) {
          game.myPlayer.position.setValues(-300, -1400);
          game.movementJoystick.delta.setValues(0, 80);
          game.random.state = seed;
          final runner = ArenaEnemy(
            EnemyKind.runner,
            elite: seed.isEven,
            position: Vector2(-740, -1400),
          )..clock = 1.21;
          await game.world.add(runner);
          await game.ready();
          runner.update(0);
          expect(runner.phase, 1, reason: 'Commit from 440 units away');
          runner.update(.75);
          expect(runner.phase, 2);
          // Change direction after commitment: the attack must not home in.
          game.movementJoystick.delta.setValues(0, -80);
          final start = runner.position.clone();
          runner.update(.1);
          final heading = (runner.position - start).normalized();
          if (heading.y.abs() < .01) {
            direct++;
          } else {
            predicted++;
          }
          game.myPlayer.position.y -= 300;
          runner.update(.1);
          final next = (runner.position - start).normalized();
          expect(next.distanceTo(heading), lessThan(.001));
          runner.update(1);
          expect(runner.phase, 3);
          expect(runner.position.distanceTo(start), greaterThan(400));
          expect(runner.position.distanceTo(start), lessThanOrEqualTo(521));
          runner.removeFromParent();
          await game.ready();
        }
        game.movementJoystick.delta.setZero();
        game.myPlayer.position.setValues(-300, -1400);
        game.setTrainingDamage(true);
        game.random.state = 2; // Direct attack.
        final runner = ArenaEnemy(
          EnemyKind.runner,
          position: Vector2(-740, -1400),
        )..clock = 1.21;
        await game.world.add(runner);
        await game.ready();
        runner.update(0);
        runner.update(.75);
        final health = game.gameState.health;
        runner.update(
          1,
        ); // A coarse step must still hit across the player's body.
        expect(game.gameState.health, health - 1);
        runner.removeFromParent();
        await game.ready();
        // A long leap still cannot cross another enemy's occupied body.
        final blocker = Enemy2Component(position: Vector2(-500, -1400));
        final blocked = ArenaEnemy(
          EnemyKind.runner,
          position: Vector2(-740, -1400),
        )..clock = 1.21;
        await game.world.addAll([blocker, blocked]);
        await game.ready();
        game.random.state = 2;
        blocked.update(0);
        blocked.update(.75);
        blocked.update(1);
        expect(blocked.position.x, lessThan(blocker.position.x - 75));
        blocker.removeFromParent();
        blocked.removeFromParent();
        await game.ready();
        game.myPlayer.position.setValues(220, 90);
        final preview = ArenaEnemy(
          EnemyKind.runner,
          position: Vector2(-220, 90),
        )..clock = 1.21;
        await game.world.add(preview);
        await game.ready();
        preview.update(0);
        preview.update(.35);
        game.update(0);
      });
      await capture(tester, 'skitter-grounded-leap-warning');
      expect(direct, greaterThan(5));
      expect(predicted, greaterThan(5));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in [BossKind.saint, BossKind.magistrate]) {
    for (final dodge in [false, true]) {
      testWidgets(
        '${kind.name} threatens straight retreat and rewards a warned sidestep $dodge',
        (tester) async {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final game = await mount(tester, loadout: const Loadout());
          game.myPlayer.position.setValues(-600, -1400);
          late ExpansionBoss boss;
          await tester.runAsync(() async {
            game.spawnBoss(kind);
            await game.ready();
            boss = game.activeBoss! as ExpansionBoss;
            boss.position.setValues(-1000, -1400);
            game.movementJoystick.delta.setValues(80, 0);
            var dodged = false;
            Vector2? chainGap;
            var avoidedSequence = -1;
            for (var frame = 0; frame < 330; frame++) {
              for (final actor in game.liveEnemies.toList()) {
                if (!identical(actor, boss)) actor.removeFromParent();
              }
              if (dodge && !dodged && boss.phase == ExpansionPhase.warning) {
                dodged = true;
              }
              // Drive a sustained intent each frame, matching a held pointer.
              // Flame resets a directly assigned delta without a drag owner.
              if (dodge &&
                  kind == BossKind.magistrate &&
                  boss.phase == ExpansionPhase.warning &&
                  boss.sequence != avoidedSequence) {
                avoidedSequence = boss.sequence;
                chainGap = null;
                final origin = game.myPlayer.position;
                for (
                  var distance = 45.0;
                  distance <= 225 && chainGap == null;
                  distance += 45
                ) {
                  for (var direction = 0; direction < 24; direction++) {
                    final angle = direction * math.pi / 12;
                    final candidate =
                        origin +
                        Vector2(math.cos(angle), math.sin(angle)) * distance;
                    if (candidate.distanceTo(boss.position) < 120 ||
                        game.segmentBlocked(origin, candidate)) {
                      continue;
                    }
                    final constrained = candidate.clone();
                    game.constrainActor(constrained, 30);
                    if (constrained.distanceTo(candidate) > 1) continue;
                    if (boss.currentMove!.cues.every(
                      (cue) => !cue.shape.hits(candidate, 1, body: 38),
                    )) {
                      chainGap = candidate;
                      break;
                    }
                  }
                }
                expect(
                  chainGap,
                  isNotNull,
                  reason: 'A reachable gap must exist in the forward volley',
                );
              }
              if (chainGap != null) {
                // Read the fan and settle between lanes. Blindly holding a
                // perpendicular direction would cross the neighboring chains.
                final delta = chainGap - game.myPlayer.position;
                game.movementJoystick.delta.setFrom(
                  delta.length < 3 ? Vector2.zero() : delta.normalized() * 80,
                );
              } else {
                game.movementJoystick.delta.setValues(
                  dodged ? 0 : 80,
                  dodged ? 80 : 0,
                );
              }
              game.update(1 / 60);
              if (frame % 6 == 0) await game.ready();
            }
          });
          expect(boss.sequence, greaterThan(0));
          if (dodge) {
            expect(game.gameState.health, game.gameState.maxHealth);
          } else {
            expect(
              game.gameState.health,
              lessThan(game.gameState.maxHealth),
              reason: 'Constant movement along the predicted route must not neutralize the kit',
            );
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'regular enemy warnings and impacts use the same material effects',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = await mount(tester);
      await tester.runAsync(() async {
        game.startBossRush();
        game.bossRushWait = 9999;
        await game.ready();
        await game.world.addAll([
          ArenaEnemy(EnemyKind.runner, position: Vector2(-340, -90))
            ..phase = 1
            ..clock = .2,
          ArenaEnemy(EnemyKind.shield, position: Vector2(-80, 130))
            ..phase = 1
            ..clock = .2,
          ArenaEnemy(EnemyKind.burster, position: Vector2(260, -80))
            ..phase = 1
            ..clock = .2,
          ArenaEnemy(EnemyKind.sentinel, position: Vector2(450, 100)),
        ]);
        game.addHostileArea(
          Vector2(-340, 170),
          radius: 90,
          warning: .8,
          active: 2,
          cause: 'Sentinel',
        );
        game.addHostileArea(
          Vector2(210, 150),
          radius: 90,
          warning: .8,
          active: 2,
          poison: true,
        );
        await game.ready();
        game.update(.05);
        await game.ready();
      });
      await capture(tester, 'vfx-regular-warning');
      await tick(tester, game, 55);
      await capture(tester, 'vfx-regular-impact');
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all eight bosses threaten an open long-distance retreat in both phases',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final kind in BossKind.values) {
        for (final enraged in [false, true]) {
          final game = await mount(tester, loadout: const Loadout());
          late PositionComponent boss;
          await tester.runAsync(() async {
            game.myPlayer.position.setValues(-800, -1400);
            game.spawnBoss(kind);
            await game.ready();
            boss = game.activeBoss!;
            boss.position.setValues(-1800, -1400);
            if (enraged) {
              (boss as CombatEnemy).takeDamage(
                (boss as CombatEnemy).combatHealth.maximum * .51,
              );
            }
            for (var frame = 0; frame < 450; frame++) {
              for (final actor in game.liveEnemies.toList()) {
                if (!identical(actor, boss)) actor.removeFromParent();
              }
              game.movementJoystick.delta.setValues(80, 0);
              game.update(1 / 60);
              if (frame % 6 == 0) await game.ready();
              if (game.gameState.health < game.gameState.maxHealth) break;
            }
          });
          expect(
            game.myPlayer.position.x,
            greaterThan(-500),
            reason: 'A real retreat must be exercised',
          );
          expect(
            game.gameState.health,
            lessThan(game.gameState.maxHealth),
            reason:
                '${kind.name}, phase ${enraged ? 2 : 1}: open space must not neutralize attacks',
          );
          expect(
            game.map.bounds.rect.width,
            greaterThan(4000),
            reason: 'The arena is never shrunk',
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets('faster boss bolts cannot tunnel through a player or a shield', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = await mount(tester, loadout: const Loadout());
    game.gameNotifier.advanceTime(1);
    final shot = ShadowProjectile(
      position: Vector2(-90, 0),
      direction: Vector2(1, 0),
      speed: 1150,
    );
    await tester.runAsync(() async {
      await game.world.add(shot);
      await game.ready();
    });
    shot.update(.16);
    expect(game.gameState.health, game.gameState.maxHealth - 1);
    expect(shot.isRemoving || shot.isRemoved, isTrue);
    final snapshot = game.gameNotifier.checkpoint();
    snapshot['state'] = game.gameState.copyWith(guard: true).toJson();
    game.gameNotifier.restoreCheckpoint(snapshot);
    game.resumeGame();
    game.gameNotifier.advanceTime(1);
    final guarded = ShadowProjectile(
      position: Vector2(-90, 0),
      direction: Vector2(1, 0),
      speed: 1150,
    );
    await tester.runAsync(() async {
      await game.world.add(guarded);
      await game.ready();
    });
    guarded.update(.16);
    expect(game.gameState.health, game.gameState.maxHealth - 1);
    expect(game.gameState.guard, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('schema two restores a damaged pair without transient attacks', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var game = await mount(tester, loadout: const Loadout());
    await tester.runAsync(() async {
      game.spawnBoss(BossKind.bellkeeper);
      game.spawnBoss(BossKind.marshal, companion: true);
      await game.ready();
    });
    for (final boss in game.bosses.toList()) {
      (boss as CombatEnemy).takeDamage(10);
    }
    final snapshot = game.checkpoint();
    expect(RunCheckpoint.valid(snapshot), isTrue);
    game = await mount(tester, loadout: const Loadout(), snapshot: snapshot);
    expect(game.bosses.length, 2);
    expect(game.gameState.gameplayState, GameplayState.paused);
    expect(game.world.children.whereType<BossAttack>(), isEmpty);
    for (final boss in game.bosses) {
      expect(
        (boss as CombatEnemy).combatHealth.current,
        (boss as BossEncounter).kind.baseHealth - 10,
      );
    }
    await tester.pumpWidget(const SizedBox());
  });
}
