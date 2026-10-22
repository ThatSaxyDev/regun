import 'package:regun/components/weapons/combat_effect.dart';
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/boss_weak_point.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/systems/weapon_reaction.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

class _Audio extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  void pauseMusic(bool value) {}
}

class _Body extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy {
  _Body(Vector2 at, {this.boss = false})
    : super(position: at, size: Vector2.all(60), anchor: Anchor.center);
  final bool boss;
  @override
  bool get isBoss => boss;
  @override
  Future<void> onLoad() async {
    initializeHealth(1000);
  }

  @override
  void onCombatDeath() {}
}

void main() {
  Future<RegunGame> mount(
    WidgetTester tester,
    CharacterType c, {
    WeaponType weapon = WeaponType.carbine,
  }) async {
    SharedPreferences.setMockInitialValues({});
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Audio())],
          child: MaterialApp(
            home: BaseView(
              key: ValueKey(c),
              loadout: Loadout(character: c, weapon: weapon, training: true),
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

  Future<_Body> body(RegunGame g, double x, {bool boss = false}) async {
    final b = _Body(Vector2(x, 0), boss: boss);
    await g.world.add(b);
    await g.ready();
    return b;
  }

  void ranks(
    RegunGame g,
    Map<PowerUp, int> ranks, {
    Set<String> fusions = const {},
  }) {
    final snapshot = g.gameNotifier.checkpoint();
    snapshot['state'] = g.gameState
        .copyWith(ranks: ranks, evolutions: fusions)
        .toJson();
    g.gameNotifier.restoreCheckpoint(snapshot);
    g.gameNotifier.playGame();
  }

  testWidgets(
    'Kiln Pact and Firebreak create one shared patch per burning priority death',
    (tester) async {
      final g = await mount(tester, CharacterType.moth);
      await tester.runAsync(() async {
        final priority = await body(g, 300, boss: true);
        ranks(
          g,
          {PowerUp.hotShot: 3, PowerUp.scouringHeat: 2, PowerUp.accelerant: 2},
          fusions: {'kilnPact', 'firebreak'},
        );
        priority.ignite(.85);
        g.combat.onKill(priority);
        await g.ready();
        expect(g.world.children.whereType<BurningGround>().length, 1);
        final ground = g.world.children.whereType<BurningGround>().single;
        final age = ground.age;
        g.pauseGame();
        ground.update(10);
        expect(ground.age, age);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Ground Wire adds one hop only on fourth successful discharge and freezes gate',
    (tester) async {
      final g = await mount(
        tester,
        CharacterType.rook,
        weapon: WeaponType.arcCaster,
      );
      await tester.runAsync(() async {
        final a = await body(g, 100);
        await body(g, 230);
        await body(g, 360);
        final last = await body(g, 490);
        ranks(
          g,
          {PowerUp.staticCharge: 3, PowerUp.faradayReserve: 2},
          fusions: {'groundWire'},
        );
        for (var i = 0; i < 3; i++) {
          g.combat.update(.01);
          g.hitEnemy(a, 2);
        }
        expect(last.combatHealth.current, 1000);
        g.combat.update(.01);
        g.hitEnemy(a, 2);
        expect(last.combatHealth.current, lessThan(1000));
        expect(g.gameNotifier.survivor.wire, 0);
        expect(g.gameNotifier.survivor.wireGate, 1);
        g.pauseGame();
        g.update(10);
        expect(g.gameNotifier.survivor.wireGate, 1);
        g.resumeGame();
        final hp = last.combatHealth.current;
        for (var i = 0; i < 4; i++) {
          g.combat.update(.01);
          g.hitEnemy(a, 2);
        }
        expect(
          last.combatHealth.current,
          hp,
          reason: 'One-second bonus-hop gate prevents repeated bonus',
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Moth ignition is global, burn bonus applies once, and Scouring targets bosses',
    (tester) async {
      final g = await mount(tester, CharacterType.moth);
      await tester.runAsync(() async {
        final a = await body(g, 100),
            b = await body(g, 220),
            boss = await body(g, 340, boss: true);
        expect(g.hitEnemy(a, 1), true);
        expect(a.burnDamage, .35);
        expect(a.burnRemaining, 3);
        g.hitEnemy(b, 1);
        expect(b.burning, false);
        expect(g.burnMultiplier(a), 1.25);
        ranks(g, {PowerUp.hotShot: 3, PowerUp.scouringHeat: 3});
        g.hitEnemy(boss, 1);
        expect(g.burnMultiplier(boss), closeTo(1.25 * 1.3, 1e-7));
        final hp = boss.combatHealth.current;
        boss.update(.5);
        expect(hp - boss.combatHealth.current, closeTo(.85 * 1.25 * 1.3, 1e-6));
        boss.ignite(.1);
        expect(boss.burnDamage, closeTo(.85, 1e-8));
        g.pauseGame();
        final burn = boss.burnRemaining;
        boss.update(10);
        expect(boss.burnRemaining, burn);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Coil fans count once and fifth release hits a different owner without recursion',
    (tester) async {
      final g = await mount(tester, CharacterType.coil);
      await tester.runAsync(() async {
        final a = await body(g, 100), b = await body(g, 230);
        for (var release = 0; release < 5; release++) {
          g.primaryRelease(2);
          final id = g.gameNotifier.survivor.lastRelease;
          for (var pellet = 0; pellet < 9; pellet++) {
            g.hitEnemy(a, 2, releaseId: id);
          }
        }
        expect(b.combatHealth.current, closeTo(998.9, 1e-6));
        expect(g.gameNotifier.survivor.chainVictims, 1);
        expect(g.gameNotifier.survivor.coil, 0);
        final snapshot = g.checkpoint();
        snapshot['enemies'] =
            []; // Test bodies are deliberately outside the saved enemy catalog.
        expect(RunCheckpoint.valid(snapshot), true);
        final before = b.combatHealth.current;
        // The spent fifth release never becomes another hit after repeated contact.
        g.hitEnemy(a, 2, releaseId: g.gameNotifier.survivor.lastRelease);
        expect(b.combatHealth.current, before);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'main weapon blasts carry innate perks without enabling primary procs',
    (tester) async {
      final g = await mount(
        tester,
        CharacterType.moth,
        weapon: WeaponType.scrapMortar,
      );
      await tester.runAsync(() async {
        final a = await body(g, 100);
        ranks(g, {PowerUp.hotShot: 8, PowerUp.staticCharge: 8});
        final damage = g.primaryRelease(8), r = g.gameNotifier.survivor;
        g.explode(
          a.position.clone(),
          radius: 145,
          damage: damage,
          releaseId: r.lastRelease,
          releaseBonus: r.releaseBonus,
          reaction: WeaponReaction.of(WeaponType.scrapMortar),
        );
        expect(
          a.burnDamage,
          .35,
          reason: 'Innate ignition works, acquired primary Hot Shot remains excluded',
        );
        expect(g.gameNotifier.survivor.chainVictims, 0);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Harrow classification and weakpoint transfer apply the bonus once',
    (tester) async {
      final g = await mount(tester, CharacterType.harrow);
      await tester.runAsync(() async {
        final ordinary = await body(g, 100),
            boss = await body(g, 300, boss: true);
        g.hitEnemy(ordinary, 10);
        g.hitEnemy(boss, 10);
        expect(ordinary.combatHealth.current, 991);
        expect(boss.combatHealth.current, 988.5);
        final part = BossWeakPoint(
          owner: boss,
          position: boss.position.clone(),
          kind: BossPropKind.valve,
          onBroken: () {},
          health: 100,
        );
        await g.world.add(part);
        await g.ready();
        g.hitEnemy(part, 10);
        expect(part.combatHealth.current, 88.5);
        expect(boss.combatHealth.current, 982.75);
        g.hitEnemy(ordinary, 10, primary: false);
        expect(ordinary.combatHealth.current, 981);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Fuse recharge floor and source-owned grenade rewards stay separate from mines',
    (tester) async {
      final g = await mount(tester, CharacterType.fuse);
      await tester.runAsync(() async {
        expect(g.grenadeRecharge, 16);
        ranks(g, {PowerUp.grenadeRecharge: 8, PowerUp.grenadeDamage: 8});
        expect(g.grenadeRecharge, 10);
        final a = await body(g, 100);
        a.restoreHealth(5, maximum: 5);
        g.combat.explode(
          a.position.clone(),
          radius: 205,
          damage: 8,
          grenade: true,
        );
        expect(g.gameNotifier.survivor.grenadeKills, 1);
        final b = await body(g, 400);
        b.restoreHealth(5, maximum: 5);
        g.explode(
          b.position.clone(),
          radius: 185,
          damage: 8,
          reaction: WeaponReaction.mine,
        );
        expect(g.gameNotifier.survivor.grenadeKills, 1);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'conditional damage cap, frozen bonus and reload walking have useful effects',
    (tester) async {
      final g = await mount(
        tester,
        CharacterType.flint,
        weapon: WeaponType.anchorEngine,
      );
      await tester.runAsync(() async {
        ranks(g, {
          PowerUp.measuredShot: 8,
          PowerUp.closeQuarters: 8,
          PowerUp.braceLoader: 8,
          PowerUp.sureFoot: 8,
          PowerUp.exposedSeam: 8,
        });
        final b = await body(g, 120);
        b.freeze();
        g.gameNotifier.survivor.completedReload(CharacterType.flint);
        final amount = g.primaryRelease(10), r = g.gameNotifier.survivor;
        expect(amount, closeTo(15.6, 1e-8));
        g.hitEnemy(
          b,
          amount,
          releaseId: r.lastRelease,
          releaseBonus: r.releaseBonus,
          travel: 100,
        );
        expect(1000 - b.combatHealth.current, closeTo(16 * 1.27, 1e-6));
        final baseline = g.playerWalkSpeed;
        g.gameNotifier.decreaseBullets();
        g.gameNotifier.reloadBullets();
        expect(g.playerWalkSpeed, closeTo(baseline * 1.18, 1e-6));
        expect(baseline, greaterThan(291 * .93));
        g.pauseGame();
        final charge = r.reloadCharge;
        g.update(10);
        expect(r.reloadCharge, charge);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
