import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/game.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/mummy_walk.dart';
import 'package:regun/presentation/regun_art.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String sound) async {}
  @override
  Future<void> playMusic(String sound) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool value) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('distance gait holds at walls and keeps phase through turns, pauses and relocation', () {
    final walk = MummyWalk();
    walk.follow(ui.Offset.zero, walking: true);
    walk.follow(const ui.Offset(27, 0), walking: true);
    expect(walk.frame, 3);
    for (var n = 0; n < 100; n++) {
      walk.follow(const ui.Offset(27, 0), walking: true);
    }
    expect(walk.frame, 3);
    walk.follow(const ui.Offset(18, 0), walking: true);
    expect(walk.frame, 4);
    expect(walk.left, isTrue);
    walk.follow(const ui.Offset(18.01, 5), walking: true);
    expect(walk.left, isTrue);
    walk.follow(const ui.Offset(20, 5), walking: false);
    expect(walk.frame, 4);
    walk.follow(const ui.Offset(900, 5), walking: true);
    expect(walk.frame, 4);
  });
  testWidgets(
    'live Mummy uses distance frames, mirrors turns and retains attack cadence',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      late RegunGame game;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
            child: const MaterialApp(
              home: BaseView(loadout: Loadout(training: true)),
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
        game.myPlayer.position.setZero();
        final enemy = Enemy2Component(position: Vector2(250, 0));
        await game.world.add(enemy);
        await game.ready();
        final frames = <int>{};
        for (var n = 0; n < 10; n++) {
          enemy.update(.1);
          frames.add(enemy.animationTicker!.currentIndex);
        }
        expect(frames.length, greaterThanOrEqualTo(6));
        expect(enemy.isFlippedHorizontally, isTrue);
        expect(enemy.animation!.frames.length, 8);
        final distance = enemy.walk.distance;
        game.myPlayer.position.setValues(500, 0);
        enemy.update(.1);
        expect(enemy.isFlippedHorizontally, isFalse);
        expect(enemy.walk.distance, isNot(distance));
        game.myPlayer.position.setFrom(enemy.position + Vector2(20, 0));
        enemy.update(.3);
        expect(enemy.isAttacking, isTrue);
        expect(enemy.timeSinceLastAttack, closeTo(.3, .0001));
        enemy.update(.3);
        expect(enemy.timeSinceLastAttack, 0);
        expect(enemy.attackInterval, .6);
        expect(enemy.animation!.frames.length, 2);
        await tester.pumpWidget(const SizedBox());
      });
      expect(tester.takeException(), isNull);
    },
  );

  test('render all eight grounded walk poses in both directions using actual game sprites', () async {
    await RegunArt.shared.load();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xff252726), ui.BlendMode.src);
    for (var row = 0; row < 2; row++) {
      for (var frame = 0; frame < 8; frame++) {
        canvas.save();
        canvas.translate(frame * 120.0, row * 140.0);
        if (row == 1) {
          canvas.translate(120, 0);
          canvas.scale(-1, 1);
        }
        RegunArt.shared
            .sprite('enemies/mummy_walk', frame)
            .render(canvas, size: Vector2.all(120));
        canvas.restore();
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(960, 280);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/test-previews').create(recursive: true);
    await File('build/test-previews/mummy-walk-both-directions.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
    if (const bool.fromEnvironment('REGUN_MUMMY_VIDEO')) {
      await renderMummyMotion();
    }
  });
}

Future<void> renderMummyMotion() async {
  final directory = Directory('build/test-previews/mummy-walk-motion');
  await directory.create(recursive: true);
  final walks = [MummyWalk(), MummyWalk()];
  for (var frame = 0; frame < 96; frame++) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xff252726), ui.BlendMode.src);
    final travel = frame / 60 * 90;
    for (var row = 0; row < 2; row++) {
      walks[row].follow(
        ui.Offset(row == 0 ? travel : -travel, 0),
        walking: true,
      );
      final x = row == 0 ? 220 + travel * 2 : 560 - travel * 2;
      final y = row * 180.0;
      canvas.drawLine(
        ui.Offset(0, y + 158),
        ui.Offset(960, y + 158),
        ui.Paint()
          ..color = const ui.Color(0xff363b36)
          ..strokeWidth = 1,
      );
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: ui.Offset(x + 90, y + 158),
          width: 70,
          height: 10,
        ),
        ui.Paint()..color = const ui.Color(0x55000000),
      );
      canvas.save();
      canvas.translate(x, y);
      if (row == 1) {
        canvas.translate(180, 0);
        canvas.scale(-1, 1);
      }
      RegunArt.shared
          .sprite('enemies/mummy_walk', walks[row].frame)
          .render(canvas, size: Vector2.all(180));
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(960, 360);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${directory.path}/${frame.toString().padLeft(3, '0')}.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  }
}
