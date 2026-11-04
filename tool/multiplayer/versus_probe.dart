// Manual diagnostic entrypoint. Install over the normal simulator app to reuse
// each signed-in test account and set regun-net-role in its Documents directory.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/account/account_controller.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/widgets/online_arena.dart';

class SilentAudio extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  Future<void> warmSupply() async {}
}

int now() => DateTime.now().microsecondsSinceEpoch;
Future<void> delay(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
Future<void> until(bool Function() done, String step, {int ms = 26000}) async {
  final elapsed = Stopwatch()..start();
  while (!done()) {
    if (elapsed.elapsedMilliseconds > ms) throw StateError(step);
    await delay(12);
  }
}

Future<String> rendezvous() async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, 41764);
  try {
    return await socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 3));
  } finally {
    socket.destroy();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('REGUN_HOSTED_VERSUS_PROBE')) {
    throw StateError('Hosted Versus probe requires explicit opt-in');
  }
  final dir = await getApplicationDocumentsDirectory();
  final role = await File('${dir.path}/regun-net-role').readAsString();
  if (role != 'host' && role != 'peer') throw StateError('Invalid probe role');
  final host = role == 'host';
  final session = OnlineSession();
  final tickTrace = <int, Map<String, int>>{};
  session.onTickTrace = (stage, tick, serverUs, clientUs) {
    final sample = tickTrace.putIfAbsent(tick, () => {'server': serverUs});
    sample.putIfAbsent(stage, () => clientUs);
  };
  final show = ValueNotifier(false);
  final report = <String, Object?>{'role': role};
  var stage = 'startup';
  ServerSocket? relay;
  OnlineSession.prepareAssets = RegunArt.shared.load;
  runApp(
    ProviderScope(
      overrides: [soloudPlayProvider.overrideWithValue(SilentAudio())],
      child: MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (_, visible, _) => visible
              ? OnlineArena(session: session)
              : const Scaffold(body: Center(child: Text('Regun network test'))),
        ),
      ),
    ),
  );
  try {
    if (OnlineSession.host != 'regunserver.kiishi.space' ||
        OnlineSession.database != 'regun' ||
        !OnlineSession.tls) {
      throw StateError('Unexpected endpoint');
    }
    stage = 'restore saved account';
    await LocalPreferences.shared.load();
    final account = AccountController.shared;
    await account.initialize();
    report['accountRestored'] = account.ready;
    if (!account.ready) throw StateError('Saved account unavailable');
    stage = 'connect';
    await session.connect();
    await until(() => session.connected, 'production connection');
    report['predictionAvailable'] = session.predictionAvailable;
    report['combatAvailable'] = session.combatAvailable;
    const map = String.fromEnvironment(
      'REGUN_HOSTED_PROBE_MAP',
      defaultValue: 'ossuary_cross_1v1',
    );
    final coop = const {'breach', 'foundry'}.contains(map);
    var startAt = 0;
    stage = 'private room';
    if (host) {
      await session.create(
        name: 'QA Sim Host',
        mode: coop ? 'coop' : 'versus',
        teamSize: coop ? 0 : 1,
        map: map,
      );
      await until(() => session.room != null, 'create room');
      report['arenaCompatible'] = session.compatible;
      report['arena'] = session.room?.mapId;
      report['roomGeometryHash'] = session.room?.geometryHash;
      report['createMessage'] = session.error;
      if (!session.compatible) throw StateError('Arena geometry mismatch');
      if (!coop) {
        await session.enemies(false);
        if (session.error.isNotEmpty) {
          throw StateError('Disable enemies failed');
        }
      }
      relay = await ServerSocket.bind(InternetAddress.loopbackIPv4, 41764);
      relay.listen((socket) async {
        socket.writeln('${session.room?.code ?? ''} $startAt');
        await socket.close();
      });
    } else {
      String? response;
      final elapsed = Stopwatch()..start();
      while (response == null && elapsed.elapsedMilliseconds < 30000) {
        try {
          response = await rendezvous();
        } on SocketException {
          await delay(150);
        }
      }
      if (response == null) throw StateError('Room rendezvous failed');
      await session.join(response.split(' ').first, 'QA Sim Peer');
      report['joinMessage'] = session.error;
      if (session.room == null) throw StateError('Join failed');
    }
    stage = 'ready and start';
    await until(
      () => session.members.length == 2 && session.gun?.enabled == true,
      'room roster',
    );
    await until(() => session.room?.enemies == coop, 'enemy setting');
    await session.ready();
    if (host) {
      await until(() => session.canStart, 'both ready');
      await session.start();
    }
    await until(
      () => session.controlsEnabled && session.predictedPosition != null,
      'active',
    );
    show.value = true;
    final other = session.members.firstWhere(
      (m) => m.identity.toHexString != session.identity,
    );
    final otherKey = other.identity.toHexString;
    stage = 'synchronize measurement';
    if (host) {
      startAt = now() + 3500000;
    } else {
      final sync = Stopwatch()..start();
      while (startAt == 0 && sync.elapsedMilliseconds < 8000) {
        final fields = (await rendezvous()).split(' ');
        startAt = int.parse(fields.last);
        if (startAt == 0) await delay(60);
      }
      if (startAt == 0) throw StateError('Missing shared start time');
    }
    final frames = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => frames.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(collect);
    final trials = <Map<String, Object?>>[];
    final gaps = <double>[], serverTicks = <double>[];
    int? lastUpdate;
    String? lastTick;
    var stalls = 0, activeSamples = 0, maxEnemies = 0;
    final observed = <Map<String, int>>[];
    var lastPoll = now();
    stage = 'play and measure';
    try {
      for (var i = 0; i < 8; i++) {
        final actorHost = i.isEven;
        final acting = actorHost == host;
        final at = startAt + i * 2250000;
        final shotAt = at + 1000000;
        await until(() => now() >= at, 'trial start');
        final member = acting
            ? session.me!
            : session.members.firstWhere(
                (m) => m.identity.toHexString == otherKey,
              );
        final key = acting ? session.identity! : otherKey;
        Offset? visual() => acting
            ? session.predictedPosition
            : session.remotePosition(
                session.members.firstWhere(
                  (m) => m.identity.toHexString == otherKey,
                ),
              );
        final visualStart = visual(),
            authorityStart = Offset(member.x, member.y);
        final shotCount = session.fighters[key]?.shots ?? 0;
        final existingRounds = session
            .presentedProjectiles()
            .where((p) => p.owner == key)
            .map((p) => p.id)
            .toSet();
        int? motionAt,
            authorityAt,
            confirmedShotAt,
            visibleShotAt,
            moveInputAt,
            fireInputAt;
        int? movementDispatchAt, movementSequence, fireDispatchAt, fireSequence;
        int? firstMotionAckAt;
        double? movementServerInputAgeMs;
        if (acting) {
          session.onMotionDispatch = (input) {
            if (moveInputAt != null &&
                input.movement.dy != 0 &&
                movementDispatchAt == null) {
              movementDispatchAt = now();
              movementSequence = input.seq;
            }
          };
          session.onCombatDispatch = (sequence, firing) {
            if (fireInputAt != null && firing && fireDispatchAt == null) {
              fireDispatchAt = now();
              fireSequence = sequence;
            }
          };
        }
        final direction = (i ~/ 2).isEven ? 1.0 : -1.0;
        if (acting && session.controlsEnabled) {
          moveInputAt = now();
          session.moveY = .7 * direction;
        }
        var stopped = false, triggered = false;
        while (now() < at + 2240000) {
          final sample = now();
          final pollGapUs = sample - lastPoll;
          lastPoll = sample;
          final sentSequence = movementSequence;
          if (sentSequence != null &&
              firstMotionAckAt == null &&
              session.movementPrediction.acknowledged >= sentSequence) {
            firstMotionAckAt = sample;
            if (session.movementPrediction.acknowledged == sentSequence &&
                session.movementPrediction.timingAvailable) {
              movementServerInputAgeMs = session.movementPrediction.inputAgeMs;
            }
          }
          if (session.controlsEnabled) {
            activeSamples++;
            if (session.movementPrediction.stalled) stalls++;
          }
          if (acting && !stopped && sample >= at + 450000) {
            session.moveY = 0;
            stopped = true;
          }
          if (acting &&
              !triggered &&
              sample >= shotAt &&
              session.controlsEnabled) {
            session.aimX = direction;
            session.aimY = 0;
            fireInputAt = now();
            session.firing = true;
            triggered = true;
          }
          if (acting && triggered && sample >= shotAt + 175000) {
            session.firing = false;
          }
          final p = visual();
          if (motionAt == null &&
              p != null &&
              visualStart != null &&
              (p - visualStart).distance > 6) {
            motionAt = sample;
          }
          final current = acting
              ? session.me!
              : session.members.firstWhere(
                  (m) => m.identity.toHexString == otherKey,
                );
          if (authorityAt == null &&
              (Offset(current.x, current.y) - authorityStart).distance > 6) {
            authorityAt = sample;
          }
          if (sample >= shotAt &&
              confirmedShotAt == null &&
              (session.fighters[key]?.shots ?? 0) > shotCount) {
            confirmedShotAt = sample;
          }
          if (sample >= shotAt &&
              visibleShotAt == null &&
              session.presentedProjectiles().any(
                (p) => p.owner == key && !existingRounds.contains(p.id),
              )) {
            visibleShotAt = sample;
          }
          final tick = session.room?.tick.toString();
          if (tick != lastTick) {
            if (lastUpdate != null) {
              gaps.add((sample - lastUpdate) / 1000);
            }
            lastUpdate = sample;
            lastTick = tick;
            if (tick != null) {
              observed.add({
                'tick': int.parse(tick),
                'observedUs': sample,
                'pollGapUs': pollGapUs,
              });
            }
            final dt = session.movementPrediction.tickIntervalMs;
            if (dt > 0) serverTicks.add(dt);
          }
          final enemies = session.scene.where((e) => e.kind == 'enemy').length;
          if (enemies > maxEnemies) maxEnemies = enemies;
          await delay(8);
        }
        session.neutral();
        session.onMotionDispatch = null;
        session.onCombatDispatch = null;
        trials.add({
          'trial': i,
          'acting': acting,
          'movementInputUs': moveInputAt,
          'fireInputUs': fireInputAt,
          'movementDispatchUs': movementDispatchAt,
          'movementSequence': movementSequence,
          'firstMotionAckUs': firstMotionAckAt,
          'fireDispatchUs': fireDispatchAt,
          'fireSequence': fireSequence,
          'motionUs': motionAt,
          'authorityMotionUs': authorityAt,
          'movementServerInputAgeMs': movementServerInputAgeMs,
          'confirmedShotUs': confirmedShotAt,
          'presentedShotUs': visibleShotAt,
        });
      }
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(collect);
    }
    double? p95(List<double> values) {
      if (values.isEmpty) return null;
      values.sort();
      return values[(values.length * .95).ceil() - 1];
    }

    report.addAll({
      'status': 'passed',
      'trials': trials,
      'observedTicks': observed,
      'tickTrace': [
        for (final entry in tickTrace.entries)
          {'tick': entry.key, ...entry.value},
      ],
      'rttMs': session.me?.pingMs,
      'updateGapP95Ms': p95(gaps),
      'updateGapMaxMs': gaps.lastOrNull,
      'updates': gaps.length,
      'serverTickP95Ms': p95(serverTicks),
      'activeSamples': activeSamples,
      'stalls': stalls,
      'frames': frames.length,
      'maxEnemies': maxEnemies,
      'frameRasterP95Ms': p95(
        frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList(),
      ),
    });
    if (host) await delay(1800);
  } catch (e) {
    report.addAll({
      'status': 'failed',
      'stage': stage,
      'reason': e is StateError ? e.message : e.runtimeType.toString(),
      'diagnostic': session.connectionDiagnostic,
      'message': session.error,
      'members': session.members.length,
      'compatible': session.compatible,
      'matchVersion': session.match?.version,
      'gunEnabled': session.gun?.enabled,
    });
  } finally {
    show.value = false;
    session.neutral();
    await relay?.close();
    try {
      if (session.connected && session.room != null) {
        await session.leave();
        if (session.error.isEmpty && session.room != null) {
          try {
            await until(
              () => session.room == null,
              'leave subscription',
              ms: 2000,
            );
          } on StateError {
            // Record the unconfirmed cleanup below.
          }
        }
        if (session.error.isNotEmpty) report['leaveError'] = session.error;
      }
      report['leftRoom'] = session.room == null;
    } finally {
      await session.close();
      await File('${dir.path}/regun-versus-result.json')
          .writeAsString(jsonEncode(report));
    }
  }
}
