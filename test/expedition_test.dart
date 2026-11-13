import 'package:regun/systems/supply_drops.dart';
import 'package:regun/desktop/desktop_controller.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/components/map/expedition_staging.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/components/enemies/expedition_walker.dart';
import 'package:regun/components/enemies/expedition_veteran_enemy.dart';
import 'package:regun/components/enemies/enemy_3_projectile.dart';
import 'package:regun/components/enemies/hostile_area.dart';
import 'package:regun/systems/expedition_signature.dart';
import 'package:regun/components/enemies/combat_enemy.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart' show PositionComponent;
import 'package:regun/systems/arena_geometry.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/walker_boss.dart';
import 'package:regun/components/enemies/lodestar_boss.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/services/expedition_release.dart';
import 'package:regun/services/expedition_progress.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/systems/arena_bounds.dart';
import 'package:regun/systems/walker_combat.dart';
import 'package:regun/systems/expedition.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {
    if (asset.startsWith('supply_charge_')) chargeCues.add(asset);
  }

  final chargeCues = <String>{};
  @override
  Future<void> playMusic(String theme) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool paused) {}
}

class _Store extends RunStore {
  Map<String, dynamic>? saved;
  Map<String, dynamic>? committedDoor;
  bool rejectNext = false;

  @override
  Future<Map<String, dynamic>?> read({
    bool Function(Map<String, dynamic>)? validate,
  }) async {
    final snapshot = saved;
    return snapshot != null && (validate?.call(snapshot) ?? true)
        ? snapshot
        : null;
  }

  @override
  Future<bool> write(Map<String, dynamic> snapshot) async {
    saved = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    return true;
  }

  @override
  Future<bool> writeRecovery(Map<String, dynamic> snapshot) async {
    if (rejectNext) {
      rejectNext = false;
      return false;
    }
    final result = await write(snapshot);
    if ((saved!['expedition'] as Map).containsKey('next')) {
      committedDoor = saved;
    }
    return result;
  }

  @override
  Future<void> clear({String? expectedRunId}) async {
    if (expectedRunId == null || expectedRunId == saved?['id']) saved = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'published pressure is pinned in the run and shares the backend digest',
    () {
      expect(
        ExpeditionRelease.bundled.hash,
        'ebd424b5803c0dde1bdba31e7467452046617e04643a485094604751db5281e3',
      );
      expect(ExpeditionRelease.bundled.startingHearts, 6);
      const release = ExpeditionRelease(
        revision: 8,
        enabled: true,
        pressure: 10,
        repairPercent: 24,
        startingHealth: 8,
      );
      expect(
        release.hash,
        '03057e3ab80269ae892b661b8782899249268986a24cd253e448d5f7491b3bde',
      );
      final run = Expedition(817, release: release)
        ..region = ExpeditionRegion.relay;
      final restored = Expedition.read(run.toJson());
      expect(restored.release.hash, release.hash);
      expect(restored.release.repairPercent, 24);
      expect(restored.release.pressure, 10);
      expect(restored.release.startingHealth, 8);
      expect(
        ExpeditionRelease.read(ExpeditionRelease.bundled.toJson())
            .startingHealth,
        isNull,
      );
      expect(
        restored.pack.length,
        (Expedition(817)..region = ExpeditionRegion.relay).pack.length + 10,
      );
      expect(restored.waveSizes, run.waveSizes);
      expect(
        () => ExpeditionRelease.read({...release.toJson(), 'hash': 'wrong'}),
        throwsFormatException,
      );
    },
  );

  test('Blood Tax requires 70, 65 or 60 kills and persists progress', () {
    expect(
      [
        for (var rank = 1; rank <= 3; rank++)
          ExpeditionSignature.bloodTaxKills(rank),
      ],
      [70, 65, 60],
    );
    final run = Expedition(9, generator: 10)
      ..signatures[ExpeditionSignature.bloodTax] = 1
      ..signatureKills = 69;
    expect(Expedition.read(run.toJson()).signatureKills, 69);
    run.signatureKills = 70;
    expect(() => Expedition.read(run.toJson()), throwsFormatException);
  });

  test('Expedition ramps waves, enemy roles and regional durability', () {
    final run = Expedition(817);
    expect(run.pack.toSet(), {EnemyKind.scorpion, EnemyKind.mummy});
    expect(run.waveLimit, 3);
    expect(run.waveCarryover, 1);
    expect(run.waveSizes.every((size) => size >= 3), isTrue);
    expect(run.spawnInterval, .55);
    expect(Expedition(817, generator: 10).spawnInterval, 1.4);
    run.spawned = run.waveSizes.first;
    final openingGap = run.spawnInterval;
    expect(run.enemyDamage(heavy: true), 1);
    run.room = 1;
    expect(run.pack, contains(EnemyKind.ranged));
    expect(run.pack, isNot(contains(EnemyKind.runner)));
    run.room = 2;
    expect(run.pack, contains(EnemyKind.runner));
    var health = run.enemyHealthScale;
    var impact = run.enemyImpactScale;
    for (final region in ExpeditionRegion.values.skip(1)) {
      run
        ..region = region
        ..room = 2;
      expect(run.enemyHealthScale, greaterThan(health));
      expect(run.enemyImpactScale, lessThan(impact));
      expect(run.waveLimit, greaterThan(2));
      run.spawned = run.waveSizes.first;
      expect(run.spawnInterval, lessThan(openingGap));
      health = run.enemyHealthScale;
      impact = run.enemyImpactScale;
    }
    expect(run.enemyDamage(heavy: true), 2);
    expect(run.enemyDamage(), 2);
    final legacy = Expedition.read(Expedition(817, generator: 4).toJson());
    expect(legacy.enemyHealthScale, 1);
    expect(legacy.pack, contains(EnemyKind.ranged));
  });

