import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

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

Future<void> until(bool Function() check, String label) async {
  final end = DateTime.now().add(const Duration(seconds: 15));
  while (!check()) {
    if (DateTime.now().isAfter(end)) throw StateError('Timed out: $label');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native sticks predict against delayed authoritative simulation and cancel on pause',
    (tester) async {
      expect(
        OnlineSession.host.split(':').first,
        anyOf('localhost', '127.0.0.1'),
      );
      final a = OnlineSession(tokens: InMemoryTokenStore()),
          b = OnlineSession(tokens: InMemoryTokenStore());
      await tester.runAsync(() async {
        OnlineSession.prepareAssets = () => RegunArt.shared.load();
        await a.connect();
        await b.connect();
        expect(
          a.connected && b.connected,
          isTrue,
          reason: '${a.error} ${b.error}',
        );
        expect(a.predictionAvailable, isTrue);
        await a.create(
          name: 'Native host',
          mode: 'versus',
          teamSize: 1,
          map: 'network_lab',
        );
        await until(() => a.room != null, 'room');
        await b.join(a.room!.code, 'Native peer');
        await until(
          () =>
              a.members.length == 2 &&
              a.gun?.enabled == true &&
              b.gun?.enabled == true,
          'attach',
        );
        await a.ready();
        await b.ready();
        await until(() => a.canStart, 'ready');
        await a.start();
        await until(() => a.controlsEnabled && b.controlsEnabled, 'active');
      });
      const captureKey = Key('native-prediction');
      LocalPreferences.shared.controls = const ControlLayout();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: MaterialApp(
            home: RepaintBoundary(
              key: captureKey,
              child: OnlineView(session: a),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final sticks = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OnlineStickSkin,
      );
      expect(sticks, findsNWidgets(2));
      final center = tester.getCenter(sticks.first),
          origin = a.predictedPosition!;
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(0, 26));
      var beforeEcho = false;
      await tester.runAsync(() async {
        await until(() {
          if (a.predictedPosition!.dy > origin.dy + 2 &&
              a.me!.y < origin.dy + 1) {
            beforeEcho = true;
          }
          return a.predictedPosition!.dy > origin.dy + 45;
        }, 'predicted touch movement');
      });
      expect(beforeEcho, isTrue);
      await gesture.up();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 700)),
      );
      expect(
        (a.predictedPosition! - Offset(a.me!.x, a.me!.y)).distance,
        lessThan(12),
      );
      a.dash();
      await tester.runAsync(
        () => until(() => a.predictedDashRemaining > 0, 'predicted dash'),
      );
      a.menuOpen = true;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      expect(a.predictedPosition, isNull);
      a.menuOpen = false;
      await tester.runAsync(
        () => until(() => a.predictedPosition != null, 'resume'),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await tester.runAsync(() async {
        final folder = (await getApplicationDocumentsDirectory()).path;
        await File('$folder/online-prediction-native.png')
            .writeAsBytes(png!.buffer.asUint8List());
        await File('$folder/online-prediction-native.json').writeAsString(
          jsonEncode({
            'status': 'passed',
            'earlyTouchMovement': beforeEcho,
            'ack': a.movementPrediction.acknowledged,
            'pending': a.movementPrediction.pendingCount,
            'host': OnlineSession.host,
          }),
        );
      });
      image.dispose();
      await binding.takeScreenshot('online-prediction-native');
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await a.close();
        await b.close();
      });
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
