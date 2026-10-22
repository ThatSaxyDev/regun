import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/components/weapons/weapon_art.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Audio extends SoloudPlay {
  final cues = <String>[];
  @override
  Future<void> play(String asset) async {
    cues.add(asset);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalPreferences.shared.load();
    await RegunArt.shared.load();
    for (final name in ['PressStart2P', 'Orbitron']) {
      await (FontLoader(
        name,
      )..addFont(rootBundle.load('assets/fonts/$name-Regular.ttf'))).load();
    }
  });

  Future<RegunGame> mount(WidgetTester tester, _Audio audio) async {
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(audio)],
          child: const MaterialApp(
            home: BaseView(
              loadout: Loadout(weapon: WeaponType.burstRifle, training: true),
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
    'burst rounds consume separate ammo, turn, pause and finish reload',
    (tester) async {
      final audio = _Audio();
      final game = await mount(tester, audio);
      // Use release statistics and real components rather than visual-only clocks.
      await tester.runAsync(() async {
        game.weaponJoystick.delta.setValues(60, 0);
        game.weaponJoystick.delta.setValues(60, 0);
        game.update(.01);
        await game.ready();
        expect(game.shotsFired, 1);
        expect(game.gameState.noOfBullets, 17);
        game.weaponJoystick.delta.setValues(60, 0);
        game.update(.09);
        await game.ready();
        expect(game.shotsFired, 2);
        game.weaponJoystick.delta.setValues(0, 60);
        game.update(.10);
        await game.ready();
        expect(game.shotsFired, 3);
        expect(
          game.world.children.whereType<BulletComponent>().last.direction.y,
          closeTo(1, .001),
        );
        expect(game.gameState.noOfBullets, 15);
        game.weaponJoystick.delta.setValues(60, 0);
        game.update(.39);
        expect(game.shotsFired, 3);
        game.weaponJoystick.delta.setValues(60, 0);
        game.update(.01);
        expect(game.shotsFired, 4);
        game.gameNotifier.reloadBullets(manual: true);
        game.update(.30);
        expect(game.shotsFired, 4);
        expect(game.burstFire.pending, 0);
        expect(game.gameState.reloading, isTrue);
        game.pauseGame();
        final progress = game.gameNotifier.reloadProgress.value;
        game.update(1);
        expect(game.gameNotifier.reloadProgress.value, progress);
        expect(game.shotsFired, 4);
        expect(audio.cues.where((c) => c.startsWith('shot_')).length, 4);
        final save = game.checkpoint();
        expect(RunCheckpoint.valid(save), isTrue);
        save['burstRecovery'] = double.nan;
        expect(RunCheckpoint.valid(save), isFalse);
        game.gameNotifier.playGame();
        game.weaponJoystick.delta.setZero();
        game.update(1.099);
        expect(game.gameState.noOfBullets, 14);
        expect(game.gameState.reloading, isTrue);
        game.update(.001);
        expect(game.gameState.noOfBullets, 18);
        expect(game.gameState.reloading, isFalse);
        game.restartGame();
        await game.ready();
        expect(game.burstFire.pending, 0);
        expect(game.burstFire.recovery, 0);
      });
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('saturated volley spends neither ammo nor a firing cue', (
    tester,
  ) async {
    final audio = _Audio();
    final game = await mount(tester, audio);
    await tester.runAsync(() async {
      for (var i = 0; i < RegunGame.maxProjectiles; i++) {
        game.addProjectile(
          BulletComponent(
            position: Vector2(-1500, -1500),
            direction: Vector2(1, 0),
            speed: 0,
          ),
        );
      }
      await game.ready();
      game.weaponJoystick.delta.setValues(60, 0);
      game.weaponJoystick.delta.setValues(60, 0);
      game.update(.01);
      expect(game.shotsFired, 0);
      expect(game.gameState.noOfBullets, 18);
      expect(audio.cues.where((c) => c.startsWith('shot_')), isEmpty);
      game.world.children.whereType<BulletComponent>().first.removeFromParent();
      await game.ready();
      game.weaponJoystick.delta.setValues(60, 0);
      game.update(.05);
      await game.ready();
      expect(game.shotsFired, 1);
      expect(game.gameState.noOfBullets, 17);
      expect(audio.cues.where((c) => c.startsWith('shot_')), [
        'shot_burstRifle_0.wav',
      ]);
    });
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'held burst aim cannot fire before tactical reload seats and locks',
    (tester) async {
      final audio = _Audio();
      final game = await mount(tester, audio);
      await tester.runAsync(() async {
        game.gameNotifier.decreaseBullets();
        game.gameNotifier.reloadBullets(manual: true);
        expect(game.gameNotifier.reloadTactical, isTrue);
        for (var step = 0; step < 139; step++) {
          game.weaponJoystick.delta.setValues(60, 0);
          game.update(.01);
          expect(game.shotsFired, 0);
          expect(game.gameState.noOfBullets, 17);
        }
        game.weaponJoystick.delta.setValues(60, 0);
        game.update(.011);
        await game.ready();
        expect(game.shotsFired, 1);
        expect(game.gameState.noOfBullets, 17);
        expect(audio.cues.where((s) => s.startsWith('reload_')), [
          'reload_burstRifle_0.wav',
          'reload_burstRifle_1.wav',
        ]);
      });
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'boss victories settle once, repeated kinds count, Training never unlocks',
    () {
      final profile = PlayerProfile();
      void settle(String id, {bool training = false}) => profile.settle(
        runId: id,
        loadout: Loadout(training: training),
        kills: 1,
        score: 1,
        seconds: 1,
        earnedScrap: 0,
        scorpions: 0,
        elites: 0,
        bosses: {'shadow'},
        bossVictories: 3,
        noHitBosses: {},
        foundFusions: {},
        enemies: {},
      );
      settle('practice', training: true);
      expect(profile.totalBossVictories, 0);
      settle('one');
      settle('one');
      expect(profile.totalBossVictories, 3);
      expect(profile.weaponUnlocked(WeaponType.burstRifle), isTrue);
      final restored = PlayerProfile.fromJson(profile.toJson());
      expect(restored.totalBossVictories, 3);
      expect(restored.weaponUnlocked(WeaponType.burstRifle), isTrue);
      expect(
        PlayerProfile.fromJson({
          'schema': 1,
          'challenges': ['arcCaster'],
        }).weaponUnlocked(WeaponType.arcCaster),
        isTrue,
      );
      expect(WeaponType.burstRifle.availableOnline, isFalse);
    },
  );

  test('render real atlas assembly at reload events, mirrored aim and Reduced Motion', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xff161B18), BlendMode.src);
    const phases = [-1.0, 0.0, .1, .42, .72, .82, .94, 1.0];
    for (var row = 0; row < 6; row++) {
      for (var col = 0; col < phases.length; col++) {
        canvas.save();
        canvas.translate(110 + col * 180.0, 90 + row * 145.0);
        canvas.scale(2);
        if (row == 1) {
          canvas.rotate(math.pi);
          canvas.scale(1, -1);
        }
        if (row == 2) canvas.rotate(-math.pi / 4);
        paintWeapon(
          canvas,
          WeaponType.burstRifle,
          reload: phases[col],
          recoil: phases[col] < 0 ? .9 : 0,
          reducedMotion: row == 3 || row == 5,
          tactical: row >= 4,
        );
        canvas.restore();
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1500, 900);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/test-previews').create(recursive: true);
    await File('build/test-previews/burst-rifle-mechanism.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
