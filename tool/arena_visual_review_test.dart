// Gameplay camera review. Run with flutter test tool/arena_visual_review_test.dart.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/enemies/arena_enemy.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentAudio extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}

  @override
  Future<void> playMusic(String theme) async {}

  @override
  void pauseMusic(bool paused) {}
}

const _frame = Key('store-capture');
const _sizes = {'iphone': (Size(852, 393), 2.0)};

Future<void> _step(RegunGame game, int frames) async {
  for (var i = 0; i < frames; i++) {
    game.update(1 / 60);
    await game.ready();
  }
}

Future<void> _crowd(RegunGame game, {bool left = false}) async {
  final origin = game.myPlayer.position;
  const formation = [
    (EnemyKind.mummy, 190.0, -60.0),
    (EnemyKind.runner, 246.0, 108.0),
    (EnemyKind.ranged, 410.0, -130.0),
    (EnemyKind.scorpion, 268.0, -168.0),
    (EnemyKind.scorpion, 317.0, 42.0),
    (EnemyKind.shield, 385.0, 159.0),
    (EnemyKind.mummy, 138.0, 186.0),
    (EnemyKind.scorpion, -148.0, -190.0),
    (EnemyKind.burster, -252.0, 100.0),
    (EnemyKind.mummy, -375.0, -94.0),
    (EnemyKind.scorpion, 480.0, 20.0),
  ];
  for (final (kind, x, y) in formation) {
    await game.world.add(
      ArenaEnemy(kind, position: origin + Vector2(left ? -x : x, y)),
    );
  }
  await game.ready();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Keep capture profiles isolated from device preferences.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await LocalPreferences.shared.load();
    await RegunArt.shared.load();
    await (FontLoader('PressStart2P')
          ..addFont(rootBundle.load('assets/fonts/PressStart2P-Regular.ttf')))
        .load();
    final orbitron = FontLoader('Orbitron');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      orbitron.addFont(rootBundle.load('assets/fonts/Orbitron-$weight.ttf'));
    }
    await orbitron.load();
  });

  for (final target in _sizes.entries) {
    testWidgets('capture landscape ${target.key}', (tester) async {
      final (size, ratio) = target.value;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> mount(Widget child) async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [soloudPlayProvider.overrideWithValue(_SilentAudio())],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData.dark(),
              home: RepaintBoundary(key: _frame, child: child),
            ),
          ),
        );
      }

      Future<void> save(String name) async {
        final gameWidget = find.byType(RiverpodAwareGameWidget);
        if (gameWidget.evaluate().isNotEmpty) {
          final game = tester.widget<RiverpodAwareGameWidget>(gameWidget).game!;
          game.resumeEngine();
          await tester.pump(const Duration(milliseconds: 1));
          game.pauseEngine();
        }
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_frame),
        );
        final image = await boundary.toImage(pixelRatio: ratio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory(
          '${Directory.systemTemp.path}/regun-arena-review/${target.key}',
        )..createSync(recursive: true);
        await File('${directory.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      }

      await tester.runAsync(() async {
        LocalPreferences.shared.profile = PlayerProfile(
          challenges: {'training', 'foundry', 'arcCaster', 'harrow'},
          totalBossVictories: 3,
          preferredCharacter: CharacterType.harrow,
          preferredArena: ArenaType.foundry,
        );
        await LocalPreferences.shared.saveProfile();

        Future<RegunGame> start(Loadout loadout) async {
          await mount(BaseView(loadout: loadout, reviewControlledSpawns: true));
          final game =
              tester
                      .widget<RiverpodAwareGameWidget>(
                        find.byType(RiverpodAwareGameWidget),
                      )
                      .game!
                  as RegunGame;
          await game.loaded;
          await tester.pump();
          await game.ready();
          game.pauseEngine();
          game.random.state = 128;
          game.gameNotifier.resetRun(loadout: loadout, seed: 128);
          await _step(game, 130);
          return game;
        }

        for (final arena in ArenaType.values) {
          final game = await start(
            Loadout(arena: arena, weapon: WeaponType.shotgun),
          );
          for (final solid in game.geometry.obstacles) {
            final start = Vector2(solid.left - 65, solid.center.dy);
            game.myPlayer.position.setFrom(start);
            game.moveActor(game.myPlayer, Vector2(1, 0), 1000, .5);
            expect(
              game.myPlayer.position.x,
              lessThanOrEqualTo(solid.left - 29),
              reason: '${arena.name} player crossing $solid',
            );
            game.myPlayer.position.setFrom(start - Vector2(0, 300));
            final enemy = ArenaEnemy(EnemyKind.runner, position: start.clone());
            await game.world.add(enemy);
            await game.ready();
            game.moveActor(
              enemy,
              Vector2(1, 0),
              1000,
              .5,
              avoidCrowd: false,
              airborne: true,
            );
            expect(
              enemy.position.x,
              lessThan(solid.left),
              reason: '${arena.name} airborne enemy crossing $solid',
            );
            enemy.removeFromParent();
            await game.ready();
          }
          game.myPlayer.position.setFrom(game.playerEntrance.landingPosition);
          await _step(game, 10);
          await save('${arena.name}-arrival');
          if (arena == ArenaType.foundry || arena == ArenaType.relayGraveyard) {
            final press = game.geometry.obstacles.first;
            game.myPlayer.position.setValues(
              press.left - 260,
              press.bottom + 70,
            );
            await _step(game, 30);
          }
          if (arena == ArenaType.floodworks) {
            final gate = game.map.regions('floodworks_gate').single;
            game.myPlayer.position.setValues(gate.left - 230, gate.bottom + 32);
            await _step(game, 30);
            await save('floodworks-gate');
            await _step(game, 30);
            await save('floodworks-current');
            final divider = game.geometry.obstacles[1];
            game.myPlayer.position.setValues(
              divider.left - 265,
              divider.center.dy,
            );
            await _step(game, 30);
            await save('floodworks-divider');

            game.myPlayer.position.setFrom(game.playerEntrance.landingPosition);
          }
          await _crowd(game, left: arena == ArenaType.floodworks);
          await _step(game, 20);
          await save('${arena.name}-combat');
          if (arena == ArenaType.floodworks) {
            final at = game.map.anchors('floodworks_vents').single;
            final enemy = ArenaEnemy(EnemyKind.mummy, position: at.clone());
            expect(game.registerEnemy(enemy), isTrue);
            await game.world.add(enemy);
            await game.ready();
            final health = enemy.combatHealth.current;
            game.addHostileArea(
              at,
              radius: 330,
              warning: 2,
              active: 3,
              cause: 'Sluice surge',
            );
            await _step(game, 45);
            await save('floodworks-warning');
            await _step(game, 98);
            expect(enemy.combatHealth.current, lessThan(health));
            await save('floodworks-surge');
            await _step(game, 182);
            await save('floodworks-draining');
          }
        }
      });
    });
  }
}
