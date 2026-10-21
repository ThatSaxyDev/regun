import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/boss_encounter.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/components/enemies/enemy_3_component.dart';
import 'package:regun/components/enemies/enemy_3_projectile.dart';
import 'package:regun/components/enemies/shadow_projectile.dart';
import 'package:regun/components/enemies/hostile_area.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

class _Audio extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  void pauseMusic(bool paused) {}
}

// Widget tests use a serialized in-memory transport; actual atomic files and
// backup recovery are exercised independently in run_store_test.dart.
class _MemoryStore extends RunStore {
  Map<String, dynamic>? value;
  @override
  Future<bool> write(Map<String, dynamic> snapshot) {
    value = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    return Future.value(true);
  }

  @override
  Future<Map<String, dynamic>?> read(
          {bool Function(Map<String, dynamic>)? validate}) async =>
      value != null && (validate == null || validate(value!)) ? value : null;
  @override
  Future<void> clear({String? expectedRunId}) {
    if (expectedRunId == null || value?['id'] == expectedRunId) value = null;
    return Future.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'all weapons/characters mount, bosses work, and a live run restores safely',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _MemoryStore();
    const capture = Key('full-run-capture');
    await tester.runAsync(() async {
      for (final pair in [
        ('PressStart2P', 'PressStart2P-Regular.ttf'),
        ('Orbitron', 'Orbitron-Bold.ttf')
      ]) {
        final font = FontLoader(pair.$1)
          ..addFont(rootBundle.load('assets/fonts/${pair.$2}'));
        await font.load();
      }
    });
    Future<RegunGame> mount(Loadout loadout,
        {Map<String, dynamic>? resume}) async {
      late RegunGame game;
      await tester.runAsync(() async {
        await tester.pumpWidget(ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
            child: MaterialApp(
                theme: ThemeData.dark(),
                home: RepaintBoundary(
                    key: capture,
                    child: BaseView(
                        key: UniqueKey(),
                        loadout: loadout,
                        runStore: store,
                        resumeSnapshot: resume)))));
        game = tester
            .widget<RiverpodAwareGameWidget>(
                find.byType(RiverpodAwareGameWidget))
            .game! as RegunGame;
        await game.loaded.timeout(const Duration(seconds: 15));
        await tester.pump();
        await game.ready().timeout(const Duration(seconds: 15));
        game.update(2); // Finish deployment before exercising combat.
      });
      await tester.pump();
      return game;
    }

    Future<void> screenshot(String name) async {
      await tester.pump();
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final character in CharacterType.values) {
      for (final weapon in WeaponType.values) {
        final game = await mount(Loadout(character: character, weapon: weapon));
        expect(game.gameState.health, character.health);
        expect(game.gameState.noOfBullets, weapon.capacity);
        game.weaponJoystick.delta.setValues(70, 0);
        game.spawnShotgunBullets();
        await tester.runAsync(() => game.ready());
        final bullets =
            game.world.children.whereType<BulletComponent>().toList();
        expect(bullets.length, weapon == WeaponType.shotgun ? 3 : 1);
        expect(bullets.first.damage,
            closeTo(weapon.damage * character.damage, 0.001));
        game.gameNotifier.reloadBullets();
        game.gameNotifier.advanceTime(0.45);
        if (weapon == WeaponType.shotgun) {
          await screenshot('survivor-${character.name}');
        }
        if (character == CharacterType.rook) {
          await screenshot('weapon-${weapon.name}');
        }
        expect(tester.takeException(), isNull);
      }
    }

