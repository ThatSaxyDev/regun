import 'package:regun/systems/ariet_escort_tactics.dart';
import 'package:regun/presentation/walker_art.dart';
import 'package:regun/presentation/ariet_battle_art.dart';

import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/ariet_boss.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/systems/ariet_combat.dart';
import 'package:regun/systems/ariet_rig.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String path) async {}
  @override
  Future<void> playMusic(String path) async {}
  @override
  void pauseMusic(bool paused) {}
  @override
  void configure({required double music, required double sfx}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  WidgetTester? activeTester;
  Future<RegunGame> mount(WidgetTester tester) async {
    activeTester = tester;
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: const MaterialApp(
            home: BaseView(
              loadout: Loadout(training: true),
              reviewControlledSpawns: true,
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
      game.pauseEngine();
      game.update(2);
      await game.ready();
    });
    return game;
  }

  Future<ArietBoss> ready(RegunGame g) async {
    for (var i = 0; i < 100 && g.arietCandidate?.prepared != true; i++) {
      await activeTester!.pump();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      g.update(1 / 120);
    }
    await g.ready().timeout(const Duration(seconds: 2));
    expect(g.arietCandidate?.prepared, isTrue);
    g.pauseEngine();
    return g.arietCandidate!;
  }

  Future<void> advance(RegunGame g, double seconds, {bool held = false}) async {
    for (var t = 0.0; t < seconds - 1e-8; t += .025) {
      g.weaponJoystick.delta.setValues(held ? 70 : 0, 0);
      g.update((seconds - t).clamp(0, .025));
      await g.ready();
    }
  }

  testWidgets(
    'Training selector plays arrival, full roof arsenal, escorts, health loss, recovery and non-damaging fatal cleanup',
    (tester) async {
      final g = await mount(tester);
      final controlScale = g.reloadButtonComponent.scale.clone();
      final controlPosition = g.reloadButtonComponent.position.clone();
      g.pauseGame();
      await tester.pump();
      await tester.ensureVisible(find.text('BOSS PRACTICE'));
      await tester.tap(find.text('BOSS PRACTICE'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      final button = find.byKey(const Key('practice-boss-ariet'));
      await tester.ensureVisible(button);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      for (var i = 0; i < 200 && g.arietCandidate?.prepared != true; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.runAsync(() async {
        final b = await ready(g);
        expect(g.mechanicalTrial, MechanicalTrial.ariet);
        expect(g.walkerTrial, isFalse);
        expect(g.bosses, isEmpty);
        expect(g.trainingDamage, isFalse);
        expect(
          b.assets.walker.arsenal,
          isNotNull,
          reason: 'seekers need their actual arsenal sprite sheet',
        );
        expect(b.assets.walker.rects['rocket'], isNotNull);
        final rocketRecorder = ui.PictureRecorder();
        WalkerArt(b.assets.walker)
            .part(Canvas(rocketRecorder), 'rocket', const Offset(64, 40), 64);
        final rocketPicture = rocketRecorder.endRecording(),
            rocketImage = await rocketPicture.toImage(128, 80);
        final rocketPixels = (await rocketImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        var metalPixels = 0;
        for (var y = 30; y < 50; y++) {
          for (var x = 40; x < 88; x++) {
            if (rocketPixels[(y * 128 + x) * 4 + 3] > 128) metalPixels++;
          }
        }
        expect(
          metalPixels,
          greaterThan(200),
          reason: 'visible metal nose/body/fins, not only a red glow',
        );
        Directory('build/ariet-fight').createSync(recursive: true);
        final rocketPng = await rocketImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        File('build/ariet-fight/rocket-body.png')
            .writeAsBytesSync(rocketPng!.buffer.asUint8List());
        rocketImage.dispose();
        rocketPicture.dispose();
        // Each real rocket exit must produce visible airborne ember pixels,
        // independently of a subdued floor scorch or an actor covering it.
        for (final ending in ['intercept', 'contact', 'wall', 'expiry']) {
          final f =
              ArietCombat(
                  rig: ArietRig(),
                  clear: (a, z, _) => ending != 'wall' || z.dx < 10,
                  hurt: (_, __) => true,
                  signal: (_) {},
                  landingLegal: (_, __) => true,
                  deploy: (_) {},
                )
                ..phase = ArietPhase.recovery
                ..player = ending == 'contact'
                    ? const Offset(55, 0)
                    : const Offset(0, 9000);
          final rocket = ArietRound(Offset.zero, 0, seeker: true);
          if (ending == 'expiry') rocket.age = 3.49;
          f.rounds.add(rocket);
          if (ending == 'intercept') {
            f.intercept(rocket);
          } else {
            f.advance(.12);
          }
          expect(f.impacts.where((i) => i.rocketBlast), hasLength(1));
          for (final reduced in [false, true]) {
            final burstRecorder = ui.PictureRecorder();
            final burstCanvas = Canvas(burstRecorder);
            final at = f.impacts.single.position;
            burstCanvas.translate(128 - at.dx, 128 - at.dy);
            ArietBattleArt(b.assets)
                .rounds(burstCanvas, f, g.loadout.arena, reduced);
            final picture = burstRecorder.endRecording(),
                im = await picture.toImage(256, 256);
            final bytes = await im.toByteData();
            var warm = 0;
            for (var n = 0; n < bytes!.lengthInBytes; n += 4) {
              if (bytes.getUint8(n + 3) > 40 &&
                  bytes.getUint8(n) > bytes.getUint8(n + 1) * 1.1) {
                warm++;
              }
            }
            expect(
              warm,
              greaterThan(150),
              reason: '$ending burst visible, reduced=$reduced',
            );
            if (!reduced) {
              final png = await im.toByteData(format: ui.ImageByteFormat.png);
              File('build/ariet-fight/burst-$ending.png')
                  .writeAsBytesSync(png!.buffer.asUint8List());
            }
            im.dispose();
            picture.dispose();
          }
        }
        expect(
          b.assets.decodedBytes + RegunArt.shared.decodedBytes,
          lessThan(32 * 1024 * 1024),
        );
        await advance(g, 3.4);
        expect(b.fight.vulnerable, isTrue);
        expect(g.encounterCameraZoom, .74);
        expect(g.camera.viewfinder.zoom, closeTo(.74, .002));
        expect(g.reloadButtonComponent.scale, controlScale);
        expect(g.reloadButtonComponent.position, controlPosition);
        b.fight.escortQuota = 2;
        b.fight.deploymentSpent = false;
        expect(b.takeDamage(81), isTrue);
        Process? encoder;
        Future<String>? captureErrors;
        if (Platform.environment['REGUN_ARIET_FIGHT_CAPTURE'] == '1') {
          Directory('build/ariet-fight').createSync(recursive: true);
          encoder = await Process.start('ffmpeg', [
            '-y',
            '-loglevel',
            'error',
            '-f',
            'image2pipe',
            '-framerate',
            '15',
            '-i',
            '-',
            '-an',
            '-c:v',
            'libx264',
            '-pix_fmt',
            'yuv420p',
            '-movflags',
            '+faststart',
            'build/ariet-fight/native.mp4',
          ]);
          captureErrors = encoder.stderr
              .transform(systemEncoding.decoder)
              .join();
          addTearDown(() => encoder?.kill());
        }
        Future<void> frame() async {
          final target = encoder;
          if (target == null) return;
          final r = ui.PictureRecorder();
          g.render(Canvas(r));
          final p = r.endRecording(), im = await p.toImage(844, 390);
          final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
          target.stdin.add(bytes!.buffer.asUint8List());
          await target.stdin.flush();
          im.dispose();
          p.dispose();
        }

        final phases = <ArietPhase>{};
        final escortShooters = <int>{};
        var seekerStill = false;
        for (var i = 0; i < 30 * 55; i++) {
          if (i > 30 * 18 && !phases.contains(ArietPhase.exhaust)) {
            final podSide = b.rig.ground(const Offset(-30, 190));
            g.myPlayer.position.setValues(podSide.dx, podSide.dy);
          }
          if (i % 150 == 0) {}
          g.update(1 / 30);
          if (i % 4 == 0) await g.ready();
          phases.add(b.fight.phase);
          if (b.escortTactics.lastShooter case final shooter?) {
            escortShooters.add(shooter);
          }
          if (!seekerStill &&
              b.fight.rounds.where((r) => r.seeker).length >= 4) {
            seekerStill = true;
            final rec = ui.PictureRecorder();
            g.render(Canvas(rec));
            final pic = rec.endRecording(), image = await pic.toImage(844, 390);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            Directory('build/ariet-fight').createSync(recursive: true);
            File('build/ariet-fight/seeker-salvo.png')
                .writeAsBytesSync(png!.buffer.asUint8List());
            image.dispose();
            pic.dispose();
          }
          if (i.isEven) await frame();
        }
        expect(
          phases,
          containsAll([
            ArietPhase.strafe,
            ArietPhase.strafeBrake,
            ArietPhase.turnFire,
            ArietPhase.cannon,
            ArietPhase.flak,
            ArietPhase.seekers,
            ArietPhase.exhaust,
            ArietPhase.recovery,
          ]),
        );
        expect(
          seekerStill,
          isTrue,
          reason: 'actual four-or-more rocket volley in the native game',
        );
        expect(b.fight.totalDrops, 2);
        expect(b.fight.totalCannon, greaterThanOrEqualTo(4));
        expect(b.fight.totalEscort, greaterThan(0));
        expect(
          escortShooters,
          containsAll([1, 2]),
          reason: 'both real escorts must earn firing turns',
        );
        expect(b.fight.totalFlak, greaterThan(0));
        expect(b.fight.totalSeekers, greaterThan(0));
        expect(b.escorts, hasLength(2));
        expect(ArietEscort.rigScale, .55);
        for (final escort in b.escorts) {
          expect(g.crowdRadius(escort), closeTo(88 * .55, .001));
          expect(
            escort.rig.maxSpeed * ArietEscort.rigScale,
            closeTo(385, .001),
          );
        }
        expect(
          b.escorts.every((e) => e.prepared && e.combatHealth.maximum == 50),
          isTrue,
        );
        expect(g.gameState.kills, 0);
        expect(g.gameState.bosses, 0);
        // A carried/empty gunship stays genuinely above the floor and draws
        // over either escort, independent of ordinary y ordering.
        expect(
          b.rig.height,
          inInclusiveRange(
            ArietCombat.flightHeight - 7,
            ArietCombat.flightHeight + 7,
          ),
        );
        expect(
          (b.position.toOffset() - b.rig.bodyPosition).distance,
          lessThan(.001),
        );
        expect(b.rig.position.dy - b.position.y, closeTo(112, 5));
        expect(
          b.bodyPriority,
          greaterThan(
            b.escorts.map((e) => e.priority).reduce((a, c) => a > c ? a : c),
          ),
        );
        expect(g.targetDistance(b, b.position), 0);
        b.fight.paused = true;
        b.fight.rounds.clear();
        b.rig.position = Offset.zero;
        b.position.setValues(b.rig.bodyPosition.dx, b.rig.bodyPosition.dy);
        // Inspect actual body pixels: a restored hover offset must move the
        // whole painted assembly, not merely its authoritative target getter.
        final originalPhase = b.fight.phase;
        b.fight.phase = ArietPhase.recovery;
        b.rig.enginesRunning = false;
        b.rig.exhaustPuffs.clear();
        Future<double> paintedY(double height) async {
          b.rig.height = height;
          final rec = ui.PictureRecorder(),
              canvas = Canvas(rec)..translate(256, 350);
          ArietBattleArt(b.assets).body(canvas, b.fight, false, null);
          final picture = rec.endRecording(),
              image = await picture.toImage(512, 700);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          var sum = 0.0, weightedY = 0.0;
          for (var y = 0; y < 700; y++) {
            for (var x = 0; x < 512; x++) {
              final alpha = bytes[(y * 512 + x) * 4 + 3];
              sum += alpha;
              weightedY += y * alpha;
            }
          }
          image.dispose();
          picture.dispose();
          expect(sum, greaterThan(0));
          return weightedY / sum;
        }

        final groundedPaint = await paintedY(0),
            airbornePaint = await paintedY(ArietCombat.flightHeight);
        expect(groundedPaint - airbornePaint, closeTo(112, 1.0));
        // Freeze the hull and remove smoke, then compare actual painted pixels.
        // A frozen jet image cannot pass by relying on body bob or drifting puffs.
        b.rig.enginesRunning = true;
        final liveHover = b.rig.hoverMotion;
        b.rig.hoverMotion = false;
        b.rig.command = b.rig.velocity = Offset.zero;
        b.rig.desiredYaw = b.rig.yaw;
        b.rig.thrust = .18;
        Future<List<int>> flamePixels(double advance, bool reduced) async {
          b.rig.reducedMotion = reduced;
          b.rig.advance(advance);
          b.rig.bank = b.rig.pitch = b.rig.podAngle = 0;
          b.rig.exhaustPuffs.clear();
          final rec = ui.PictureRecorder(),
              canvas = Canvas(rec)..translate(256, 350);
          ArietBattleArt(b.assets).body(canvas, b.fight, reduced, null);
          final picture = rec.endRecording(),
              image = await picture.toImage(512, 700);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List().toList();
          image.dispose();
          picture.dispose();
          return bytes;
        }

        for (final reduced in [false, true]) {
          final first = await flamePixels(.04, reduced),
              second = await flamePixels(.07, reduced);
          var changed = 0;
          for (var i = 0; i < first.length; i += 4) {
            if ((first[i] - second[i]).abs() +
                    (first[i + 1] - second[i + 1]).abs() +
                    (first[i + 2] - second[i + 2]).abs() >
                25) {
              changed++;
            }
          }
          expect(
            changed,
            greaterThan(30),
            reason:
                'jet flow must animate while hull is stationary, reduced=$reduced',
          );
        }
        b.rig.hoverMotion = liveHover;
        b.rig.reducedMotion = g.preferences.reducedMotion;
        b.fight.phase = originalPhase;
        b.rig.command = b.rig.velocity = Offset.zero;
        b.rig.exhaustPuffs.clear();
        b.rig.advance(.3);
        final firstEscort = b.escorts[0], secondEscort = b.escorts[1];
        secondEscort.position.setValues(900, 700);
        firstEscort.position.setValues(-340, 0);
        g.crowdOccupancy.rebuild(b.escorts, g.crowdRadius);
        expect(g.reserveEnemySpace(b), isTrue);
        g.moveTo(firstEscort, Vector2(340, 0), 88 * ArietEscort.rigScale);
        expect(
          firstEscort.position.x,
          closeTo(340, .01),
          reason: 'walk beneath Ariet after its reservation call',
        );
        g.moveTo(firstEscort, Vector2(-340, 0), 88 * ArietEscort.rigScale);
        expect(firstEscort.position.x, closeTo(-340, .01));
        // Real escort AI crosses from swapped flank goals without either body
        // crossing through the other or remaining in a head-on deadlock.
        g.myPlayer.position.setZero();
        b.escortTactics.reset();
        b.escortTactics.advance(
          .025,
          target: Offset.zero,
          velocity: Offset.zero,
          bodies: const [
            ArietEscortBody(1, Offset(183, -170)),
            ArietEscortBody(2, Offset(183, 170)),
          ],
          legal: b.escortGoalLegal,
        );
        firstEscort.position.setValues(183, 170);
        secondEscort.position.setValues(183, -170);
        for (var i = 0; i < 320; i++) {
          g.update(.025);
          await g.ready();
          expect(
            firstEscort.position.distanceTo(secondEscort.position),
            greaterThanOrEqualTo(176 * ArietEscort.rigScale - .8),
          );
        }
        final firstGoal = b.escortTactics.goalFor(1)!,
            secondGoal = b.escortTactics.goalFor(2)!;
        expect(
          (firstEscort.position.toOffset() - firstGoal).distance,
          lessThan(120),
        );
        expect(
          (secondEscort.position.toOffset() - secondGoal).distance,
          lessThan(120),
        );
        expect(
          ArietEscortTactics.difference(
            ArietEscortTactics.angle(firstEscort.position.toOffset()),
            ArietEscortTactics.angle(secondEscort.position.toOffset()),
          ).abs(),
          greaterThan(1.0),
        );
        // The rear Walker detects the actual live teammate in its muzzle lane.
        firstEscort.position.setValues(-330, 0);
        secondEscort.position.setValues(-540, 0);
        firstEscort.rig.carryTo(
          firstEscort.position.toOffset() / ArietEscort.rigScale,
        );
        secondEscort.rig.carryTo(
          secondEscort.position.toOffset() / ArietEscort.rigScale,
        );
        firstEscort.rig.turretYaw = secondEscort.rig.turretYaw = 0;
        expect(secondEscort.firingLaneClear, isFalse);
        expect(firstEscort.firingLaneClear, isTrue);
        b.escortTactics.reset();
        for (var i = 0; i < 400; i++) {
          g.update(.025);
          await g.ready();
        }
        expect(
          ArietEscortTactics.difference(
            ArietEscortTactics.angle(firstEscort.position.toOffset()),
            ArietEscortTactics.angle(secondEscort.position.toOffset()),
          ).abs(),
          greaterThan(1.0),
          reason: 'same-line pursuit must become two real attack angles',
        );
        final airRecorder = ui.PictureRecorder();
        g.render(Canvas(airRecorder));
        final airPicture = airRecorder.endRecording(),
            airImage = await airPicture.toImage(844, 390);
        final airBytes = await airImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        Directory('build/ariet-fight').createSync(recursive: true);
        File('build/ariet-fight/airborne-pair.png')
            .writeAsBytesSync(airBytes!.buffer.asUint8List());
        airImage.dispose();
        airPicture.dispose();
        // Real movement input stays held: both escorts must acquire and fire
        // without waiting for a stationary player or the gunship to finish a cycle.
        b.fight.paused = false;
        b.fight.phase = ArietPhase.navigate;
        b.fight.clock = 0;
        b.fight.grace = 100;
        b.fight.rounds.clear();
        g.setTrainingDamage(true);
        g.gameNotifier.resetHealth();
        var movingHits = 0;
        final beforeMoving = b.fight.totalEscort;
        final movingShooters = <int>{};
        var distinctAngles = 0;
        final movingRoles = <int, Set<ArietEscortRole>>{};
        for (var i = 0; i < 480; i++) {
          final a = i * .025;
          g.movementJoystick.delta.setValues(
            70 * math.cos(a),
            70 * math.sin(a),
          );
          final health = g.gameState.health;
          g.update(.025);
          await g.ready();
          if (g.gameState.health < health) {
            movingHits++;
            g.gameNotifier.resetHealth();
          }
          final live = b.escorts.where((e) => !e.isRemoving).toList();
          if (live.length == 2) {
            final a = live[0].position - g.myPlayer.position,
                z = live[1].position - g.myPlayer.position;
            if (ArietEscortTactics.difference(
                  math.atan2(a.y, a.x),
                  math.atan2(z.y, z.x),
                ).abs() >
                .9) {
              distinctAngles++;
            }
            for (final e in live) {
              (movingRoles[e.escortId] ??= {}).add(
                b.escortTactics.roleFor(e.escortId),
              );
            }
          }
          movingShooters.addAll(
            b.fight.rounds.where((r) => r.owner != 0).map((r) => r.owner),
          );
          expect(b.fight.playerVelocity.distance, greaterThan(200));
          if (i % 8 == 0 || i % 8 == 3 || i % 8 == 5) await frame();
        }
        g.movementJoystick.delta.setZero();
        g.setTrainingDamage(false);
        expect(
          movingHits,
          greaterThan(0),
          reason: 'real straight escort rounds reach a moving survivor',
        );
        File('build/ariet-fight/escort-metrics.json').writeAsStringSync(
          jsonEncode({
            'seconds': 12,
            'samples': 480,
            'differentAngleSamples': distinctAngles,
            'rounds': b.fight.totalEscort - beforeMoving,
            'acceptedHits': movingHits,
            'scale': ArietEscort.rigScale,
            'worldSpeedLimit': 385,
            'roles': {
              for (final entry in movingRoles.entries)
                entry.key.toString(): entry.value.map((r) => r.name).toList(),
            },
          }),
        );
        expect(b.fight.totalEscort - beforeMoving, greaterThanOrEqualTo(12));
        expect(movingShooters, containsAll([1, 2]));
        expect(
          distinctAngles,
          greaterThan(100),
          reason: 'real moving pair must not stay single-file',
        );
        expect(
          movingRoles.values.any((r) => r.contains(ArietEscortRole.pressure)),
          isTrue,
        );
        expect(
          movingRoles.values.any((r) => r.contains(ArietEscortRole.intercept)),
          isTrue,
        );
        b.fight.grace = .7;
        b.fight.paused = false;
        // Actual rear-mounted cannon fire must lower native Training health.
        // No injected projectile substitutes for the old rear blind-spot bug.
        await advance(g, 2.1);
        g.setTrainingDamage(true);
        g.gameNotifier.resetHealth();
        b.fight.rounds.clear();
        b.rig.position = Offset.zero;
        b.rig.yaw = b.rig.desiredYaw = 0;
        b.position.setZero();
        b.fight.phase = ArietPhase.cannonLock;
        b.fight.clock = 0;
        g.myPlayer.position.setValues(-450, 0);
        final before = g.gameState.health;
        for (var i = 0; i < 360 && g.gameState.health == before; i++) {
          await advance(g, 1 / 120);
        }
        expect(
          g.gameState.health,
          lessThan(before),
          reason: 'rear cannon reaches and damages the survivor after lock and flight',
        );
        expect(b.fight.totalCannon, greaterThan(0));
        // Shootable seeker is an actual native weapon target, without rewards.
        final seeker = ArietRound(
          g.myPlayer.position.toOffset() + const Offset(150, 0),
          0,
          seeker: true,
        );
        b.fight.rounds.add(seeker);
        final rocket = b.rocketTargets.single;
        expect(g.projectileTargets, contains(rocket));
        final shot = BulletComponent(
          position: Vector2(seeker.position.dx - 40, seeker.position.dy),
          direction: Vector2(1, 0),
          speed: 1200,
          maxTravelDistance: 300,
          weapon: WeaponType.carbine,
        );
        g.addProjectile(shot);
        await g.ready();
        await advance(g, .15);
        expect(seeker.removed, isTrue);
        expect(g.hitEnemy(rocket, 1), isFalse);
        expect(b.fight.rounds.contains(seeker), isFalse);
        expect(g.gameState.kills, 0);
        b.fight.rounds.clear();
        b.fight.phase = ArietPhase.recovery;
        b.fight.paused = true;
        await advance(g, .6);
        g.damagePlayer(amount: 99, cause: 'Ariet recovery regression');
        expect(g.playerEntrance.active, isTrue);
        final frozen = b.fight.elapsed;
        g.update(.2);
        expect(b.fight.elapsed, frozen);
        for (var i = 0; i < 200 && g.playerEntrance.active; i++) {
          g.update(.05);
          await g.ready();
        }
        expect(g.gameState.health, g.gameState.maxHealth);
        expect(g.gameState.gameplayState, GameplayState.playing);
        expect(b.combatHealth.current, 79);
        g.setTrainingDamage(false);
        b.fight.paused = false;
        await advance(g, .1);
        final kills = g.gameState.kills, level = g.gameState.currentLevel;
        b.takeDamage(1000);
        expect(b.fight.defeated, isTrue);
        expect(b.fight.rounds, isEmpty);
        if (encoder == null) {
          await advance(g, 5);
        } else {
          for (var i = 0; i < 75; i++) {
            g.update(1 / 15);
            await g.ready();
            await frame();
          }
          await encoder.stdin.close();
          expect(await encoder.exitCode, 0, reason: await captureErrors);
        }
        expect(b.fight.finished, isTrue);
        expect(b.assets.disposed, isTrue);
        expect(g.world.children.whereType<ArietEscort>(), isEmpty);
        expect(g.gameState.kills, kills);
        expect(g.gameState.currentLevel, level);
        g.practiceAriet();
        final replacement = await ready(g);
        expect(identical(b, replacement), isFalse);
        await () async {
          final b = replacement;
          b.fight.paused = true;
          b.fight.phase = ArietPhase.recovery;
          for (final weapon in WeaponType.values) {
            g.pauseGame();
            g.preferences.profile.challenges.addAll(['training', weapon.name]);
            g.preferences.profile.ownedWeapons.add(weapon.name);
            expect(await g.changeTrainingWeapon(weapon), isTrue);
            g.gameNotifier.playGame();
            g.pauseEngine();
            b.rig.position = Offset.zero;
            b.rig.yaw = b.rig.desiredYaw = 0;
            b.position.setZero();
            b.combatHealth.current = 160;
            b.burnRemaining = b.cinderRemaining = 0;
            g.myPlayer.position.setValues(-300, b.rig.bodyPosition.dy);
            b.fight.rounds.clear();
            await advance(g, weapon.firesOnRelease ? .4 : 1.1, held: true);
            if (weapon.firesOnRelease) {
              g.arsenal!.releaseAim(Vector2(.5, 0));
            }
            g.weaponJoystick.delta.setZero();
            await advance(g, 2.0);
            expect(
              b.combatHealth.current,
              lessThan(160),
              reason: '${weapon.name} must hit the actual hull',
            );
            expect(
              b.assets.decodedBytes + RegunArt.shared.decodedBytes,
              lessThan(32 * 1024 * 1024),
              reason: weapon.name,
            );
          }
          g.pauseGame();
          g.preferences.profile.challenges.add('training');
          await g.changeTrainingWeapon(WeaponType.carbine);
          g.gameNotifier.playGame();
          g.pauseEngine();
          b.combatHealth.current = 160;
          b.burnRemaining = b.cinderRemaining = 0;
          g.arsenal!.clearField();
          for (final p
              in g.world.children.whereType<BulletComponent>().toList()) {
            p.removeFromParent();
          }
          await g.ready();
          final gap = b.rig.air(const Offset(50, 94));
          final shot = BulletComponent(
            position: Vector2(gap.dx, gap.dy),
            direction: Vector2(1, 0),
            maxTravelDistance: 28,
            bulletRadius: 2,
            damage: 1,
          );
          g.addProjectile(shot);
          await g.ready();
          await advance(g, .2);
          expect(
            b.combatHealth.current,
            160,
            reason: 'the genuine pod/hull gap must stay empty',
          );
          g.explode(Vector2.zero(), radius: 500, damage: 3);
          expect(
            b.combatHealth.current,
            157,
            reason: 'overlapping machinery takes one blast',
          );
          await advance(g, .4);
          final dir = Directory('build/ariet-fight')
            ..createSync(recursive: true);
          final rec = ui.PictureRecorder();
          g.render(Canvas(rec));
          final pic = rec.endRecording(), im = await pic.toImage(844, 390);
          final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
          File('${dir.path}/native.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          im.dispose();
          pic.dispose();
        }();
        g.practiceWalker();
        expect(replacement.retired, isTrue);
        expect(g.arietCandidate, isNull);
        expect(g.walkerTrial, isTrue);
        expect(g.encounterCameraZoom, .80);
        g.practiceAriet();
        final pending = g.arietCandidate!;
        g.restartGame();
        await ready(g);
        expect(pending.retired, isTrue);
        expect(g.arietTrial, isTrue);
      });
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