  test('fresh seeds vary region length and wave count independently', () {
    for (final region in ExpeditionRegion.values) {
      final lengths = <int>{};
      final counts = <int>{};
      for (var seed = 0; seed < 100; seed++) {
        final run = Expedition(seed)..region = region;
        lengths.add(run.roomCount);
        for (var room = 0; room < run.roomCount; room++) {
          run.room = room;
          final sizes = run.waveSizes;
          counts.add(sizes.length);
          expect(sizes.every((size) => size >= 2), isTrue);
          expect(sizes.reduce((a, b) => a + b), run.pack.length);
          var index = 0;
          for (final size in sizes) {
            for (var inWave = 0; inWave < size; inWave++) {
              run.spawned = index++;
              expect(run.startsWave, inWave == 0);
            }
          }
        }
      }
      expect(lengths, {5, 6, 7, 8});
      expect(counts, {3, 4, 5});
    }
    final old = Expedition(817, generator: 5);
    expect(Expedition.read(old.toJson()).roomCount, 5);
  });

  test('pursuit and damage ramp without drops between Expedition regions', () {
    for (var seed = 0; seed < 60; seed++) {
      final run = Expedition(seed);
      var lastPace = run.enemyPursuitScale;
      var lastDamage = 1;
      var lastHeavyDamage = 1;
      for (final region in ExpeditionRegion.values) {
        run.region = region;
        final count = run.roomCount;
        for (var room = 0; room <= count; room++) {
          run.room = room;
          final pace = run.enemyPursuitScale;
          expect(
            pace,
            room == 0 ? closeTo(lastPace, .00001) : greaterThan(lastPace),
          );
          expect(pace - lastPace, lessThanOrEqualTo(.036));
          final damage = run.enemyDamage();
          final heavyDamage = run.enemyDamage(heavy: true);
          expect(damage, inInclusiveRange(lastDamage, 2));
          expect(heavyDamage, inInclusiveRange(lastHeavyDamage, 2));
          if (region == ExpeditionRegion.breach) expect(heavyDamage, 1);
          if (region == ExpeditionRegion.foundry) expect(damage, 1);
          lastPace = pace;
          lastDamage = damage;
          lastHeavyDamage = heavyDamage;
        }
      }
      expect(lastDamage, 2);
      expect(lastHeavyDamage, 2);
    }
  });

  test('Foundry opens with larger waves and inherited boss variants', () {
    final limits = <int>{};
    for (var seed = 0; seed < 60; seed++) {
      final run = Expedition(seed);
      limits.add(run.bossReinforcements);
      for (final region in ExpeditionRegion.values.skip(1)) {
        run.region = region;
        final veterans = [
          for (var i = 0; i < run.pack.length; i++)
            if ((run..spawned = i).veteran case final veteran?) veteran,
        ];
        expect(veterans.length, run.waveSizes.length);
        expect(veterans.first, ExpeditionVeteran.values[region.index - 1]);
        expect(run.waveSizes.every((size) => size >= 4), isTrue);
        expect(run.enemyPursuitScale, greaterThan(1));
        expect(run.enemyDamage(heavy: true), 2);
      }
    }
    expect(limits, {0, 1, 2});
  });

  test('opening hands vary and boss forge requires two ranked signatures', () {
    final hands = <String>{};
    final options = <ExpeditionSignature>{};
    for (var seed = 0; seed < 256; seed++) {
      final run = Expedition(seed);
      final hand = run.openingSignatures;
      expect(hand.toSet(), hasLength(3));
      expect(Expedition.read(run.toJson()).openingSignatures, hand);
      hands.add(hand.map((card) => card.name).join(','));
      options.addAll(hand);
    }
    expect(hands.length, greaterThan(10));
    expect(options, ExpeditionSignature.values.toSet());
    expect(
      Expedition(12, generator: 8).openingSignatures,
      ExpeditionSignature.legacy,
    );
    final run = Expedition(99)
      ..signatures[ExpeditionSignature.coldSnap] = 2
      ..signatures[ExpeditionSignature.shatterstep] = 1
      ..phase = ExpeditionPhase.reward
      ..draft = [PowerUp.salvage];
    run.room = run.roomCount;
    expect(run.forgeChoices, isEmpty);
    run.signatures[ExpeditionSignature.shatterstep] = 2;
    expect(run.forgeChoices, [ExpeditionFusion.brittleSteel]);
    run.fusions.add(ExpeditionFusion.brittleSteel);
    expect(Expedition.read(run.toJson()).fusions, {
      ExpeditionFusion.brittleSteel,
    });
    expect(run.forgeChoices, isEmpty);
  });