    // Exercise healing through actual lethal hits, including rolls that the
    // former 2.5%-per-rank chance rejected. Seeds yield ~2.8%, 5.5%, 11%, 51%.
    final medic = await mount(const Loadout());
    for (final scenario in [
      (0, 2, false),
      (1, 2, true),
      (1, 4, false),
      (2, 4, true),
      (2, 8, false),
      (3, 8, true),
      (3, 1, false),
    ]) {
      final checkpoint = medic.gameNotifier.checkpoint();
      checkpoint['state'] = medic.gameState.copyWith(health: 2, ranks: {
        if (scenario.$1 > 0) PowerUp.fieldMedic: scenario.$1
      }).toJson();
      medic.gameNotifier.restoreCheckpoint(checkpoint);
      medic.gameNotifier.playGame();
      final target = EnemyComponent(position: Vector2(300, 0));
      await tester.runAsync(() async {
        await medic.world.add(target);
        await medic.ready();
      });
      medic.random.state = scenario.$2;
      target.lastHitWasSecondary = true;
      final killsBefore = medic.gameState.kills;
      expect(target.takeDamage(100), isTrue);
      expect(medic.gameState.health, scenario.$3 ? 3 : 2,
          reason: 'Field Medic rank ${scenario.$1}, seed ${scenario.$2}');
      expect(medic.gameState.kills, killsBefore + 1);
      expect(target.takeDamage(100), isFalse);
      expect(medic.gameState.health, scenario.$3 ? 3 : 2,
          reason: 'A repeated hit cannot award another heart');
      await tester.runAsync(() => medic.ready());
    }
    medic.gameNotifier.resetHealth();
    final fullHealthTarget = EnemyComponent(position: Vector2(300, 0));
    await tester.runAsync(() async {
      await medic.world.add(fullHealthTarget);
      await medic.ready();
    });
    medic.random.state = 2;
    fullHealthTarget.takeDamage(100);
    expect(medic.gameState.health, medic.gameState.maxHealth,
        reason: 'A successful heal cannot exceed maximum health');

    for (final attack in ['contact', 'revenant', 'shadow', 'ground']) {
      final shield = await mount(const Loadout());
      final checkpoint = shield.gameNotifier.checkpoint();
      checkpoint['state'] = shield.gameState
          .copyWith(guard: true, ranks: {PowerUp.scrapArmour: 1}).toJson();
      shield.gameNotifier.restoreCheckpoint(checkpoint);
      shield.gameNotifier.playGame();
      shield.gameNotifier.advanceTime(1); // Expire resume protection.
      final health = shield.gameState.health;
      // Intersect the player's hitbox edge instead of spawning a tiny hollow
      // projectile wholly inside it (which does not model an incoming shot).
      final position = shield.myPlayer.position + Vector2(25, 0);
      final source = switch (attack) {
        'contact' => EnemyComponent(position: position),
        'revenant' => Enemy3Projectile(position: position, speed: 0),
        'shadow' => ShadowProjectile(
            position: position, direction: Vector2(1, 0), speed: 0),
        _ => HostileArea(position: position, warning: 0, damage: 2),
      };
      await tester.runAsync(() async {
        await shield.world.add(source);
        await shield.ready();
        for (var i = 0; i < 3; i++) {
          shield.update(1 / 60);
          await shield.ready();
        }
      });
      expect(shield.gameState.guard, isFalse,
          reason: '$attack must connect and consume the shield');
      expect(shield.gameState.health, health,
          reason: '$attack must not bypass the shield');
      expect(shield.damageFeedback.remaining, 0,
          reason: 'A blocked hit must not show health-loss feedback');
    }

    final showcase = await mount(const Loadout(training: true));
    await tester.runAsync(() async {
      await showcase.world.addAll([
        EnemyComponent(position: Vector2(210, -55)),
        EnemyComponent(position: Vector2(-120, 170)),
        Enemy2Component(position: Vector2(-240, -40)),
        Enemy3Component(position: Vector2(330, -175)),
        ArenaEnemy(EnemyKind.shield, position: Vector2(390, 90)),
        ArenaEnemy(EnemyKind.runner, position: Vector2(-370, 160)),
      ]);
      await showcase.ready();
      showcase.update(.1);
    });
    await screenshot('art-breach-playable');
    expect(tester.takeException(), isNull);

