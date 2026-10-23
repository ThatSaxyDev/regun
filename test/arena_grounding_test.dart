import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/game_utils/player_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/systems/arena_bounds.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  void pauseMusic(bool paused) {}
}

void main() {
  for (final arena in ArenaType.values) {
    testWidgets(
      'survivor stays inside all visible fence edges and corners in ${arena.name}',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1500, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          await LocalPreferences.shared.load();
          await (FontLoader('Orbitron')
                ..addFont(rootBundle.load('assets/fonts/Orbitron-Regular.ttf')))
              .load();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
              child: MaterialApp(
                home: BaseView(loadout: Loadout(training: true, arena: arena)),
              ),
            ),
          );
          final game =
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
          final bounds = game.map.bounds;
          final player = game.myPlayer;
          final directions = [
            ('TOP', Vector2(0, -1)),
            ('RIGHT', Vector2(1, 0)),
            ('BOTTOM', Vector2(0, 1)),
            ('LEFT', Vector2(-1, 0)),
            ('TOP LEFT', Vector2(-1, -1)),
            ('TOP RIGHT', Vector2(1, -1)),
            ('BOTTOM LEFT', Vector2(-1, 1)),
            ('BOTTOM RIGHT', Vector2(1, 1)),
          ];
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          for (var i = 0; i < directions.length; i++) {
            player.position.setFrom(directions[i].$2.normalized() * 2000);
            // A large real dash step must stop before every rendered inner edge.
            game.moveActor(
              player,
              directions[i].$2.normalized(),
              1450,
              5,
              radius: PlayerComponent.collisionRadius,
            );
            game.update(0);
            await game.ready();
            final p = player.position;
            final direction = directions[i].$2;
            if (direction.x != 0) {
              expect(
                p.x,
                closeTo(
                  direction.x < 0
                      ? bounds.interior.left + PlayerComponent.collisionRadius
                      : bounds.interior.right - PlayerComponent.collisionRadius,
                  .001,
                ),
              );
            }
            if (direction.y != 0) {
              expect(
                p.y,
                closeTo(
                  direction.y < 0
                      ? bounds.interior.top + PlayerComponent.collisionRadius
                      : bounds.interior.bottom - player.boundaryFootExtent,
                  .001,
                ),
              );
            }

            expect(
              p.x - PlayerComponent.collisionRadius,
              greaterThanOrEqualTo(bounds.interior.left),
            );
            expect(
              p.x + PlayerComponent.collisionRadius,
              lessThanOrEqualTo(bounds.interior.right),
            );
            expect(
              p.y - PlayerComponent.collisionRadius,
              greaterThanOrEqualTo(bounds.interior.top),
            );
            expect(
              p.y + player.boundaryFootExtent,
              lessThanOrEqualTo(bounds.interior.bottom),
            );
            // The feet stop above the south wall's drawn face, not just its base.
            expect(
              p.y + player.size.y * .38,
              lessThanOrEqualTo(
                bounds.floor.bottom -
                    ArenaBounds.fenceThickness -
                    ArenaBounds.wallVisualRise -
                    4,
              ),
            );
            final view = game.camera.visibleWorldRect;
            final screen = Offset(
              (p.x - view.left) / view.width * game.canvasSize.x,
              (p.y - view.top) / view.height * game.canvasSize.y,
            );
            canvas.save();
            canvas.translate((i % 2) * 600.0, (i ~/ 2) * 300.0);
            canvas.clipRect(const Rect.fromLTWH(0, 0, 600, 300));
            canvas.drawColor(const Color(0xff151219), BlendMode.src);
            canvas.save();
            canvas.translate(300 - screen.dx, 150 - screen.dy);
            game.render(canvas);
            canvas.restore();
            final text = TextPainter(
              text: TextSpan(
                text: '${arena.name.toUpperCase()} / ${directions[i].$1}',
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            text.paint(canvas, const Offset(16, 16));
            canvas.restore();
          }
          final picture = recorder.endRecording();
          final image = await picture.toImage(1200, 1200);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/test-previews').create(recursive: true);
          await File('build/test-previews/fence-${arena.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
          picture.dispose();
          await tester.pumpWidget(const SizedBox());
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}