  test('seeded branches resolve distinct repeatable room geometry', () {
    final shapes = <String>{};
    final chambers = <ExpeditionChamber>{};
    for (var seed = 0; seed < 2500; seed++) {
      final run = Expedition(seed)
        ..region =
            ExpeditionRegion.values[seed % ExpeditionRegion.values.length];
      run.room = seed % run.roomCount;
      final room = ExpeditionRoom(run);
      final restored = ExpeditionRoom(Expedition.read(run.toJson()));
      expect(restored.bounds, room.bounds);
      expect(restored.solids, room.solids);
      expect(restored.doors, room.doors);
      shapes.add(room.solids.toString());
      chambers.add(room.chamber!);
      if (run.room + 1 < run.roomCount) {
        final next = Expedition.read(run.toJson())..next = seed % 2;
        next.advanceRoom();
        expect(ExpeditionRoom(next).chamber, isNot(room.chamber));
      }
      final interior = ArenaBounds(room.bounds).interior;
      expect(
        room.solids.every((solid) => interior.intersect(solid) == solid),
        isTrue,
      );
      final clear = interior.deflate(32);
      expect(clear.contains(room.entrance), isTrue);
      for (var i = 0; i < room.doors.length; i++) {
        expect(clear.contains(room.doors[i]), isTrue);
        expect(
          room.solids.any((r) => r.inflate(32).overlaps(room.door(i))),
          isFalse,
        );
      }
      // A conservative flood fill checks player-sized routes around the
      // generated solids with the combat geometry's clearance.
      final cells = <(int, int)>{};
      const step = 24.0;
      Offset at((int, int) cell) => Offset(cell.$1 * step, cell.$2 * step);
      (int, int) cell(Offset p) =>
          ((p.dx / step).round(), (p.dy / step).round());
      final open = [cell(room.entrance)];
      while (open.isNotEmpty) {
        final p = open.removeLast();
        final point = at(p);
        if (!clear.contains(point) ||
            room.solids.any((solid) => solid.inflate(45).contains(point)) ||
            !cells.add(p)) {
          continue;
        }
        open.addAll([
          (p.$1 + 1, p.$2),
          (p.$1 - 1, p.$2),
          (p.$1, p.$2 + 1),
          (p.$1, p.$2 - 1),
        ]);
      }
      for (final door in room.doors) {
        expect(cells.contains(cell(door)), isTrue);
      }
    }
    expect(shapes.length, greaterThanOrEqualTo(20));
    expect(chambers, ExpeditionChamber.values.toSet());
  });