    final game = await mount(const Loadout(arena: ArenaType.foundry));
    for (var i = 0; i < 500; i++) {
      game.gameNotifier.healthIncrease();
    }
    for (final kind in BossKind.values) {
      await tester.runAsync(() async {
        game.spawnBoss(kind);
        await game.ready().timeout(const Duration(seconds: 10));
      });
      final boss = game.activeBoss!;
      expect((boss as BossEncounter).kind, kind);
      final health = boss as CombatEnemy;
      expect(health.takeDamage(health.combatHealth.maximum * 0.55), isTrue);
      expect((boss as BossEncounter).enraged, isTrue);
      await tester.runAsync(() async {
        for (var frame = 0; frame < 25 * 60; frame++) {
          // XP retained from the preceding boss can legitimately open a picker.
          // Resolve it so this scenario continues to exercise the next boss FSM.
          for (var picks = 0;
              game.gameState.gameplayState == GameplayState.powerup;
              picks++) {
            if (picks > 30) {
              throw StateError("Picker stuck ${game.gameState.toJson()}");
            }
            final offer = game.gameState;
            if (offer.evolutionChoices.isNotEmpty) {
              game.gameNotifier
                  .fuse(offer.evolutionChoices.first, offerId: offer.offerId);
            } else {
              game.gameNotifier.applyPowerUp(offer.powerUpChoices.first,
                  offerId: offer.offerId);
            }
          }
          game.update(1 / 60);
          if (frame % 30 == 0) await game.ready();
        }
      });
      expect(game.activeBoss, boss);
      await screenshot('boss-${kind.name}');
      expect(game.gameState.gameplayState, GameplayState.playing,
          reason: 'Boss ${kind.name} must still be testable');
      expect(health.takeDamage(100000), isTrue);
      expect(health.takeDamage(100000), isFalse);
      expect(game.activeBoss, isNull);
      for (var picks = 0;
          game.gameState.gameplayState == GameplayState.powerup;
          picks++) {
        if (picks > 30) {
          throw StateError("Picker stuck ${game.gameState.toJson()}");
        }
        game.gameNotifier.applyPowerUp(game.gameState.powerUpChoices.first,
            offerId: game.gameState.offerId);
      }
      game.update(1 / 60);
      await tester.runAsync(() => game.ready());
    }
    expect(game.gameState.bosses, BossKind.values.length);
    expect(
        game.defeatedBosses, BossKind.values.map((kind) => kind.name).toSet());

    // A damaged live enemy, a boss, earned XP, and a partial reload survive a checkpoint.
    final enemy = Enemy2Component(position: Vector2(350, 0));
    await tester.runAsync(() async {
      await game.world.add(enemy);
      await game.ready();
    });
    enemy.takeDamage(1);
    game.spawnBoss(BossKind.shadow);
    await tester.runAsync(() => game.ready());
    (game.activeBoss as CombatEnemy).takeDamage(10);
    game.myPlayer.position.setValues(100, 100);
    game.gameNotifier.decreaseBullets();
    game.gameNotifier.reloadBullets();
    game.gameNotifier.advanceTime(0.4);
    game.dropXP(Vector2(900, 900), 11);
    game.pauseGame();
    await tester.runAsync(() => game.saveCheckpoint());
    final snapshot =
        await tester.runAsync(() => store.read(validate: RunCheckpoint.valid));
    expect(snapshot, isNotNull);
    final oldHealth = game.gameState.health;
    final oldAmmo = game.gameState.noOfBullets;
    final oldClock = game.gameState.survivalSeconds;
    final restored =
        await mount(const Loadout(arena: ArenaType.foundry), resume: snapshot);
    expect(restored.paused, isTrue);
    expect(restored.gameState.health, oldHealth);
    expect(restored.gameState.noOfBullets, oldAmmo);
    expect(restored.gameState.survivalSeconds, oldClock);
    expect(restored.myPlayer.position, Vector2(100, 100));
    expect(
        restored.liveEnemies
            .whereType<Enemy2Component>()
            .any((e) => e.combatHealth.current == 5),
        isTrue);
    expect(
        (restored.activeBoss as CombatEnemy).combatHealth.current,
        (snapshot!['enemies'] as List)
            .cast<Map>()
            .firstWhere((e) => e['kind'] == 'shadow')['health']);
    expect(restored.gameState.reloading, isTrue);
    restored.resumeGame();
    restored.update(0.5);
    expect(restored.gameState.reloading, isFalse);
    expect(restored.gameState.noOfBullets, restored.gameState.maxBullets);

