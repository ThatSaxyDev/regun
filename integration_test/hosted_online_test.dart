// Deliberately opt-in: creator-authorized hosted playtest, isolated fresh guests
// and private rooms only. Never use this as an unattended production soak.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:regun/models/control_layout.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/presentation/control_art.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/online_view.dart';
import 'package:spacetimedb/spacetimedb.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  Future<void> warmSupply() async {}
}

Future<void> until(
  bool Function() condition,
  String label, {
  int seconds = 15,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) throw StateError('Timed out: $label');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> settle() =>
    Future<void>.delayed(const Duration(milliseconds: 900));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'authorized hosted lobby, predicted touch, combat controls and reconnect',
    (tester) async {
      if (const bool.fromEnvironment('REGUN_HOSTED_PLAYTEST')) {
        expect(OnlineSession.host, 'regunserver.kiishi.space');
        expect(OnlineSession.database, 'regun');
      } else {
        expect(
          const bool.fromEnvironment('REGUN_LOCAL_LATENCY_PLAYTEST'),
          isTrue,
        );
        expect(OnlineSession.host.startsWith('127.0.0.1:'), isTrue);
        expect(OnlineSession.database, 'regun-dev');
      }
      const weapon = String.fromEnvironment(
        'REGUN_TEST_WEAPON',
        defaultValue: 'carbine',
      );
      final host = OnlineSession(tokens: InMemoryTokenStore());
      final peer = OnlineSession(tokens: InMemoryTokenStore());
      final report = <String, Object?>{
        'status': 'started',
        'endpoint': OnlineSession.host,
        'checks': <String>[],
      };
      final checks = report['checks']! as List<String>;
      const prefix = String.fromEnvironment(
        'REGUN_TEST_DEVICE',
        defaultValue: 'simulator',
      );
      Future<void> save() async {
        final folder = (await getApplicationDocumentsDirectory()).path;
        await File('$folder/hosted-online-report.json')
            .writeAsString(jsonEncode(report), flush: true);
        // Safe scalar measurements only; no identity tokens or invitation codes.
        debugPrint('REGUN_HOSTED_REPORT ${jsonEncode(report)}');
        debugPrint(
          'REGUN_PROJECTILE_REPORT ${jsonEncode({
            for (final key in ['status', 'endpoint', 'weapon', 'firstVisualBulletMs', 'firstConfirmedShotMs', 'matchedProjectiles', 'maxSpeculativeBullets', 'continuousPeerFrames', 'duplicateVisualKeys', 'roomCleanup', 'failure'])
              if (report.containsKey(key)) key: report[key],
          })}',
        );
      }

      addTearDown(() async {
        for (final session in [peer, host]) {
          try {
            if (session.connected && session.room != null) {
              await session.leave();
            }
          } finally {
            await session.close();
          }
        }
      });
      OnlineSession.prepareAssets = () => RegunArt.shared.load();
      await tester.runAsync(() async {
        try {
          final clock = Stopwatch()..start();
          await host.connect();
          await peer.connect();
          report['connectMs'] = clock.elapsedMilliseconds;
          report['weapon'] = weapon;
          expect(
            host.connected && peer.connected,
            isTrue,
            reason: '${host.error} ${peer.error}',
          );
          expect(host.predictionAvailable && peer.predictionAvailable, isTrue);
          checks.add('fresh-native-guests-and-prediction-capabilities');
          await host.create(
            name: 'QA ${prefix.substring(0, math.min(prefix.length, 10))} host',
            mode: 'versus',
            teamSize: 1,
            map: 'ossuary_cross_1v1',
          );
          expect(host.error, isEmpty, reason: 'create: ${host.status}');
          await until(() => host.room != null, 'create private room');
          await peer.join(
            host.room!.code,
            'QA ${prefix.substring(0, math.min(prefix.length, 10))} peer',
          );
          await until(
            () =>
                host.members.length == 2 &&
                peer.members.length == 2 &&
                host.gun?.enabled == true &&
                peer.gun?.enabled == true,
            'both rosters and loadouts',
          );
          await host.enemies(false);
          await until(
            () => host.room?.enemies == false && peer.room?.enemies == false,
            'host options replicate',
          );
          await host.chooseLoadout(weapon, 'rook');
          await peer.chooseLoadout('revolver', 'rook');
          await until(
            () => host.gun?.weapon == weapon && peer.gun?.weapon == 'revolver',
            'loadout choices replicate',
          );
          expect(host.canStart, isFalse);
          await host.ready();
          await peer.ready();
          await until(() => host.canStart, 'ready');
          // Any kit change clears both Ready flags. This must be visible to both clients.
          await peer.chooseLoadout('shotgun', 'rook');
          await until(
            () =>
                host.members.every((m) => !m.ready) &&
                peer.members.every((m) => !m.ready),
            'loadout clears readiness',
          );
          expect(host.canStart, isFalse);
          await host.ready();
          await peer.ready();
          await until(() => host.canStart, 'ready again');
          checks.add('room-rosters-options-loadouts-readiness');
          await host.start();
          await until(
            () => host.controlsEnabled && peer.controlsEnabled,
            'match active',
          );
          await until(
            () =>
                host.predictedPosition != null &&
                host.movementPrediction.acknowledged > 0,
            'first simulation acknowledgement',
          );
        } catch (error) {
          report['status'] = 'failed';
          report['failure'] = error.toString();
          await save();
          rethrow;
        }
      });
      LocalPreferences.shared.controls = const ControlLayout();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: MaterialApp(
            home: RepaintBoundary(
              key: const Key('hosted-capture'),
              child: OnlineView(session: host),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final sticks = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OnlineStickSkin,
      );
      expect(sticks, findsNWidgets(2));
      final origin = host.predictedPosition!;
      final response = Stopwatch()..start();
      final touch = await tester.startGesture(tester.getCenter(sticks.first));
      await touch.moveBy(const Offset(0, 30));
      await tester.runAsync(() async {
        try {
          int? localMs, authorityMs;
          await until(() {
            if (host.predictedPosition!.dy > origin.dy + 2) {
              localMs ??= response.elapsedMilliseconds;
            }
            if (host.me!.y > origin.dy + 2) {
              authorityMs ??= response.elapsedMilliseconds;
            }
            return localMs != null && authorityMs != null;
          }, 'local and authoritative touch response');
          report['localFirstMoveMs'] = localMs;
          report['serverFirstMoveMs'] = authorityMs;
          expect(localMs!, lessThan(120));
          expect(localMs!, lessThan(authorityMs!));
          checks.add('touch-movement-before-server-echo');
        } catch (error) {
          report['status'] = 'failed';
          report['failure'] = error.toString();
          await save();
          rethrow;
        }
      });
      await touch.up();
      await tester.runAsync(() async {
        try {
          await settle();
          double error() =>
              (host.predictedPosition! - Offset(host.me!.x, host.me!.y))
                  .distance;
          report['stoppedError'] = error();
          expect(error(), lessThan(12));
          final replicated = peer.members.firstWhere(
            (m) => m.identity.toHexString == host.identity,
          );
          expect(
            (Offset(replicated.x, replicated.y) -
                    Offset(host.me!.x, host.me!.y))
                .distance,
            lessThan(1),
          );
          checks.add('stop-convergence-and-peer-position');
          final dashSeq = host.me!.dashSeq;
          host.moveY = 1;
          host.dash();
          await until(() => host.predictedDashRemaining > 0, 'local dash');
          await until(() => host.me!.dashSeq > dashSeq, 'server dash');
          host.neutral();
          await settle();
          expect(error(), lessThan(12));
          checks.add('dash-confirmation-and-convergence');
          // A local volley must be visible before its authoritative echo.
          expect(host.projectilePredictionAvailable, isTrue);
          final shots = host.gun!.shots;
          final firedAt = Stopwatch()..start();
          int? visualMs, confirmedMs;
          var maxSpeculative = 0;
          final beforeMatches = host.projectilePresentation.matched;
          host.aimX = -1;
          host.aimY = 0;
          host.firing = true;
          await until(() {
            final shown = host.presentedProjectiles();
            maxSpeculative = math.max(
              maxSpeculative,
              host.projectilePresentation.speculativeCount,
            );
            if (shown.any((r) => r.id.startsWith('local:'))) {
              visualMs ??= firedAt.elapsedMilliseconds;
            }
            if (host.gun!.shots > shots) {
              confirmedMs ??= firedAt.elapsedMilliseconds;
            }
            return visualMs != null &&
                confirmedMs != null &&
                host.gun!.ammo < host.gun!.capacity;
          }, 'predicted volley and server firing');
          report['firstVisualBulletMs'] = visualMs;
          report['firstConfirmedShotMs'] = confirmedMs;
          report['maxSpeculativeBullets'] = maxSpeculative;
          expect(visualMs, lessThan(100));
          expect(visualMs, lessThan(confirmedMs!));
          await until(
            () => host.projectilePresentation.matched > beforeMatches,
            'shot burst and pellet matched',
          );
          report['matchedProjectiles'] =
              host.projectilePresentation.matched - beforeMatches;
          checks.add(
            'predicted-bullets-before-echo-with-single-matched-confirmation',
          );
          var continuousPeerFrames = 0, duplicateKeys = 0;
          final previousPeer = <String, (double, double)>{};
          final heldUntil = Stopwatch()..start();
          while (heldUntil.elapsedMilliseconds < 1000) {
            await Future<void>.delayed(const Duration(milliseconds: 16));
            final shown = host.presentedProjectiles();
            final keys = shown
                .map(
                  (r) =>
                      '${r.owner}:${r.data['burst']}:${r.data['burstShot']}:${r.data['pellet']}',
                )
                .toList();
            duplicateKeys += keys.length - keys.toSet().length;
            final peerShown = peer.presentedProjectiles();
            for (final visual in peerShown) {
              final raw = peer.projectiles
                  .where((r) => r.id == visual.id)
                  .firstOrNull;
              if (raw == null) continue;
              final old = previousPeer[visual.id];
              if (old != null &&
                  raw.x == old.$1 &&
                  (visual.x - old.$2).abs() > .01) {
                continuousPeerFrames++;
              }
              previousPeer[visual.id] = (raw.x, visual.x);
            }
            maxSpeculative = math.max(
              maxSpeculative,
              host.projectilePresentation.speculativeCount,
            );
          }
          report['continuousPeerFrames'] = continuousPeerFrames;
          report['duplicateVisualKeys'] = duplicateKeys;
          report['matchedProjectiles'] =
              host.projectilePresentation.matched - beforeMatches;
          report['maxSpeculativeBullets'] = maxSpeculative;
          expect(duplicateKeys, 0);
          expect(continuousPeerFrames, greaterThan(0));
          checks.add(
            'held-fire-continuous-peer-travel-without-duplicate-rounds',
          );
          final releasedAt = Stopwatch()..start();
          host.neutral();
          await until(() => !host.gun!.aiming, 'authoritative fire release');
          report['fireReleaseConfirmedMs'] = releasedAt.elapsedMilliseconds;
          report['serverInputAgeMs'] = host.movementPrediction.inputAgeMs;
          report['serverTickIntervalMs'] =
              host.movementPrediction.tickIntervalMs;
          host.reload();
          await until(() => host.gun!.reloading, 'manual reload');
          await until(
            () => !host.gun!.reloading && host.gun!.ammo == host.gun!.capacity,
            'reload completion',
          );
          checks.add('authoritative-fire-and-manual-reload');
          final grenades = host.gun!.grenadeCharges;
          host.throwGrenade(aim: const Offset(-1, 0), power: .4);
          await until(
            () => host.gun!.grenadeCharges == grenades - 1,
            'grenade inventory',
          );
          checks.add('independent-grenade-intent-and-inventory');
          // Sustain movement/reversals long enough to reveal queue drift.
          var maxPending = 0, maxError = 0.0, stalls = 0;
          final samples = <double>[];
          final directions = [
            const Offset(0, -1),
            const Offset(0, 1),
            const Offset(-1, 0),
            const Offset(1, 0),
          ];
          for (var i = 0; i < 48; i++) {
            final direction = directions[(i ~/ 3) % directions.length];
            host.moveX = direction.dx;
            host.moveY = direction.dy;
            peer.moveY = i.isEven ? -.2 : .2;
            await Future<void>.delayed(const Duration(milliseconds: 250));
            expect(
              host.connected && peer.connected && host.controlsEnabled,
              isTrue,
            );
            maxPending = math.max(
              maxPending,
              host.movementPrediction.pendingCount,
            );
            if (host.movementPrediction.stalled) stalls++;
            final e = error();
            samples.add(e);
            maxError = math.max(maxError, e);
          }
          host.neutral();
          peer.neutral();
          await settle();
          report['sustainedSeconds'] = 12;
          report['maxPendingCommands'] = maxPending;
          report['stalledSamples'] = stalls;
          report['maxPredictionLead'] = maxError;
          report['meanPredictionLead'] =
              samples.reduce((a, b) => a + b) / samples.length;
          report['afterReversalsError'] = error();
          expect(maxPending, lessThan(12));
          expect(stalls, 0);
          expect(error(), lessThan(12));
          checks.add('sustained-reversals-without-queue-stall');
          // Local pause is not a shared pause. Stop must reach the server.
          host.menuOpen = true;
          await settle();
          final stopped = Offset(host.me!.x, host.me!.y);
          await Future<void>.delayed(const Duration(milliseconds: 300));
          expect(
            (Offset(host.me!.x, host.me!.y) - stopped).distance,
            lessThan(.01),
          );
          expect(host.predictedPosition, isNull);
          expect(host.projectilePresentation.speculativeCount, 0);
          host.menuOpen = false;
          await until(() => host.predictedPosition != null, 'menu resume');
          checks.add('menu-stop-and-resume');
          final identity = host.identity, generation = host.me!.generation;
          await host.suspend();
          await host.resume();
          await until(
            () =>
                host.controlsEnabled &&
                host.me!.generation > generation &&
                host.movementPrediction.acknowledged > 0,
            'reconnect epoch',
          );
          expect(host.identity, identity);
          expect(host.moveX, 0);
          expect(host.moveY, 0);
          report['hostRttMs'] = host.me!.pingMs;
          report['peerRttMs'] = peer.me!.pingMs;
          expect(host.error, isEmpty);
          expect(peer.error, isEmpty);
          checks.add('same-guest-reconnect-and-cleared-input');
          report['status'] = 'passed';
          await save();
        } catch (error) {
          report['status'] = 'failed';
          report['failure'] = error.toString();
          await save();
          rethrow;
        }
      });
      await tester.pump(const Duration(milliseconds: 100));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('hosted-capture')),
      );
      expect(boundary.debugNeedsPaint, isFalse);
      await binding.takeScreenshot('hosted-online-$prefix');
      // Leave these isolated rooms before disposing either client.
      await tester.runAsync(() async {
        await peer.leave();
        await host.leave();
        await until(
          () => host.room == null && peer.room == null,
          'room cleanup',
        );
        report['roomCleanup'] = true;
        await save();
      });
      await tester.pumpWidget(const SizedBox());
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
