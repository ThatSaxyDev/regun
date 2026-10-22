// Explicit, bounded hosted verification using fresh guests/private rooms.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:spacetimedb/spacetimedb.dart';

Future<void> until(bool Function() check, String label) async {
  final end = DateTime.now().add(const Duration(seconds: 15));
  while (!check()) {
    if (DateTime.now().isAfter(end)) throw StateError('Timed out: $label');
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    ('coop', 3, 'breach'),
    ('coop', 2, 'foundry'),
    ('versus', 4, 'ironworks_relay_2v2'),
    ('versus', 6, 'ossuary_cross_3v3'),
  ]) {
    if (const int.fromEnvironment('REGUN_PARTY_FILTER') != 0 &&
        scenario.$2 != const int.fromEnvironment('REGUN_PARTY_FILTER')) {
      continue;
    }
    testWidgets('hosted ${scenario.$1} ${scenario.$2} players ${scenario.$3}', (
      tester,
    ) async {
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
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Checking private online party…')),
          ),
        ),
      );
      await tester.runAsync(() async {
        final players = List.generate(
          scenario.$2,
          (_) => OnlineSession(tokens: InMemoryTokenStore()),
        );
        final host = players.first;
        final report = <String, Object?>{
          'status': 'started',
          'endpoint': OnlineSession.host,
          'mode': scenario.$1,
          'players': scenario.$2,
          'arena': scenario.$3,
        };
        Future<void> save() async {
          final folder = (await getApplicationDocumentsDirectory()).path;
          await File('$folder/hosted-${scenario.$3}-${scenario.$2}.json')
              .writeAsString(jsonEncode(report), flush: true);
          debugPrint('REGUN_PARTY_REPORT ${jsonEncode(report)}');
        }

        try {
          OnlineSession.prepareAssets = () => RegunArt.shared.load();
          for (final p in players) {
            await p.connect();
            expect(p.connected, isTrue, reason: p.error);
            expect(p.predictionAvailable, isTrue);
          }
          await host.create(
            name: 'QA party host',
            mode: scenario.$1,
            teamSize: scenario.$1 == 'coop' ? 0 : scenario.$2 ~/ 2,
            map: scenario.$3,
          );
          await until(() => host.room != null, 'create');
          for (var i = 1; i < players.length; i++) {
            await players[i].join(host.room!.code, 'QA party $i');
          }
          await until(
            () => players.every(
              (p) =>
                  p.members.length == players.length && p.gun?.enabled == true,
            ),
            'rosters and attachment',
          );
          if (scenario.$1 == 'versus') {
            await host.enemies(false);
            await until(
              () => players.every((p) => p.room?.enemies == false),
              'enemy setting',
            );
          }
          final weapons = ['shotgun', 'carbine', 'revolver', 'arcCaster'];
          for (var i = 0; i < players.length; i++) {
            await players[i].chooseLoadout(
              weapons[i % 4],
              scenario.$1 == 'coop'
                  ? ['rook', 'scrapper', 'warden'][i % 3]
                  : 'rook',
            );
          }
          await until(
            () => players.every((p) => !p.members.any((m) => m.ready)),
            'loadout readiness reset',
          );
          for (final p in players) {
            await p.ready();
          }
          await until(() => host.canStart, 'all ready');
          await host.start();
          await until(
            () => players.every((p) => p.controlsEnabled),
            'all active',
          );
          await until(
            () => players.every(
              (p) =>
                  p.predictedPosition != null &&
                  p.movementPrediction.acknowledged > 0,
            ),
            'all acknowledgements',
          );
          var maxPending = 0, stalls = 0, samples = 0, maxServerQueued = 0;
          var minRate = 1.0, maxAckSilence = 0.0;
          final inputAges = <double>[], tickIntervals = <double>[];
          var maxRemoteExtrapolationMs = 0.0;
          double percentile(List<double> values, double fraction) {
            final sorted = values.toList()..sort();
            return sorted[(fraction * (sorted.length - 1)).round()];
          }

          // Co-op stays short to avoid turning this into a balance/boss soak.
          final iterations = scenario.$1 == 'coop' ? 16 : 40;
          final initial = [for (final p in players) Offset(p.me!.x, p.me!.y)];
          for (var step = 0; step < iterations; step++) {
            for (var i = 0; i < players.length; i++) {
              final p = players[i];
              // Move out from the squad spawn, then reverse at bounded intervals.
              final sign = (step ~/ 4).isEven ? 1.0 : -1.0;
              p.moveX = i.isEven ? -.5 * sign : .5 * sign;
              p.moveY = i % 3 == 0 ? -.5 * sign : .5 * sign;
            }
            await Future<void>.delayed(const Duration(milliseconds: 250));
            for (final p in players) {
              expect(
                p.connected && p.controlsEnabled,
                isTrue,
                reason: '${p.status}: ${p.error}',
              );
              maxPending = math.max(
                maxPending,
                p.movementPrediction.pendingCount,
              );
              if (p.movementPrediction.stalled) stalls++;
              maxServerQueued = math.max(
                maxServerQueued,
                p.movementPrediction.serverQueued,
              );
              minRate = math.min(minRate, p.movementPrediction.simulationRate);
              maxAckSilence = math.max(
                maxAckSilence,
                p.movementPrediction.acknowledgementAge,
              );
              inputAges.add(p.movementPrediction.inputAgeMs);
              tickIntervals.add(p.movementPrediction.tickIntervalMs);
              expect(p.movementPrediction.timingAvailable, isTrue);
              for (final member in p.members) {
                if (member.identity.toHexString == p.identity) continue;
                final displayed = p.remotePosition(member);
                expect(displayed.dx.isFinite && displayed.dy.isFinite, isTrue);
                final track = p.remoteMotion[member.identity.toHexString]!;
                maxRemoteExtrapolationMs = math.max(
                  maxRemoteExtrapolationMs,
                  track.extrapolatedSeconds * 1000,
                );
                expect(track.extrapolatedSeconds, lessThanOrEqualTo(.08));
              }
              samples++;
            }
          }
          for (final p in players) {
            p.neutral();
          }
          await Future<void>.delayed(const Duration(milliseconds: 1000));
          final errors = [
            for (final p in players)
              (p.predictedPosition! - Offset(p.me!.x, p.me!.y)).distance,
          ];
          final maxError = errors.reduce(math.max);
          report['compactAcknowledgements'] = players.every(
            (p) => p.movementPrediction.compactAcknowledgements,
          );
          expect(report['compactAcknowledgements'], isTrue);
          report['inputAgeP50Ms'] = percentile(inputAges, .5);
          report['inputAgeP95Ms'] = percentile(inputAges, .95);
          report['maxInputAgeMs'] = inputAges.reduce(math.max);
          report['tickIntervalP50Ms'] = percentile(tickIntervals, .5);
          report['tickIntervalP95Ms'] = percentile(tickIntervals, .95);
          report['maxRemoteExtrapolationMs'] = maxRemoteExtrapolationMs;
          report['maxEventLoopGapMs'] = [
            for (final p in players) p.maxPredictionTimerGapMs,
          ];
          report['maxRefreshGapMs'] = [
            for (final p in players) p.maxRefreshGapMs,
          ];
          report['droppedCommands'] = [
            for (final p in players) p.movementPrediction.droppedCommands,
          ];
          report['activeSeconds'] = iterations / 4;
          report['maxPendingCommands'] = maxPending;
          report['stalledSamples'] = stalls;
          report['samples'] = samples;
          report['maxServerQueued'] = maxServerQueued;
          report['minimumSimulationRate'] = minRate;
          report['maxAckSilenceMs'] = (maxAckSilence * 1000).round();
          report['maxStoppedError'] = maxError;
          report['applicationRttMs'] = [for (final p in players) p.me!.pingMs];
          report['allPositionsFinite'] = players.every(
            (p) =>
                p.predictedPosition!.dx.isFinite &&
                p.predictedPosition!.dy.isFinite,
          );
          expect(stalls, 0);
          expect(maxPending, lessThan(12));
          expect(maxError, lessThan(12));
          // All clients agree on every fighter's authoritative resting position.
          for (final source in players) {
            for (final observer in players) {
              final member = observer.members.firstWhere(
                (m) => m.identity.toHexString == source.identity,
              );
              expect(
                (Offset(member.x, member.y) -
                        Offset(source.me!.x, source.me!.y))
                    .distance,
                lessThan(2),
              );
            }
          }
          report['initialPositions'] = [
            for (final p in initial) [p.dx, p.dy],
          ];
          report['rostersAgree'] = true;
          report['status'] = 'passed';
        } catch (error) {
          report['status'] = 'failed';
          report['failure'] = error.toString();
          report['clientStates'] = [
            for (final p in players)
              {
                'connected': p.connected,
                'status': p.status,
                'error': p.error,
                'members': p.members.length,
                'combatEnabled': p.gun?.enabled,
                'roomPresent': p.room != null,
              },
          ];
          rethrow;
        } finally {
          for (final p in players.reversed) {
            try {
              if (p.connected && p.room != null) await p.leave();
            } finally {
              await p.close();
            }
          }
          report['testClientsClosed'] = true;
          await save();
        }
      });
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
