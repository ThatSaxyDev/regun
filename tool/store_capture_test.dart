// Store artwork capture. Run explicitly with flutter test tool/store_capture_test.dart.
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
import 'package:regun/desktop/desktop_bindings.dart';
import 'package:regun/game.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:regun/widgets/game_presentation.dart';
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
const _sizes = {
  'iphone': (Size(852, 393), 3.0),
  'ipad': (Size(2752 / 3, 688), 3.0),
  'duo-outer': (Size(678, 466), 3.0),
  'duo-inner': (Size(951, 669), 3.0),
  'play': (Size(960, 540), 2.0),
  'play-tablet': (Size(1280, 720), 1.5),
};

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

Future<void> _fire(RegunGame game, Vector2 direction, int frames) async {
  if (game.desktopInput case final input?) {
    final point = game.camera.localToGlobal(game.myPlayer.position + direction);
    input.pointer = Offset(point.x, point.y);
    input.fire = true;
    await _step(game, frames);
    input.cancelFire();
    return;
  }
  game.weaponJoystick.delta.setFrom(direction);
  await _step(game, frames);
  game.weaponJoystick.delta.setZero();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerStoreCaptures();
}

void registerStoreCaptures({bool nativeMac = false}) {
  late Directory captureDirectory;
  setUpAll(() async {
    if (nativeMac) {
      expect(Platform.isMacOS, isTrue);
      captureDirectory = await Directory.systemTemp.createTemp(
        'regun-store-macos-',
      );
      // ignore: avoid_print
      print('REGUN_MACOS_CAPTURES=${captureDirectory.path}');
    }
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

  final sizes = nativeMac ? {'macos': (const Size(1440, 900), 2.0)} : _sizes;
  for (final target in sizes.entries) {
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
              builder: nativeMac
                  ? (context, child) => GamePresentation(
                      scale: DesktopBindings.textBaseline,
                      child: child!,
                    )
                  : null,
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
        final directory = nativeMac
            ? captureDirectory
            : (Directory('store-artboards/sources/${target.key}')
                ..createSync(recursive: true));
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
          await mount(
            BaseView(
              loadout: loadout,
              reviewControlledSpawns: true,
              runStore: nativeMac
                  ? RunStore(
                      directory: Directory(
                        '${captureDirectory.path}/checkpoints',
                      ),
                    )
                  : null,
            ),
          );
          final game =
              tester
                      .widget<RiverpodAwareGameWidget>(
                        find.byType(RiverpodAwareGameWidget),
                      )
                      .game!
                  as RegunGame;
          if (nativeMac) expect(game.usingDesktopInput, isTrue);
          await game.loaded;
          await tester.pump();
          await game.ready();
          game.pauseEngine();
          game.random.state = 128;
          game.gameNotifier.resetRun(loadout: loadout, seed: 128);
          await _step(game, 130);
          return game;
        }

        final breach = await start(const Loadout());
        await _crowd(breach);
        await _fire(breach, Vector2(70, -15), 6);
        await save('01-survival');

        final foundry = await start(
          const Loadout(weapon: WeaponType.arcCaster, arena: ArenaType.foundry),
        );
        await _crowd(foundry, left: true);
        await _fire(foundry, Vector2(-70, -20), 12);
        await save('02-weapons');

        foundry.gameNotifier.increaseXP(
          foundry.gameState.noOfCoinsToUpgrade.ceil(),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await save('03-upgrades');

        final boss = await start(
          const Loadout(arena: ArenaType.foundry, training: true),
        );
        boss.practiceLodestar();
        for (
          var i = 0;
          i < 150 && boss.lodestarCandidate?.prepared != true;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 16));
          await Future<void>.delayed(const Duration(milliseconds: 10));
          boss.update(1 / 120);
        }
        expect(boss.lodestarCandidate?.prepared, isTrue);
        boss.pauseEngine();
        final lodestar = boss.lodestarCandidate!;
        var visibleSections = 0;
        for (var i = 0; i < 1600 && visibleSections < 4; i++) {
          await _step(boss, 1);
          final field = boss.camera.visibleWorldRect.deflate(85);
          visibleSections = lodestar.fight.rig.poses
              .where((pose) => field.contains(pose.position))
              .length;
          if (boss.inputBlocked ||
              lodestar.fight.depths.any((depth) => depth > 0)) {
            visibleSections = 0;
          }
        }
        expect(visibleSections, greaterThanOrEqualTo(4));
        final aim = lodestar.position - boss.myPlayer.position;
        await _fire(boss, aim.normalized() * 70, 5);
        await save('04-bosses');

        await mount(const LoadoutView());
        for (final arena in ['breach', 'foundry']) {
          await precacheImage(
            AssetImage('assets/art/arenas/${arena}_floor.png'),
            tester.element(find.byType(LoadoutView)),
          );
        }
        for (var i = 0; i < 12; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 40));
        }
        await save('05-loadout');

        final supply = await start(const Loadout());
        supply.supplyDrops.nextIn = .05;
        await _step(supply, 175);
        final pod = supply.supplyDrops.drop!;
        supply.myPlayer.position.setValues(
          pod.position.dx - 140,
          pod.position.dy,
        );
        await _crowd(supply);
        await _step(supply, 45);
        await _fire(supply, Vector2(70, -15), 5);
        await save('06-airdrop');
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
