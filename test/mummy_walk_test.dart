import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:regun/components/enemies/enemy_2_component.dart';
import 'package:regun/presentation/online_world.dart';
import 'package:regun/multiplayer/combat_state.dart';
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
    for (var n = 0; n < 9; n++) {
      walk.follow(const ui.Offset(18, 0), walking: true);
    }
    expect(walk.left, isTrue);
    walk.follow(const ui.Offset(18.01, 5), walking: true);
    expect(walk.left, isTrue);
    walk.follow(const ui.Offset(20, 5), walking: false);
    expect(walk.frame, 4);
    walk.follow(const ui.Offset(900, 5), walking: true);
    expect(walk.frame, 4);
  });
  test(
    'jitter cannot spin a blocked mummy, real target turns still settle',
    () {
      final walk = MummyWalk();
      walk.follow(ui.Offset.zero, walking: true, facingX: -200);
      var flips = 0;
      for (var i = 0; i < 600; i++) {
        final before = walk.left;
        walk.follow(
          ui.Offset(i.isEven ? .6 : 0, 0),
          walking: true,
          facingX: -200,
        );
        if (before != walk.left) flips++;
      }
      expect(flips, 0);
      expect(walk.blocked, true);
      final phase = walk.distance;
      for (var i = 0; i < 120; i++) {
        walk.follow(
          ui.Offset.zero,
          walking: true,
          facingX: i.isEven ? .02 : -.02,
        );
      }
      expect(walk.left, true);
      walk.follow(ui.Offset.zero, walking: true, facingX: 200, dt: .1);
      expect(walk.left, true);
      walk.follow(ui.Offset.zero, walking: true, facingX: 200, dt: .05);
      expect(walk.left, false);
      expect(walk.distance, phase);
      for (var i = 1; i <= 20; i++) {
        walk.follow(ui.Offset(i * 1.5, 0), walking: true, facingX: 200);
      }
      expect(walk.blocked, false);
      expect(walk.stanceScale(reducedMotion: true), 1);
    },
  );
  test(
    'snapshots freeze stance and facing clocks when authoritative age stops',
    () {
      final walk = MummyWalk();
      for (var i = 0; i < 30; i++) {
        walk.followSnapshot(
          ui.Offset.zero,
          age: i / 20,
          walking: true,
          facingX: -200,
        );
      }
      expect(walk.blocked, true);
      final clock = walk.clock, stance = walk.stanceScale(reducedMotion: false);
      for (var i = 0; i < 120; i++) {
        walk.followSnapshot(
          ui.Offset.zero,
          age: 29 / 20,
          walking: true,
          facingX: 200,
        );
      }
      expect(walk.clock, clock);
      expect(walk.left, true);
      expect(walk.stanceScale(reducedMotion: false), stance);
      expect(MummyWalk.attackFrame(0, hasStruck: false), 5);
      expect(MummyWalk.attackFrame(0, hasStruck: true), 6);
      expect(MummyWalk.attackFrame(.139, hasStruck: true), 6);
      expect(MummyWalk.attackFrame(.14, hasStruck: true), 5);
    },
  );
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
        expect(enemy.isFlippedHorizontally, isTrue);
        enemy.update(.05);
        expect(enemy.isFlippedHorizontally, isFalse);
        expect(enemy.walk.distance, isNot(distance));
        game.myPlayer.position.setFrom(enemy.position + Vector2(20, 0));
        enemy.update(.2);
        expect(enemy.isAttacking, isTrue);
        expect(enemy.timeSinceLastAttack, closeTo(.2, .0001));
        enemy.update(.1);
        expect(enemy.timeSinceLastAttack, 0);
        enemy.update(.3);
        expect(enemy.timeSinceLastAttack, closeTo(.3, .0001));
        enemy.update(.3);
        expect(enemy.timeSinceLastAttack, 0);
        expect(enemy.attackInterval, .6);
        expect(enemy.firstStrikeDelay, .3);
        expect(enemy.animation!.frames.length, 2);
        final planted = enemy.position.clone();
        final blockers = [
          for (final delta in [
            Vector2(101, 0),
            Vector2(-101, 0),
            Vector2(0, 101),
            Vector2(0, -101),
          ])
            PositionComponent(
              position: planted + delta,
              size: Vector2.all(116),
            ),
        ];
        for (final targetX in [planted.x - 300, planted.x + 300]) {
          game.myPlayer.position.setValues(targetX, planted.y);
          for (var i = 0; i < 30; i++) {
            game.enemyTactics.rebuild([enemy]);
            game.crowdOccupancy.rebuild([
              enemy,
              ...blockers,
            ], (a) => identical(a, enemy) ? 45 : 52);
            enemy.update(1 / 60);
          }
          expect(enemy.position.distanceTo(planted), lessThan(.001));
          expect(enemy.walk.blocked, true);
          expect(enemy.isFlippedHorizontally, targetX < planted.x);
          expect(enemy.animation, same(enemy.blockedAnimation));
        }
        await tester.pumpWidget(const SizedBox());
      });
      expect(tester.takeException(), isNull);
    },
  );

  test('actual blocked and attack sprites animate while Reduced Motion stays planted', () async {
    await RegunArt.shared.load();
    final walk = MummyWalk();
    walk.followSnapshot(ui.Offset.zero, age: 0, walking: true, facingX: -200);
    for (var i = 1; i <= 20; i++) {
      walk.followSnapshot(
        ui.Offset.zero,
        age: i / 20,
        walking: true,
        facingX: -200,
      );
    }
    Future<List<int>> render(
      double age, {
      bool reduced = false,
      bool attacking = false,
      double strike = -1,
      String? output,
    }) async {
      final recorder = ui.PictureRecorder();
      // Render the actual shared online/native material art at gameplay size.
      final c = ui.Canvas(recorder);
      c.drawRect(
        const ui.Rect.fromLTWH(0, 0, 160, 160),
        ui.Paint()..color = const ui.Color(0xff232A25),
      );
      OnlineWorldArt.enemy(
        c,
        OnlineEntity('mummy', 'enemy', {
          'key': 'mummy',
          'kind': 'mummy',
          'x': 80,
          'y': 80,
          'size': 100,
          'health': 6,
          'maximumHealth': 6,
          'phase': attacking ? 1 : 0,
          'age': age,
          'phaseTime': 0,
          'mummyStrikeAt': strike,
        }),
        foundry: false,
        reducedMotion: reduced,
        mummyWalk: walk,
      );
      final picture = recorder.endRecording(),
          image = await picture.toImage(160, 160);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (output != null) {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).writeAsBytes(png!.buffer.asUint8List());
      }
      image.dispose();
      picture.dispose();
      return data!.buffer.asUint8List();
    }

    final first = await render(1), still = await render(1, reduced: true);
    walk.followSnapshot(ui.Offset.zero, age: 1.1, walking: true, facingX: -200);
    expect(await render(1.1), isNot(equals(first)));
    expect(await render(1.1, reduced: true), equals(still));
    final windup = await render(2, attacking: true);
    final strike = await render(2, attacking: true, strike: 2);
    expect(strike, isNot(equals(windup)));
    expect(await render(2.2, attacking: true, strike: 2), equals(windup));
    final directory = Directory('build/test-previews/mummy-alert');
    await directory.create(recursive: true);
    for (var i = 0; i < 32; i++) {
      walk.followSnapshot(
        ui.Offset.zero,
        age: 1.2 + i / 16,
        walking: true,
        facingX: -200,
      );
      await render(
        1.2 + i / 16,
        output: '${directory.path}/${i.toString().padLeft(3, '0')}.png',
      );
    }
  });
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
