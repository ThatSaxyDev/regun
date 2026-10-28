import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/combat_enemy.dart';
import 'package:regun/components/enemies/ground_projection.dart';
import 'package:regun/components/enemies/pattern_boss.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/systems/arena_geometry.dart';
import 'package:regun/systems/supply_drops.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/widgets/boss_victory_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Audio extends SoloudPlay {
  @override
  Future<void> play(String s) async {}
  @override
  Future<void> playMusic(String s) async {}
  @override
  void pauseMusic(bool p) {}
}

class _Body extends PositionComponent
    with HasGameReference<RegunGame>, CombatEnemy {
  _Body(Vector2 at)
    : super(position: at, size: Vector2.all(80), anchor: Anchor.center);
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
            home: RepaintBoundary(
              key: Key('combat-scene'),
              child: BaseView(loadout: Loadout(training: true)),
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

  testWidgets(
    'boss deaths award two overflow HP once, survive Continue, and queue paused banners',
    (tester) async {
      final game = await mount(tester);
      await tester.runAsync(() async {
        final max = game.gameState.maxHealth;
        for (final kind in [BossKind.queen, BossKind.demon]) {
          game.spawnBoss(kind);
          await game.ready();
          final boss = game.activeBoss! as CombatEnemy;
          boss.takeDamage(100000);
          boss.takeDamage(100000); // Death must not grant twice.
          await game.ready();
        }
        expect(game.gameState.health, max + 4);
        expect(game.gameState.maxHealth, max);
        game.gameNotifier.heal();
        expect(game.gameState.health, max + 4);
        expect(game.bossVictory.current.value, BossKind.queen);
        final time = game.bossVictory.remaining;
        game.pauseGame();
        game.update(10);
        expect(game.bossVictory.remaining, time);
        game.resumeGame();
        game.bossVictory.update(2.81);
        expect(game.bossVictory.current.value, BossKind.demon);
        final snapshot = game.checkpoint();
        expect(RunCheckpoint.valid(snapshot), isTrue);
        expect(
          RunCheckpoint.valid({
            ...snapshot,
            'state': {...snapshot['state'] as Map, 'maxHealth': 0},
          }),
          isFalse,
        );
        game.restartGame();
        await game.ready();
        expect(game.restoreRun(snapshot), isTrue);
        expect(game.gameState.health, max + 4);
        expect(
          game.bossVictory.current.value,
          isNull,
        ); // Continue never re-awards or re-announces.
        final actors = game.world.children.whereType<PositionComponent>().where(
          (a) => a is CombatEnemy || identical(a, game.myPlayer),
        );
        expect(
          game.world.children.whereType<GroundProjection>().every(
            (f) => actors.every((a) => f.priority < a.priority),
          ),
          isTrue,
        );
      });
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'every boss owns a separate floor projection below negative-world actors',
    (tester) async {
      final game = await mount(tester);
      await tester.runAsync(() async {
        game.myPlayer.position.setValues(0, -1200);
        game.myPlayer.update(0);
        for (final kind in _legacyBosses) {
          game.practiceBoss(kind);
          await game.ready();
          final boss = game.activeBoss!;
          boss.position.setValues(180, -1200);
          boss.update(0);
          final floors = game.world.children
              .whereType<GroundProjection>()
              .where((f) => identical(f.owner, boss))
              .toList();
          expect(floors, hasLength(1), reason: kind.title);
          expect(floors.single.parent, game.world);
          expect(floors.single.priority, lessThan(game.myPlayer.priority));
          expect(floors.single.priority, lessThan(boss.priority));
          game.practiceBoss(kind);
          await game.ready();
          expect(floors.single.isRemoving || floors.single.isRemoved, isTrue);
        }
      });
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'grenade pressure moves outer survivors without damage and respects cover',
    (tester) async {
      final game = await mount(tester);
      await tester.runAsync(() async {
        final outer = _Body(Vector2(300, 0)),
            blocked = _Body(Vector2(-300, 0)),
            far = _Body(Vector2(0, 450));
        await game.world.addAll([outer, blocked, far]);
        await game.ready();
        game.geometry = ArenaGeometry(
          game.map.bounds,
          obstacles: [const Rect.fromLTWH(-180, -80, 40, 160)],
        );
        game.combat.explode(
          Vector2.zero(),
          radius: 205,
          damage: 8,
          grenade: true,
        );
        for (var i = 0; i < 40; i++) {
          outer.update(.01);
          blocked.update(.01);
          far.update(.01);
        }
        expect(outer.position.x, greaterThan(360));
        expect(outer.combatHealth.current, 10000);
        expect(blocked.position.x, -300);
        expect(blocked.combatHealth.current, 10000);
        expect(far.position.y, 450);
      });
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'landed pod blocks walking, fast enemy motion and shot sight until breakdown',
    (tester) async {
      final game = await mount(tester);
      await tester.runAsync(() async {
        game.supplyDrops.drop = SupplyDrop(Offset.zero)
          ..phase = SupplyPhase.active;
        expect(game.geometry.solids.single, game.supplyDrops.drop!.footprint);
        game.myPlayer.position.setValues(-160, -26);
        game.moveActor(game.myPlayer, Vector2(1, 0), 2000, .2);
        expect(game.myPlayer.position.x, lessThanOrEqualTo(-76));
        final enemy = _Body(Vector2(160, -26));
        await game.world.add(enemy);
        await game.ready();
        game.moveTo(enemy, Vector2(-160, -26), 36);
        expect(enemy.position.x, greaterThanOrEqualTo(82));
        expect(
          game.segmentBlocked(Vector2(-120, -26), Vector2(120, -26)),
          isTrue,
        );
        game.supplyDrops.drop!.phase = SupplyPhase.breaking;
        expect(game.geometry.solids, isEmpty);
        expect(
          game.segmentBlocked(Vector2(-120, -26), Vector2(120, -26)),
          isFalse,
        );
      });
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Queen warning and grounded pod render beneath the survivor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final font in ['PressStart2P', 'Orbitron']) {
        await (FontLoader(
          font,
        )..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf'))).load();
      }
    });
    final game = await mount(tester);
    await tester.runAsync(() async {
      game.myPlayer.position.setValues(100, -900);
      game.practiceBoss(BossKind.queen);
      await game.ready();
      final queen = game.activeBoss! as PatternBoss;
      queen.position.setValues(140, -1000);
      queen.phase = PatternBossPhase.warning;
      queen.pattern = 1;
      queen.clock = .4;
      game.supplyDrops.drop = SupplyDrop(const Offset(340, -1000))
        ..phase = SupplyPhase.active;
      game.update(.001);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await game.ready();
    });
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('combat-scene')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/queen-ground-layers.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'victory stamp fits narrow enlarged text and renders game typography',
    (tester) async {
      for (final font in ['PressStart2P', 'Orbitron']) {
        await (FontLoader(
          font,
        )..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf'))).load();
      }
      tester.view.physicalSize = const Size(320, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const capture = Key('victory');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Color(0xff171B18),
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Center(
                child: RepaintBoundary(
                  key: capture,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: BossVictoryBanner(kind: BossKind.queen),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('VANQUISHED'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(capture),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/boss-vanquished.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    },
  );
}

final _legacyBosses = BossKind.active
    .where((kind) => kind != BossKind.walker)
    .toList();
