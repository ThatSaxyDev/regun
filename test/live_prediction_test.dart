import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:spacetimedb/spacetimedb.dart';

Future<void> until(bool Function() condition, String label) async {
  final end = DateTime.now().add(const Duration(seconds: 12));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) throw StateError('Timed out: $label');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'live local prediction moves before server echo, converges, dashes and resets',
    () async {
      // This mutates disposable local rooms only, never the production service.
      expect(
        OnlineSession.host.split(':').first,
        anyOf('127.0.0.1', 'localhost'),
      );
      HttpOverrides.global = null;
      final a = OnlineSession(tokens: InMemoryTokenStore()),
          b = OnlineSession(tokens: InMemoryTokenStore());
      try {
        await a.connect();
        await b.connect();
        expect(
          a.connected && b.connected,
          isTrue,
          reason: '${a.error} ${b.error}',
        );
        expect(a.predictionAvailable && b.predictionAvailable, isTrue);
        await a.create(
          name: 'Prediction host',
          mode: 'versus',
          teamSize: 1,
          map: 'network_lab',
        );
        await until(() => a.room != null, 'create');
        await b.join(a.room!.code, 'Prediction peer');
        await until(() => a.members.length == 2, 'join');
        // create enables combat; let both capability attachments settle.
        await until(
          () => a.gun?.enabled == true && b.gun?.enabled == true,
          'attach',
        );
        await a.ready();
        await b.ready();
        await until(() => a.canStart, 'ready');
        await a.start();
        await until(() => a.controlsEnabled && b.controlsEnabled, 'active');
        await until(
          () =>
              a.predictedPosition != null &&
              a.movementPrediction.acknowledged > 0,
          'initial ack',
        );
        final original = Offset(a.me!.x, a.me!.y);
        final ack = a.movementPrediction.acknowledged;
        a.moveY = 1;
        var predictedBeforeEcho = false;
        final begin = DateTime.now();
        await until(() {
          final predicted = a.predictedPosition!;
          final actual = Offset(a.me!.x, a.me!.y);
          if (predicted.dy > original.dy + 2 && actual.dy < original.dy + 1) {
            predictedBeforeEcho = true;
          }
          return predicted.dy > original.dy + 45;
        }, 'local movement');
        expect(DateTime.now().difference(begin).inMilliseconds, lessThan(500));
        // With a delay proxy the first visual motion must precede its server echo.
        if (const bool.fromEnvironment('REGUN_DELAYED')) {
          expect(predictedBeforeEcho, isTrue);
        }
        await until(() => a.me!.y > original.dy + 60, 'server movement');
        a.neutral();
        await Future<void>.delayed(const Duration(milliseconds: 900));
        expect(
          (a.predictedPosition! - Offset(a.me!.x, a.me!.y)).distance,
          lessThan(12),
        );
        expect(a.movementPrediction.acknowledged, greaterThan(ack));
        expect(a.movementPrediction.pendingCount, lessThanOrEqualTo(12));
        final dashBefore = a.me!.dashSeq;
        a.moveY = 1;
        a.dash();
        await until(() => a.predictedDashRemaining > 0, 'local dash');
        await until(() => a.me!.dashSeq > dashBefore, 'server dash');
        a.neutral();
        a.menuOpen = true;
        await Future<void>.delayed(const Duration(milliseconds: 700));
        final stopped = Offset(a.me!.x, a.me!.y);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect((Offset(a.me!.x, a.me!.y) - stopped).distance, lessThan(.01));
        expect(a.predictedPosition, isNull);
        a.menuOpen = false;
        await until(() => a.predictedPosition != null, 'resume prediction');
        final identity = a.identity, generation = a.me!.generation;
        await a.suspend();
        await a.resume();
        await until(
          () =>
              a.me != null &&
              a.me!.generation > generation &&
              a.controlsEnabled,
          'reconnect',
        );
        expect(a.identity, identity);
        expect(a.moveX, 0);
        expect(a.moveY, 0);
        await until(
          () => a.movementPrediction.acknowledged > 0,
          'fresh epoch ack',
        );
        expect(a.error, isEmpty);
      } finally {
        await a.close();
        await b.close();
      }
    },
    skip: !const bool.fromEnvironment('REGUN_LIVE_PREDICTION'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
