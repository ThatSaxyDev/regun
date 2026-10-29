import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/lodestar_boss.dart';
import 'package:regun/systems/lodestar/lodestar_sections.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
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
  // This developer recording runs under flutter test with isolated preferences.
  // ignore: invalid_use_of_visible_for_testing_member
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
              loadout: Loadout(training: true, arena: ArenaType.foundry),
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

  Future<LodestarBoss> ready(RegunGame g) async {
    for (var i = 0; i < 100 && g.lodestarCandidate?.prepared != true; i++) {
      await activeTester!.pump(const Duration(milliseconds: 16));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      g.update(1 / 120);
    }
    await g.ready().timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        throw StateError(
          'ready trial=${g.mechanicalTrial} prepared=${g.lodestarCandidate?.prepared} mounted=${g.lodestarCandidate?.isMounted} loaded=${g.lodestarCandidate?.isLoaded} sheet=${g.lodestarCandidate?.assets.sheet != null} arsenal=${g.lodestarCandidate?.assets.arsenal != null} retired=${g.lodestarCandidate?.retired} entrance=${g.playerEntrance.active}',
        );
      },
    );
    expect(g.lodestarCandidate?.prepared, isTrue);
    g.pauseEngine();
    return g.lodestarCandidate!;
  }

  Future<void> advance(RegunGame g, double seconds, {bool held = false}) async {
    for (var t = 0.0; t < seconds - 1e-8; t += .025) {
      g.weaponJoystick.delta.setValues(held ? 70 : 0, 0);
      g.update((seconds - t).clamp(0, .025));
      await g.ready();
    }
  }

  testWidgets(
    'capture actual Training pressure, burrow and staged finish for review',
    (tester) async {
      final g = await mount(tester);
      Object? failure;
      await tester.runAsync(() async {
        try {
          g.practiceLodestar();
          final b = await ready(g);
          await advance(g, 4.2);
          final dir = Directory('build/lodestar-review')
            ..createSync(recursive: true);
          final encoder = await Process.start('ffmpeg', [
            '-y',
            '-loglevel',
            'error',
            '-f',
            'image2pipe',
            '-framerate',
            '30',
            '-i',
            'pipe:0',
            '-c:v',
            'libx264',
            '-preset',
            'fast',
            '-crf',
            '22',
            '-pix_fmt',
            'yuv420p',
            '-movflags',
            '+faststart',
            '${dir.path}/training-review.mp4',
          ]);
          final errors = encoder.stderr.transform(utf8.decoder).join();
          final output = encoder.stdout.drain<void>();
          var staged = false;
          for (var n = 0; n < 1050; n++) {
            final t = n / 30;
            if (t >= 18 &&
                !staged &&
                b.fight.depths.every((d) => d == 0) &&
                g.camera.visibleWorldRect
                    .deflate(50)
                    .contains(b.fight.rig.poses.first.position)) {
              for (final s in [
                LodestarSection.accelerator,
                LodestarSection.mortars,
                LodestarSection.head,
              ]) {
                b.receiveLocalDamage(
                  1000,
                  point: b.fight.rig.poses[s.index].position,
                );
              }
              staged = b.fight.defeated;
            }
            g.update(1 / 30);
            await g.ready();
            final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
            g.render(canvas);
            final pic = recorder.endRecording(),
                image = await pic.toImage(844, 390),
                bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            encoder.stdin.add(bytes!.buffer.asUint8List());
            await encoder.stdin.flush();
            image.dispose();
            pic.dispose();
            if (staged && b.fight.finished) break;
          }
          await encoder.stdin.close();
          final status = await encoder.exitCode;
          await output;
          expect(status, 0, reason: await errors);
          expect(staged, isTrue);
          File('build/lodestar-review/review.json').writeAsStringSync(
            jsonEncode({
              'capture': 'actual RegunGame renderer',
              'fps': 30,
              'player': 'stationary; protected Training',
              'finish': 'staged local hits after 18 seconds, when exposed head is visible',
              'notPhysicalPerformanceProof': true,
            }),
          );
        } catch (e, st) {
          failure = '$e\n$st';
        }
      });
      expect(failure, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
