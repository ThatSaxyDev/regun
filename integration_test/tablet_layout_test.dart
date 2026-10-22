import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:regun/widgets/game_presentation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:regun/views/settings_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool paused) {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native tablet framing, controls and practice menus', (
    tester,
  ) async {
    await Flame.device.fullScreen();
    await Flame.device.setLandscape();
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: RepaintBoundary(
            key: const Key('native-tablet-capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData.dark(),
              home: const BaseView(loadout: Loadout(training: true)),
              builder: (context, child) => GamePresentation(child: child!),
            ),
          ),
        ),
      );
      await tester.pump();
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
      await game.ready();
      for (var i = 0; i < 6; i++) {
        await game.world.add(
          EnemyComponent(
            position: game.myPlayer.position + Vector2((i - 3) * 150, -180),
          ),
        );
      }
      await game.ready();
    });
    await tester.pump(const Duration(milliseconds: 500));
    game.pauseEngine();
    expect(
      game.canvasSize.x,
      greaterThan(game.canvasSize.y),
      reason: 'The native iPad app must remain landscape.',
    );
    final orientations = <String>[];
    for (final orientation in [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]) {
      await SystemChrome.setPreferredOrientations([orientation]);
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pump();
      expect(game.canvasSize.x, greaterThan(game.canvasSize.y));
      orientations.add(orientation.name);
    }
    await Flame.device.setLandscape();
    const tag = String.fromEnvironment(
      'REGUN_LAYOUT_TAG',
      defaultValue: 'after',
    );
    final directory = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/regun-layout-$tag',
    );
    await directory.create(recursive: true);
    Future<void> capture(String name) async {
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('native-tablet-capture')),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }

    final report = <String, Object?>{
      'orientations': orientations,
      'canvas': [game.canvasSize.x, game.canvasSize.y],
      'viewport': [game.camera.viewport.size.x, game.camera.viewport.size.y],
      'world': [
        game.camera.viewport.virtualSize.x,
        game.camera.viewport.virtualSize.y,
      ],
    };
    game.resumeEngine();
    final movePoint = game.camera.viewport
        .localToGlobal(game.movementJoystick.position)
        .toOffset();
    final aimPoint = game.camera.viewport
        .localToGlobal(game.weaponJoystick.position)
        .toOffset();
    final movement = await tester.startGesture(movePoint, pointer: 1);
    await movement.moveBy(const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.movementJoystick.relativeDelta.length, greaterThan(.1));
    final aim = await tester.startGesture(aimPoint, pointer: 2);
    await aim.moveBy(const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(game.weaponJoystick.relativeDelta.length, greaterThan(.1));
    final dashes = game.dashCount;
    await tester.tapAt(
      game.camera.viewport
          .localToGlobal(game.boostButtonComponent.position)
          .toOffset(),
      pointer: 3,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.dashCount, dashes + 1);
    expect(game.movementJoystick.relativeDelta.length, greaterThan(.1));
    await aim.up();
    await movement.up();
    await tester.pump();
    game.pauseEngine();
    report['thumbsAndDash'] = 'passed';
    await capture('gameplay');
    game.pauseGame();
    await tester.pump();
    await capture('training-pause');
    await tester.tap(find.text('WEAPON PRACTICE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await capture('training-weapons');
    expect(find.text('RESUME').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await File('${directory.path}/report.json')
        .writeAsString(jsonEncode(report));
    if (!const bool.fromEnvironment('REGUN_LAYOUT_BASELINE')) {
      expect(game.camera.viewport.size.x, closeTo(game.canvasSize.x, 1));
      expect(game.camera.viewport.size.y, closeTo(game.canvasSize.y, 1));
    }
    for (final entry in <String, Widget>{
      'loadout': const LoadoutView(training: true),
      'settings': const SettingsView(),
    }.entries) {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
            child: RepaintBoundary(
              key: const Key('native-tablet-capture'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData.dark(),
                builder: (context, child) => GamePresentation(child: child!),
                home: entry.value,
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      await capture(entry.key);
      expect(tester.takeException(), isNull);
    }
    await Future<void>.delayed(const Duration(seconds: 3));
    // Short native hold permits an external simctl framebuffer capture too.
  });
}