    // Every additional normal role uses real health and the shared registry.
    for (final kind in [
      EnemyKind.runner,
      EnemyKind.shield,
      EnemyKind.burster,
      EnemyKind.nest,
      EnemyKind.sentinel
    ]) {
      final actor = ArenaEnemy(kind, position: Vector2(1100, 1100));
      await tester.runAsync(() async {
        await restored.world.add(actor);
        await restored.ready();
      });
      expect(restored.liveEnemies, contains(actor));
      expect(actor.combatHealth.current, greaterThan(0));
      // Earlier pickups can legitimately open another pending offer.
      for (var picks = 0;
          restored.gameState.gameplayState == GameplayState.powerup;
          picks++) {
        if (picks > 30) throw StateError('Unresolved offer');
        final offer = restored.gameState;
        if (offer.evolutionChoices.isNotEmpty) {
          restored.gameNotifier
              .fuse(offer.evolutionChoices.first, offerId: offer.offerId);
        } else {
          restored.gameNotifier
              .applyPowerUp(offer.powerUpChoices.first, offerId: offer.offerId);
        }
      }
      actor.lastHitWasSecondary = true;
      expect(actor.takeDamage(10000), isTrue);
    }

    // Exercise each core's actual combat branch with fresh training worlds.
    for (final recipe in fusionRecipes) {
      final practice = await mount(Loadout(
          training: true,
          weapon: recipe.id == 'stormCircuit'
              ? WeaponType.arcCaster
              : WeaponType.shotgun));
      practice.gameNotifier.prepareTrainingFusion(recipe);
      practice.gameNotifier
          .fuse(recipe.id, offerId: practice.gameState.offerId);
      expect(practice.gameState.fused(recipe.id), isTrue);
      final first = Enemy2Component(position: Vector2(200, 0));
      final second = Enemy2Component(position: Vector2(260, 20));
      await tester.runAsync(() async {
        await practice.world.addAll([first, second]);
        await practice.ready();
      });
      switch (recipe.id) {
        case 'firebreak':
          practice.combat.hit(first, 100);
          expect(practice.runtimeCounts['fire'], 1);
        case 'stormCircuit':
          practice.combat.hit(first, 0.1);
          expect(second.combatHealth.current,
              lessThan(second.combatHealth.maximum));
        case 'minefield':
          practice.combat.onDash();
          expect(practice.runtimeCounts['mines'], 3);
        case 'pinball':
          practice.weaponJoystick.delta.setValues(80, 0);
          practice.spawnShotgunBullets();
          await tester.runAsync(() => practice.ready());
          expect(
              practice.world.children
                  .whereType<BulletComponent>()
                  .every((b) => b.bounces == 6),
              isTrue);
        case 'breachEngine':
          for (var i = 0; i < 4; i++) {
            practice.gameNotifier.decreaseBullets();
          }
          practice.weaponJoystick.delta.setValues(80, 0);
          practice.spawnShotgunBullets();
          await tester.runAsync(() => practice.ready());
          expect(
              practice.world.children.whereType<BulletComponent>().first.damage,
              closeTo(4.44, 0.001));
        case 'hunterSwarm':
          practice.combat.update(1.1);
          expect(first.combatHealth.current, lessThan(2));
          expect(practice.runtimeCounts['effects'], 3);
      }
      await tester.runAsync(() => practice.ready());
      expect(tester.takeException(), isNull, reason: recipe.title);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