  testWidgets(
    'full campaign preserves route, Walker checkpoint and terminal progress',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(LocalPreferences.shared.load);
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = _Store();
      final audio = _Quiet();
      final previousRelease = ExpeditionRelease.current;
      ExpeditionRelease.current = const ExpeditionRelease(
        enabled: true,
        startingHealth: 8,
      );
      addTearDown(() => ExpeditionRelease.current = previousRelease);

      Future<RegunGame> mount({Map<String, dynamic>? snapshot}) async {
        late RegunGame game;
        await tester.runAsync(() async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [soloudPlayProvider.overrideWithValue(audio)],
              child: MaterialApp(
                home: BaseView(
                  key: UniqueKey(),
                  expeditionMode: true,
                  runStore: store,
                  resumeSnapshot: snapshot,
                  loadout: snapshot == null
                      ? const Loadout()
                      : Loadout.fromJson(
                          Map<String, dynamic>.from(snapshot['loadout'] as Map),
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
          // Drive the widget while asynchronous image and asset loads complete.
          for (var frame = 0; frame < 240 && !game.isLoaded; frame++) {
            await Future<void>.delayed(const Duration(milliseconds: 16));
            await tester.pump();
          }
          await game.loaded.timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw StateError('Expedition failed to load'),
          );
          await tester.pump();
          await game.ready().timeout(
            const Duration(seconds: 12),
            onTimeout: () =>
                throw StateError('Expedition lifecycle did not drain'),
          );
          game.pauseEngine();
          if (snapshot != null && !game.expedition!.terminal) {
            expect(game.gameState.gameplayState, isNot(GameplayState.paused));
          }
          if (snapshot == null) {
            final gate = game.expeditionRoom!.entrance;
            expect(game.crossingExpedition, isTrue);
            expect(game.playerEntrance.active, isFalse);
            expect(game.inputBlocked, isTrue);
            final start = game.myPlayer.y;
            expect(start, greaterThan(gate.dy));
            game.pauseGame();
            game.update(.15);
            expect(game.myPlayer.y, start);
            game.resumeGame();
            game.update(.15);
            expect(game.myPlayer.y, lessThan(start));
            expect(game.myPlayer.y, greaterThan(gate.dy));
            expect(game.expedition!.spawned, 0);
            game.update(.3);
            expect(game.myPlayer.y, gate.dy);
            expect(game.crossingExpedition, isFalse);
            expect(game.expedition!.room, 0);
            expect(game.gameState.health, 8);
            expect(game.gameState.maxHealth, 8);
            game.pauseEngine();
          } else {
            expect(game.crossingExpedition, isFalse);
          }
          await game.ready().timeout(
            const Duration(seconds: 12),
            onTimeout: () =>
                throw StateError('Expedition lifecycle did not drain'),
          );
        });
        return game;
      }

      var game = await mount();
      final id = game.runId;
      final capture =
          Platform.environment['REGUN_EXPEDITION_FEEL_CAPTURE'] == '1';
      final captured = <ExpeditionChamber>{};
      var verifiedSignatures = false;
      double? captureStarted;
      bool testedCaptureTime = false;
      var capturedWithGuardsAlive = false;
      Future<void> captureRoom(String name) async {
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          game.render(Canvas(recorder));
          final picture = recorder.endRecording();
          final image = await picture.toImage(844, 390);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = Directory('build/expedition-feel')
            ..createSync(recursive: true);
          File('${output.path}/$name.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        });
      }

      var testedDrop = false;
      for (var room = 0; room < game.expedition!.roomCount; room++) {
        expect(game.expedition!.room, room);
        final layout = game.expeditionRoom!;
        expect(game.geometry.solids, isNot(contains(layout.door(0))));
        expect(layout.wallDoor(0).bottom, lessThan(layout.door(0).top));
        if (capture && captured.add(layout.chamber!)) {
          await captureRoom(layout.chamber!.name);
        }
        if (capture && room == 0) {
          await tester.runAsync(() async {
            for (var i = 0; i < 105; i++) {
              game.update(1 / 60);
              if (i % 6 == 0) await game.ready();
            }
          });
          await captureRoom('enemy-arrival');
        }
        if (room == 0) {
          await tester.runAsync(() async {
            for (var frame = 0; frame < 360; frame++) {
              game.gameNotifier.heal(game.gameState.maxHealth);
              game.update(1 / 60);
              if (frame % 6 == 0) await game.ready();
            }
          });
          expect(game.expedition!.spawned, game.expedition!.waveSizes.first);
          expect(game.liveEnemies, isNotEmpty);
          expect(game.expedition!.phase, ExpeditionPhase.combat);
        }
        await tester.runAsync(() async {
          for (
            var i = 0;
            i < 2700 && game.expedition!.phase == ExpeditionPhase.combat;
            i++
          ) {
            // This test holds position under fire to check capture and saves.
            game.gameNotifier.heal(game.gameState.maxHealth);
            game.update(1 / 60);
            if (i % 6 == 0) {
              if (game.expeditionDropOffer && !game.expeditionSaving) {
                final run = game.expedition!;
                expect(run.dropGuards, 3);
                expect(game.supplyDrops.drop!.capture, 8);
                if (captureStarted != null) testedCaptureTime = true;
                expect(RunCheckpoint.valid(store.saved!), isTrue);
                await game.claimExpeditionDrop(run.dropSpecial!);
                expect(run.dropSpecial, isNull);
                testedDrop = true;
              } else if (game.supplyDrops.drop case final drop?
                  when drop.phase == SupplyPhase.active) {
                final snapshot = game.checkpoint();
                final guardPresent =
                    (snapshot['enemies'] as List).any(
                      (actor) => (actor as Map)['dropGuard'] == true,
                    ) ||
                    (snapshot['expeditionPending'] as List).any(
                      (actor) => (actor as List).length == 4,
                    );
                if (guardPresent && drop.capture > 0) {
                  capturedWithGuardsAlive = true;
                }
                if (guardPresent || capturedWithGuardsAlive) {
                  final pod = drop.position;
                  if (drop.capture == 0) captureStarted = drop.life;
                  if (captureStarted != null &&
                      drop.life - captureStarted! < 7.75) {
                    expect(game.expeditionDropOffer, isFalse);
                  }
                  game.myPlayer.position.setValues(pod.dx, pod.dy + 100);
                }
              }
              await game.ready().timeout(
                const Duration(seconds: 12),
                onTimeout: () =>
                    throw StateError('Expedition lifecycle did not drain'),
              );
              if (room == 1 &&
                  !verifiedSignatures &&
                  game.liveEnemies.length >= 2) {
                final run = game.expedition!;
                final target = game.liveEnemies.first as CombatEnemy;
                final health = target.combatHealth.current;
                run.signatures[ExpeditionSignature.breachCharge] = 1;
                run.breachChargeReady = true;
                expect(game.hitEnemy(target, .01), isTrue);
                expect(run.breachChargeReady, isFalse);
                expect(target.combatHealth.current, lessThan(health - 1));
                if (!target.combatHealth.isDead) {
                  game.hitEnemy(target, 100, primary: false);
                }

                // Exercise the real dash and kill hooks, with a known enemy
                // position and no cover between the landing and the target.
                run.signatures[ExpeditionSignature.thunderstep] = 1;
                run.signatures[ExpeditionSignature.flashpoint] = 1;
                final other = game.liveEnemies.firstOrNull as CombatEnemy?;
                if (other != null) {
                  other.position.setFrom(game.myPlayer.position);
                  other.combatHealth.current = 1;
                  game.expeditionDashLanded();
                  expect(run.flashpointCooldown, greaterThan(0));
                  expect(other.combatHealth.isDead, isTrue);
                  verifiedSignatures = true;
                }
              }
              final drop = game.supplyDrops.drop;
              if ((room != 1 || verifiedSignatures) &&
                  (drop?.phase != SupplyPhase.active ||
                      capturedWithGuardsAlive)) {
                for (final enemy in game.liveEnemies.toList()) {
                  game.hitEnemy(enemy, 100, primary: false);
                }
              }
            }
          }
          await game.ready().timeout(
            const Duration(seconds: 12),
            onTimeout: () =>
                throw StateError('Expedition lifecycle did not drain'),
          );
          await Future<void>.delayed(Duration.zero);
        });
        expect(
          game.expedition!.phase,
          ExpeditionPhase.reward,
          reason:
              'room $room, drop ${game.supplyDrops.drop?.phase}, '
              'guards ${game.expedition!.dropGuards}, '
              'capture ${game.supplyDrops.drop?.capture}, verified $verifiedSignatures, '
              'captured with guards $capturedWithGuardsAlive',
        );
        expect(game.expedition!.spawned, game.expedition!.pack.length);
        expect(game.liveEnemies, isEmpty);
        expect(game.gameState.xP, 0);
        expect(RunCheckpoint.valid(store.saved!), isTrue);
        final signatureDraft = game.expedition!.signatureDraft;
        if (room == 0) {
          expect(signatureDraft, game.expedition!.openingSignatures);
          await tester.pump();
          expect(find.text('LOADOUT'), findsNothing);
          game = await mount(snapshot: store.saved);
          expect(game.expedition!.signatureDraft, signatureDraft);
          store.rejectNext = true;
        }
        final boon = game.expedition!.draft.firstOrNull;
        await tester.runAsync(() async {
          if (boon == null) {
            game.chooseExpeditionSignature(signatureDraft.first);
          } else {
            game.chooseExpeditionBoon(boon);
          }
          await Future<void>.delayed(Duration.zero);
          if (room == 0) {
            expect(game.expeditionCommitFailed, isTrue);
            game.chooseExpeditionSignature(signatureDraft.first);
            expect(game.expedition!.signatures[signatureDraft.first], 1);
            expect(await game.commitExpedition(), isTrue);
            expect(RunCheckpoint.valid(store.saved!), isTrue);
          }
        });
        if (room == 0) {
          game.setDesktopInputActive(false);
          game.weaponJoystick.delta.setValues(70, 0);
          expect(game.spawnShotgunBullets(), isTrue);
          game.weaponJoystick.delta.setZero();
        }
        final hp = game.gameState.health;
        final rank = boon == null ? 0 : game.gameState.rank(boon);
        final ammo = game.gameState.noOfBullets;
        final door = game.expeditionRoom!.doors.last;
        if (room == 0) {
          // On the phone the exit starts offscreen. Moving north in the
          // cleared room must pan the camera before crossing the threshold.
          final south = game.expeditionRoom!.entrance;
          game.myPlayer.position.setValues(south.dx, south.dy);
          game.update(1 / 60);
          final southCamera = game.camera.viewfinder.position.y;
          expect(game.camera.visibleWorldRect.contains(door), isFalse);
          game.myPlayer.position.setValues(door.dx, door.dy + 120);
          game.update(1 / 60);
          expect(game.camera.viewfinder.position.y, lessThan(southCamera));
          expect(game.camera.visibleWorldRect.contains(door), isTrue);
          expect(game.expedition!.room, room);
        }
        game.myPlayer.position.setValues(door.dx, door.dy + 120);
        game.myPlayer.lastMovement.setValues(0, -1);
        if (capture && room == 0) {
          await captureRoom('gate-locked');
          game.update(.2);
          await captureRoom('gate-sliding');
        }
        game.update(.5);
        if (capture && room == 0) await captureRoom('gate-open');
        game.boostButtonComponent.requestDash();
        await tester.runAsync(() async {
          for (var i = 0; i < 120 && game.expedition!.room == room; i++) {
            game.update(1 / 60);
            await Future<void>.delayed(Duration.zero);
          }
          game.update(2);
          await game.ready().timeout(
            const Duration(seconds: 12),
            onTimeout: () =>
                throw StateError('Expedition lifecycle did not drain'),
          );
        });
        expect(game.expedition!.room, room + 1);
        expect(game.runId, id);
        expect(game.gameState.health, hp);
        if (boon != null) expect(game.gameState.rank(boon), rank);
        expect(game.gameState.noOfBullets, ammo);
        if (room == 0) {
          final committed = store.committedDoor!;
          expect(RunCheckpoint.valid(committed), isTrue);
          game = await mount(snapshot: committed);
          expect(game.runId, id);
          expect(game.expedition!.room, 1);
          if (boon != null) expect(game.gameState.rank(boon), rank);
          expect(game.gameState.noOfBullets, ammo);
        }
      }
      expect(verifiedSignatures, isTrue);
      expect(testedDrop, isTrue);
      expect(testedCaptureTime, isTrue);
      expect(capturedWithGuardsAlive, isTrue);
      expect(audio.chargeCues, {
        for (var i = 0; i < 8; i++) 'supply_charge_$i.wav',
      });
      await tester.runAsync(() async {
        for (var i = 0; i < 360; i++) {
          final before = game.activeBoss;
          game.update(1 / 60);
          if (game.activeBoss case final WalkerBoss actor when before == null) {
            expect(Offset(actor.x, actor.y), game.map.bounds.interior.center);
          }
          if (i % 10 == 0) {
            await game.ready().timeout(const Duration(seconds: 12));
          }
        }
      });
      var walker = game.activeBoss as WalkerBoss;
      expect(game.expedition!.boss, BossKind.walker);
      expect(walker.combatHealth.maximum, closeTo(250.8, .01));
      expect(
        ExpeditionRegion.values.map(
          (region) => (Expedition(7)..region = region).boss,
        ),
        [BossKind.walker, BossKind.demon, BossKind.ariet, BossKind.lodestar],
      );
      expect(walker.prepared, isTrue);
      expect(walker.fight.vulnerable, isTrue);
      await tester.runAsync(() async {
        // Commit a rush into the south-east corner, as when a player dodges
        // out of the locked line. Warning and landing must share clearance.
        final interior = game.map.bounds.interior;
        final safe = interior.deflate(WalkerBoss.stanceRadius);
        final start = safe.bottomRight - const Offset(190, 190);
        walker.rig.carryTo(start);
        walker.position.setValues(start.dx, start.dy);
        final fight = walker.fight
          ..phase = WalkerPhase.charge
          ..clock = 0
          ..chargeDistance = 0
          ..chargeReach = 900
          ..chargeDirection = const Offset(.7071067811865476, .7071067811865476)
          ..player = start - const Offset(500, 500);
        expect((fight.rushLanding - safe.bottomRight).distance, lessThan(.1));
        for (var i = 0; i < 180 && fight.phase != WalkerPhase.recovery; i++) {
          fight.advance(1 / 120);
        }
        expect(fight.phase, WalkerPhase.recovery);
        final landed = walker.rig.position;
        expect((landed - safe.bottomRight).distance, lessThan(3));
        expect(
          walker.rig.legs.every((leg) => interior.contains(leg.foot)),
          isTrue,
        );
        // Run through the component so the route sees the live player and root.
        game.myPlayer.position.setValues(fight.player.dx, fight.player.dy);
        for (var i = 0; i < 90; i++) {
          walker.update(1 / 120);
        }
        expect((walker.rig.position - landed).distance, greaterThan(30));
        expect(game.hitEnemy(walker, 110, primary: false), isTrue);
        if (game.expedition!.bossReinforcements > 0) {
          for (
            var i = 0;
            i < 420 && game.liveEnemies.whereType<ExpeditionWalker>().isEmpty;
            i++
          ) {
            game.gameNotifier.heal(game.gameState.maxHealth);
            game.update(1 / 60);
            if (i % 5 == 0) await game.ready();
          }
          expect(game.expedition!.bossAdds, greaterThan(0));
        } else {
          final escort = ExpeditionWalker(
            position: walker.position.clone()..x += 460,
          );
          game.world.add(escort);
          await game.ready();
        }
        final escort = game.liveEnemies.whereType<ExpeditionWalker>().first;
        expect(game.expeditionMiniWalkerSiteClear(walker.position), isFalse);
        if (game.expedition!.bossReinforcements > 0) {
          expect(game.expeditionMiniWalkerSiteClear(escort.position), isTrue);
        }
        expect(escort.combatHealth.maximum, greaterThanOrEqualTo(35));
        final id = escort.combatId.toString();
        final health = escort.combatHealth.current;
        expect(
          walker.fight.minions!().map((minion) => minion.id),
          isNot(contains(id)),
        );
        walker.fight.crushMinion!(id);
        expect(escort.combatHealth.current, health);
        expect(await game.saveCheckpoint(), isTrue);
      });
      expect(
        RunCheckpoint.valid(store.saved!),
        isTrue,
        reason: 'Walker checkpoint must be valid',
      );
      final bossHealth = walker.combatHealth.current;
      final walkerSnapshot = store.saved!;
      expect(
        (walkerSnapshot['enemies'] as List).map((e) => e['kind']),
        containsAll(['walker', 'miniWalker']),
      );
      game = await mount(snapshot: walkerSnapshot);
      expect(
        game.activeBoss,
        isA<WalkerBoss>(),
        reason:
            '${game.saveIssue}; seed=${game.expedition?.seed}; room=${game.expedition?.room}',
      );
      walker = game.activeBoss as WalkerBoss;
      expect(walker.combatHealth.current, bossHealth);
      expect(game.liveEnemies.whereType<ExpeditionWalker>(), isNotEmpty);
      game.pauseGame();
      await tester.pump();
      expect(find.byKey(const Key('pause-menu-home')), findsOneWidget);
      expect(find.text('LOADOUT'), findsNothing);
      game.resumeGame();
      await tester.runAsync(() async {
        game.expedition!.signatures[ExpeditionSignature.thunderstep] = 2;
        game.expedition!.signatures[ExpeditionSignature.breachCharge] = 2;
        expect(game.hitEnemy(walker, 10000, primary: false), isTrue);
        for (var i = 0; i < 420 && !game.expedition!.terminal; i++) {
          game.gameNotifier.heal(game.gameState.maxHealth);
          game.update(1 / 60);
          if (i % 10 == 0) {
            await game.ready().timeout(const Duration(seconds: 12));
            for (final enemy
                in game.liveEnemies.where((e) => e != walker).toList()) {
              game.hitEnemy(enemy, 100, primary: false);
            }
          }
        }
        await Future<void>.delayed(Duration.zero);
      });
      expect(game.expedition!.phase, ExpeditionPhase.reward);
      expect(RunCheckpoint.valid(store.saved!), isTrue);
      game = await mount(snapshot: store.saved);
      expect(game.expedition!.phase, ExpeditionPhase.reward);
      await tester.pump();
      expect(find.text('WALKER DEFEATED'), findsOneWidget);
      expect(find.text('Arc Primer'), findsOneWidget);
      await tester.runAsync(() async {
        game.forgeExpeditionFusion(ExpeditionFusion.arcPrimer);
        expect(game.expedition!.fusions, contains(ExpeditionFusion.arcPrimer));
        await Future<void>.delayed(Duration.zero);
        final gate = game.expeditionRoom!.doors.single;
        game.myPlayer.position.setValues(gate.dx, gate.dy);
        game.update(.5);
        await Future<void>.delayed(Duration.zero);
        expect(game.crossingExpedition, isTrue);
        game.update(.15);
        expect(game.myPlayer.position.y, lessThan(gate.dy));
        expect(game.expedition!.region, ExpeditionRegion.breach);
        game.update(.22);
        expect(game.expedition!.region, ExpeditionRegion.foundry);
        expect(
          game.myPlayer.position.y,
          greaterThan(game.expeditionRoom!.entrance.dy),
        );
        await game.ready().timeout(const Duration(seconds: 12));
        game.update(.5);
        expect(game.crossingExpedition, isFalse);
        game.expedition!.breachChargeReady = false;
        game.expeditionDashLanded();
        expect(game.expedition!.breachChargeReady, isTrue);
      });
      expect(game.expedition!.room, 0);
      expect(game.expedition!.phase, ExpeditionPhase.combat);
      expect(game.runId, id);
      expect(game.gameState.ranks, isNotEmpty);
      // Exercise every regional boss and the final settlement in the real game.
      // Direct damage keeps the integration test independent of player skill.
      await tester.runAsync(() async {
        Future<void> advanceUntil(bool Function() reached, int frames) async {
          for (var i = 0; i < frames && !reached(); i++) {
            game.update(1 / 60);
            if (i % 8 == 0) {
              await game.ready().timeout(const Duration(seconds: 12));
              await Future<void>.delayed(Duration.zero);
            }
          }
          expect(
            reached(),
            isTrue,
            reason:
                '${game.expedition!.region}/${game.expedition!.room}/${game.expedition!.phase} '
                'spawned ${game.expedition!.spawned}/${game.expedition!.pack.length}, '
                'clock ${game.expedition!.clock}, ${game.enemyPopulation}',
          );
        }

        for (final region in ExpeditionRegion.values.skip(1)) {
          expect(game.expedition!.region, region);
          final expected = ExpeditionVeteran.values[region.index - 1];
          PositionComponent? inherited;
          await advanceUntil(() {
            for (final enemy in game.liveEnemies.toList()) {
              if (enemy is ExpeditionWalker &&
                      expected == ExpeditionVeteran.miniWalker ||
                  enemy is ExpeditionVeteranEnemy && enemy.kind == expected) {
                inherited = enemy;
              } else {
                game.hitEnemy(enemy, 100, primary: false);
              }
            }
            return inherited != null;
          }, 1800);
          final veteran = inherited!;
          expect(
            (veteran as CombatEnemy).combatHealth.maximum,
            greaterThan(30),
          );
          final floor = game.map.bounds.interior;
          final start = floor.center - const Offset(120, 0);
          // Clear sight for the attack exercise. Normal spawning above still
          // uses the authored room and its actual cover.
          final geometry = game.geometry;
          game.geometry = ArenaGeometry(game.map.bounds, obstacles: []);
          veteran.position.setValues(start.dx, start.dy);
          game.crowdOccupancy.rebuild(game.liveEnemies, game.crowdRadius);
          game.myPlayer.position.setValues(start.dx + 570, start.dy);
          await advanceUntil(() => veteran.position.x > start.dx + 12, 90);
          game.myPlayer.position.setValues(veteran.x + 165, veteran.y);
          final cause = switch (expected) {
            ExpeditionVeteran.miniWalker => 'Mini Walker shot',
            ExpeditionVeteran.miniDemon => 'Mini Demon slam',
            ExpeditionVeteran.miniAriet => 'Ariet scout volley',
          };
          if (expected == ExpeditionVeteran.miniDemon) {
            await advanceUntil(
              () => game.world.children.whereType<HostileArea>().any(
                (area) => area.cause == cause && area.age < area.warning,
              ),
              150,
            );
          } else {
            await advanceUntil(
              () =>
                  game.world.children
                      .whereType<Enemy3Projectile>()
                      .where((shot) => shot.cause == cause)
                      .length ==
                  3,
              150,
            );
          }
          expect(game.hitEnemy(veteran, 100, primary: false), isTrue);
          game.geometry = geometry;
          while (!game.expedition!.bossRoom) {
            await advanceUntil(() {
              for (final enemy in game.liveEnemies.toList()) {
                game.hitEnemy(enemy, 100, primary: false);
              }
              if (game.expeditionDropCanSkip) game.skipExpeditionDrop();
              return game.expedition!.phase == ExpeditionPhase.reward &&
                  !game.expeditionSaving;
            }, 3000);
            if (game.expedition!.supplyRoom) {
              expect(game.expedition!.dropStarted, isTrue);
              expect(game.expedition!.dropGuards, 3);
            }
            game.chooseExpeditionBoon(game.expedition!.draft.first);
            await Future<void>.delayed(Duration.zero);
            final gate = game.expeditionRoom!.doors.first;
            game.myPlayer.position.setValues(gate.dx, gate.dy);
            final room = game.expedition!.room;
            await advanceUntil(
              () => game.expedition!.room != room && !game.crossingExpedition,
              140,
            );
          }
          await advanceUntil(
            () => game.activeBoss?.isMounted == true && !game.inputBlocked,
            600,
          );
          final boss = game.activeBoss!;
          expect(
            (boss as CombatEnemy).combatHealth.maximum,
            greaterThanOrEqualTo(game.expedition!.bossHealth - 1),
          );
          if (boss is LodestarBoss) {
            for (final module in [
              LodestarSection.accelerator,
              LodestarSection.mortars,
            ]) {
              boss.receiveLocalDamage(
                10000,
                point: boss.fight.rig.poses[module.index].position,
              );
            }
            boss.receiveLocalDamage(
              10000,
              point: boss.fight.rig.poses.first.position,
            );
          } else {
            expect(game.hitEnemy(boss, 10000, primary: false), isTrue);
          }
          final outcome = region == ExpeditionRegion.relay
              ? ExpeditionPhase.victory
              : ExpeditionPhase.reward;
          await advanceUntil(
            () => game.expedition!.phase == outcome && !game.expeditionSaving,
            1000,
          );
          if (region != ExpeditionRegion.relay) {
            game.chooseExpeditionBoon(game.expedition!.draft.first);
            await Future<void>.delayed(Duration.zero);
            final gate = game.expeditionRoom!.doors.single;
            game.myPlayer.position.setValues(gate.dx, gate.dy);
            await advanceUntil(
              () =>
                  game.expedition!.region != region && !game.crossingExpedition,
              140,
            );
          }
        }
      });
      expect(game.runId, id);
      expect(RunCheckpoint.valid(store.saved!), isTrue);
      await tester.pump();
      expect(find.text('EXPEDITION COMPLETE'), findsOneWidget);
      final progress = await tester.runAsync(
        () => ExpeditionProgress.shared.read('guest'),
      );
      expect(progress?['clears'], 1);
      expect(progress?['highestThreat'], 0);
      await tester.runAsync(() async {
        await tester.tap(find.text('RETURN TO OUTPOST'));
        for (
          var i = 0;
          i < 25 &&
              !tester
                  .widgetList<BaseView>(find.byType(BaseView))
                  .any((view) => view.expeditionStaging);
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 16));
          await tester.pump(const Duration(milliseconds: 40));
        }
      });
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(
        tester.widget<BaseView>(find.byType(BaseView)).expeditionStaging,
        isTrue,
      );
      expect(store.saved, isNull);
      final staging =
          tester
                  .widget<RiverpodAwareGameWidget>(
                    find.byType(RiverpodAwareGameWidget),
                  )
                  .game!
              as RegunGame;
      await tester.runAsync(() async {
        for (var frame = 0; frame < 240 && !staging.stagingReady; frame++) {
          await Future<void>.delayed(const Duration(milliseconds: 16));
          await tester.pump();
        }
        await staging.ready();
        staging.pauseEngine();
        final dummy = staging.liveEnemies
            .whereType<ExpeditionRangeTarget>()
            .single;
        for (var i = 0; i < 5; i++) {
          expect(staging.hitEnemy(dummy, 200), isTrue);
          expect(dummy.streakDamage, 200 * (i + 1));
          expect(dummy.combatHealth.isDead, isFalse);
          dummy.update(.3);
        }
        staging.world.add(
          BulletComponent(
            position: dummy.position.clone()..y += 105,
            direction: dummy.position.clone()..setValues(0, -1),
            damage: 13,
            primary: false,
          ),
        );
        await staging.ready();
        staging.update(.15);
        expect(dummy.streakDamage, 1013);
        dummy.update(1.5);
        expect(dummy.streakDamage, 1013);
        dummy.update(.5);
        expect(dummy.streakDamage, 0);
        expect(staging.hitEnemy(dummy, 7), isTrue);
        expect(dummy.streakDamage, 7);
        expect(staging.gameState.kills, 0);
        expect(await staging.saveCheckpoint(), isFalse);
        const at = ExpeditionStaging.armory;
        staging.myPlayer.position.setValues(at.dx, at.dy);
        staging.update(1 / 60);
      });
      await tester.pump();
      expect(find.text('OPEN LOADOUT'), findsOneWidget);
      final controller = DesktopController.handlers.last;
      final buttons = List<double>.filled(20, 0);
      expect(controller(ControllerFrame(buttons)), isTrue);
      buttons[4] = 1;
      expect(controller(ControllerFrame(buttons)), isTrue);
      buttons[4] = 0;
      controller(ControllerFrame(buttons));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(LoadoutView), findsOneWidget);
      expect(find.text('EQUIP'), findsOneWidget);
      await tester.tap(find.text('EQUIP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(LoadoutView), findsNothing);
      const gate = ExpeditionStaging.gate;
      staging.myPlayer.position.setValues(gate.dx, gate.dy);
      staging.update(1 / 60);
      await tester.pump();
      expect(find.text('DEPLOY'), findsOneWidget);
      // The gate only deploys a new run even while a checkpoint exists.
      store.saved = walkerSnapshot;
      if (capture) {
        game = staging;
        await captureRoom('staging-deployment');
      }
      expect(controller(ControllerFrame(buttons)), isTrue);
      buttons[4] = 1;
      expect(controller(ControllerFrame(buttons)), isTrue);
      buttons[4] = 0;
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 60 && find.text('THREAT 2').evaluate().isEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 16));
          await tester.pump(const Duration(milliseconds: 40));
        }
      });
      expect(find.text('THREAT 2'), findsOneWidget);
      expect(find.text('CONTINUE'), findsNothing);
      expect(find.text('NEW RUN'), findsNothing);
      await tester.tap(find.text('THREAT 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final next = tester.widget<BaseView>(find.byType(BaseView));
      expect(next.expeditionMode, isTrue);
      expect(next.expeditionThreat, 1);
      // A fresh deployment after victory can end in defeat and return to the
      // same Outpost without retaining a resumable combat checkpoint.
      late RegunGame losingRun;
      await tester.runAsync(() async {
        for (var i = 0; i < 200; i++) {
          final widget = find.byType(RiverpodAwareGameWidget);
          if (widget.evaluate().length == 1) {
            final candidate =
                tester.widget<RiverpodAwareGameWidget>(widget).game!
                    as RegunGame;
            if (candidate.expeditionMode && candidate.isLoaded) {
              losingRun = candidate;
              break;
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 16));
          await tester.pump(const Duration(milliseconds: 20));
        }
        await losingRun.ready();
        losingRun.update(.8);
        expect(losingRun.crossingExpedition, isFalse);
        losingRun.gameNotifier.gameOver();
        for (
          var i = 0;
          i < 60 && find.text('RETURN TO OUTPOST').evaluate().isEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 16));
          await tester.pump(const Duration(milliseconds: 20));
        }
      });
      expect(find.text('EXPEDITION LOST'), findsOneWidget);
      expect(losingRun.expedition!.phase, ExpeditionPhase.defeat);
      await tester.runAsync(() async {
        await tester.tap(find.text('RETURN TO OUTPOST'));
        await Future<void>.delayed(Duration.zero);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      });
      expect(
        tester.widget<BaseView>(find.byType(BaseView)).expeditionStaging,
        isTrue,
      );
      expect(store.saved, isNull);
      final afterLoss = await tester.runAsync(
        () => ExpeditionProgress.shared.read('guest'),
      );
      expect(afterLoss?['clears'], 1);
      expect(afterLoss?['highestThreat'], 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
