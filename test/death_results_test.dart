import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/components/enemies/enemy_component.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';

class _SilentAudio extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
  @override
  Future<void> playMusic(String theme) async {}
  @override
  void configure({required double music, required double sfx}) {}
  @override
  void pauseMusic(bool paused) {}
}

class _WorkingStore extends RunStore {
  Map<String, dynamic>? snapshot;
  @override
  Future<bool> write(Map<String, dynamic> data) async {
    snapshot = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    return true;
  }

  @override
  Future<void> clear({String? expectedRunId}) async {
    if (expectedRunId == null || snapshot?['id'] == expectedRunId) {
      snapshot = null;
    }
  }
}

void main() {
  testWidgets(
      'three contact hits during reload show usable results when saving succeeds',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _WorkingStore();
    const capture = Key('death-capture');
    late RegunGame game;
    await tester.runAsync(() async {
      for (final font in ['PressStart2P', 'Orbitron']) {
        await (FontLoader(font)
              ..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf')))
            .load();
      }
      await tester.pumpWidget(ProviderScope(
        overrides: [soloudPlayProvider.overrideWithValue(_SilentAudio())],
        child: MaterialApp(initialRoute: '/game', routes: {
          '/': (_) => const Scaffold(body: Text('Start run')),
          '/game': (_) =>
              RepaintBoundary(key: capture, child: BaseView(runStore: store)),
        }),
      ));
      game = tester
          .widget<RiverpodAwareGameWidget>(find.byType(RiverpodAwareGameWidget))
          .game! as RegunGame;
      await game.loaded;
      await tester.pump();
      await game.ready();
    });
    await tester.pump(const Duration(milliseconds: 400));

    Future<void> dieByContact() async {
      final scorpion =
          EnemyComponent(position: game.myPlayer.position + Vector2(8, 0));
      await tester.runAsync(() async {
        await game.world.add(scorpion);
        await game.ready();
        for (var i = 0; i < 5; i++) {
          game.gameNotifier.decreaseBullets();
        }
        game.gameNotifier.reloadBullets();
        for (var frame = 0; frame < 240 && game.gameState.health > 0; frame++) {
          scorpion.position.setFrom(game.myPlayer.position + Vector2(8, 0));
          game.update(1 / 60);
        }
        await game.leaveRun();
      });
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(game.gameState.health, 0);
      expect(game.gameState.gameplayState, GameplayState.gameOver);
      expect(game.saveIssue, isNull,
          reason:
              'A successful save must not be needed to size the result overlay');
      expect(find.text('END OF THE LINE').hitTestable(), findsOneWidget);
      expect(find.text('RESTART').hitTestable(), findsOneWidget);
      expect(find.text('MENU').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await dieByContact();
    await tester.runAsync(() async {
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/contact-death-results.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.text('RESTART'));
    await tester.runAsync(() async {
      await tester.pump();
      await game.ready();
    });
    expect(game.gameState.gameplayState, GameplayState.playing);
    expect(game.gameState.health, 6);
    expect(game.gameState.noOfBullets, 5);
    expect(game.paused, isFalse);
    await dieByContact();
    await tester.runAsync(() async {
      await tester.tap(find.text('MENU'));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(game.preferences.profile.settledRuns, hasLength(2));
    expect(find.text('Start run'), findsOneWidget);
    expect(find.byType(BaseView), findsNothing);
  });
}
