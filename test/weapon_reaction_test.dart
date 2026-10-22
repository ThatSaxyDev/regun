import 'package:regun/components/enemies/enemy_component.dart';
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/systems/weapon_reaction.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Audio extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool paused) {}
}

// No pursuit: isolate accepted combat force from voluntary movement.
class _Body extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy {
  _Body(Vector2 at, {this.mass = 1})
    : super(position: at, size: Vector2.all(80), anchor: Anchor.center);
  final double mass;
  @override
  double get impactResponse => mass;
  @override
  Future<void> onLoad() async {
    initializeHealth(10000);
  }

  @override
  void onCombatDeath() {}
}

void main() {
  Future<RegunGame> mount(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
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
      await game.ready();
    });
    return game;
  }

  void advance(_Body body, double seconds) {
    for (var t = 0.0; t < seconds - 1e-8; t += .01) {
      body.update((seconds - t).clamp(0, .01));
    }
  }

  testWidgets(
    'all 21 primary weapons deliver bounded mass-scaled physical reactions',
    (tester) async {
      final game = await mount(tester);
      await tester.runAsync(() async {
        for (final weapon in WeaponType.values) {
          game.pauseGame();
          expect(await game.changeTrainingWeapon(weapon), isTrue);
          game.gameNotifier.playGame();
          final body = _Body(Vector2(300, 0));
          await game.world.add(body);
          await game.ready();
          final profile = WeaponReaction.of(weapon);
          expect(game.hitEnemy(body, .1, direction: Vector2(1, 0)), isTrue);
          expect(body.impactHeld, profile.stagger > 0, reason: weapon.name);
          // Same-shot pellets/beam ticks must not compound the force.
          for (var i = 0; i < 12; i++) {
            body.receiveBulletImpact(Vector2(1, 0), weapon);
          }
          advance(body, .4);
          expect(
            body.position.x - 300,
            closeTo(profile.distance, .001),
            reason: weapon.name,
          );
          expect(body.position.y, closeTo(0, .001));
          expect(body.impactHeld, isFalse);
          expect(body.impactStride, 1);
          body.removeFromParent();
          await game.ready();
        }
        expect(
          WeaponReaction.of(WeaponType.mourningBell).distance,
          greaterThan(WeaponReaction.of(WeaponType.carbine).distance * 10),
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'mass, stagger recovery, frozen shove, pause and death preserve control',
    (tester) async {
      final game = await mount(tester);
      await tester.runAsync(() async {
        for (final mass in [0.0, .35, .65, .7, 1.0]) {
          final body = _Body(Vector2(300, 0), mass: mass);
          await game.world.add(body);
          await game.ready();
          body.receiveWeaponImpact(
            Vector2(1, 0),
            WeaponReaction.of(WeaponType.mourningBell),
          );
          expect(body.impactHeld, mass >= .6);
          advance(body, .3);
          expect(body.position.x - 300, closeTo(112 * mass, .001));
          body.receiveWeaponImpact(
            Vector2(1, 0),
            WeaponReaction.of(WeaponType.mourningBell),
          );
          expect(
            body.impactHeld,
            isFalse,
            reason: 'Recovery prevents renewed hard stagger',
          );
          advance(body, .4);
          body.receiveWeaponImpact(
            Vector2(1, 0),
            WeaponReaction.of(WeaponType.mourningBell),
          );
          expect(body.impactHeld, mass >= .6);
          body.removeFromParent();
          await game.ready();
        }
        final body = _Body(Vector2(300, 0));
        await game.world.add(body);
        await game.ready();
        body.receiveWeaponImpact(
          Vector2(1, 0),
          WeaponReaction.of(WeaponType.frostShotgun),
        );
        expect(body.freeze(), isTrue);
        game.pauseGame();
        advance(body, 1);
        expect(body.position.x, 300);
        expect(body.freezeHeld, isTrue);
        game.gameNotifier.playGame();
        advance(body, .2);
        expect(body.position.x, closeTo(332, .001));
        expect(body.freezeHeld, isTrue);
        body.takeDamage(20000);
        expect(body.freezeHeld, isFalse);
        expect(body.impactHeld, isFalse);
        final at = body.position.clone();
        advance(body, 1);
        expect(body.position, at);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'blasts push radially, cover blocks force, secondary damage needs an explicit reaction',
    (tester) async {
      final game = await mount(tester);
      await tester.runAsync(() async {
        final bodies = [
          _Body(Vector2(300, 0)),
          _Body(Vector2(-300, 0)),
          _Body(Vector2(0, 300)),
        ];
        await game.world.addAll(bodies);
        await game.ready();
        game.geometry = ArenaGeometry(
          game.map.bounds,
          obstacles: [const Rect.fromLTWH(-180, -80, 40, 160)],
        );
        game.explode(Vector2.zero(), damage: 1, radius: 320);
        advance(bodies[0], .3);
        advance(bodies[1], .3);
        advance(bodies[2], .3);
        expect(bodies[0].position.x, closeTo(386, .001));
        expect(bodies[1].position.x, -300);
        expect(bodies[2].position.y, closeTo(386, .001));
        advance(bodies[0], .4);
        game.hitEnemy(bodies[0], .1, primary: false, direction: Vector2(1, 0));
        advance(bodies[0], .3);
        expect(bodies[0].position.x, closeTo(386, .001));
        game.hitEnemy(
          bodies[0],
          .1,
          primary: false,
          direction: Vector2(1, 0),
          reaction: WeaponReaction.bellEcho,
        );
        expect(bodies[0].lastHitWasSecondary, isTrue);
        expect(bodies[0].impactHeld, isFalse);
        advance(bodies[0], .2);
        expect(bodies[0].position.x, closeTo(420, .001));
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'heavy reactions replace weaker impulses and stop at bodies and walls',
    (tester) async {
      final game = await mount(tester);
      await tester.runAsync(() async {
        final body = _Body(Vector2(300, 0)), blocker = _Body(Vector2(420, 0));
        await game.world.addAll([body, blocker]);
        await game.ready();
        game.crowdOccupancy.rebuild(game.liveEnemies, game.crowdRadius);
        body.receiveWeaponImpact(
          Vector2(1, 0),
          WeaponReaction.of(WeaponType.carbine),
        );
        body.receiveWeaponImpact(
          Vector2(1, 0),
          WeaponReaction.of(WeaponType.mourningBell),
        );
        advance(body, .3);
        expect(body.position.x, greaterThan(306));
        expect(
          body.position.distanceTo(blocker.position),
          greaterThanOrEqualTo(71.9),
        );
        blocker.removeFromParent();
        await game.ready();
        body.position.setValues(300, 0);
        game.geometry = ArenaGeometry(
          game.map.bounds,
          obstacles: [const Rect.fromLTWH(380, -100, 40, 200)],
        );
        game.crowdOccupancy.rebuild(game.liveEnemies, game.crowdRadius);
        body.receiveWeaponImpact(
          Vector2(1, 0),
          WeaponReaction.of(WeaponType.mourningBell),
        );
        advance(body, .3);
        expect(body.position.x, lessThanOrEqualTo(344.01));
        expect(body.position.x, greaterThan(320));
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'ordinary enemy sprite resumes after stagger and plays death after frozen hit',
    (tester) async {
      final game = await mount(tester);
      await tester.runAsync(() async {
        final enemy = EnemyComponent(position: Vector2(300, 0));
        enemy.restoreHealth(1000, maximum: 1000);
        await game.world.add(enemy);
        await game.ready();
        enemy.receiveWeaponImpact(
          Vector2(1, 0),
          WeaponReaction.of(WeaponType.mourningBell),
        );
        enemy.update(.01);
        expect(enemy.playing, isFalse);
        enemy.update(.21);
        expect(enemy.impactHeld, isFalse);
        expect(enemy.playing, isTrue);
        enemy.freeze();
        enemy.update(.01);
        expect(enemy.playing, isFalse);
        enemy.update(.81);
        expect(enemy.freezeHeld, isFalse);
        expect(enemy.playing, isTrue);
        enemy.freezeState.remaining = 0;
        enemy.freezeState.recovery = 0;
        enemy.freezeState.immunity = 0;
        expect(enemy.freeze(), isTrue);
        enemy.update(.01);
        enemy.takeDamage(2000);
        expect(enemy.playing, isTrue);
        expect(enemy.isDying, isTrue);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
