import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/game.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/services/run_store.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/menu_view.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/collection_view.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:regun/views/settings_view.dart';
import 'package:regun/widgets/home_artwork.dart';

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

const cases = [
  (568.0, 320.0, 0.0, 0.0),
  (667.0, 375.0, 0.0, 0.0),
  (812.0, 375.0, 44.0, 21.0),
  (844.0, 390.0, 47.0, 21.0),
  (852.0, 393.0, 59.0, 21.0),
  (874.0, 402.0, 62.0, 21.0),
  (932.0, 430.0, 59.0, 21.0),
  (956.0, 440.0, 62.0, 21.0)
];
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'Regun',
        packageName: 'dev.kiishi.regun',
        version: '1.0.0',
        buildNumber: '3',
        buildSignature: '');
    for (final pair in [
      ('PressStart2P', 'PressStart2P-Regular.ttf'),
      ('Orbitron', 'Orbitron-Regular.ttf')
    ]) {
      await (FontLoader(pair.$1)
            ..addFont(rootBundle.load('assets/fonts/${pair.$2}')))
          .load();
    }
  });
  Widget shell(Widget page, EdgeInsets safe, double scale) => ProviderScope(
      overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
      child: MaterialApp(
          key: UniqueKey(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  padding: safe, textScaler: TextScaler.linear(scale)),
              child: child!),
          home:
              RepaintBoundary(key: const Key('iphone-capture'), child: page)));

  testWidgets(
      'iPhone menu matrix preserves navigation, version label and safe edges',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await RegunArt.shared.load();
      await LocalPreferences.shared.load();
      await RunStore.shared.read(validate: RunCheckpoint.valid);
    });
    for (final device in cases) {
      tester.view.physicalSize = Size(device.$1, device.$2);
      final safe = EdgeInsets.fromLTRB(device.$3, 0, device.$3, device.$4);
      for (final scale in [1.0, 1.5]) {
        for (final page in [
          const MenuView(),
          const CollectionView(),
          const LoadoutView(training: true),
          const SettingsView()
        ]) {
          await tester.runAsync(() async {
            await tester.pumpWidget(shell(page, safe, scale));
            await Future<void>.delayed(const Duration(milliseconds: 10));
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '$device / $scale / ${page.runtimeType}');
          if (page is MenuView) {
            expect(find.text('LOADING'), findsNothing);
            expect(find.text('v1.0.0 (3)'), findsOneWidget);
            final label = tester.getRect(find.text('v1.0.0 (3)'));
            final art = tester.getRect(find.byType(HomeArtwork));
            expect(label.top, greaterThanOrEqualTo(art.bottom));
            expect(label.bottom, lessThanOrEqualTo(device.$2 - safe.bottom));
            expect(label.right, lessThanOrEqualTo(device.$1 - safe.right));
            if (scale == 1 && (device.$1 == 844 || device.$1 == 956)) {
              await tester.runAsync(() async {
                final boundary = tester.renderObject<RenderRepaintBoundary>(
                    find.byKey(const Key('iphone-capture')));
                final image = await boundary.toImage(pixelRatio: 2);
                final data =
                    await image.toByteData(format: ui.ImageByteFormat.png);
                await Directory('build/test-previews').create(recursive: true);
                await File('build/test-previews/home-${device.$1.toInt()}.png')
                    .writeAsBytes(data!.buffer.asUint8List());
                image.dispose();
              });
            }
          } else {
            expect(find.text('BACK').hitTestable(), findsOneWidget);
          }
        }
      }
    }
  });

  testWidgets(
      'iPhone gameplay matrix keeps HUD, boss and touch targets usable in both landscape safe-area arrangements',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final device in cases) {
      tester.view.physicalSize = Size(device.$1, device.$2);
      for (final mirror in [false, true]) {
        final safe = EdgeInsets.fromLTRB(
            mirror ? 0 : device.$3, 0, mirror ? device.$3 : 0, device.$4);
        late RegunGame game;
        await tester.runAsync(() async {
          await tester.pumpWidget(shell(
              const BaseView(loadout: Loadout(training: true)), safe, 1.5));
          game = tester
              .widget<RiverpodAwareGameWidget>(
                  find.byType(RiverpodAwareGameWidget))
              .game! as RegunGame;
          await game.loaded;
          await tester.pump();
          await game.ready();
          game.update(1 / 60);
          final snapshot = game.gameNotifier.checkpoint();
          final state = snapshot['state'] as Map<String, dynamic>;
          state['kills'] = 99999;
          state['currentLevel'] = 99;
          state['health'] = 12;
          state['maxHealth'] = 12;
          state['survivalSeconds'] = 1234;
          snapshot['activeSeconds'] = 1234.0;
          game.gameNotifier.restoreCheckpoint(snapshot);
          game.resumeGame();
          game.spawnBoss(BossKind.demon);
          await game.ready();
          expect(game.activeBoss, isNotNull);
        });
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: '$device / mirror:$mirror / large HUD');
        // Finish deployment before checking the large-text damage HUD.
        game.update(2);
        game.damageFeedback.trigger(amount: 2);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$device / damage HUD');
        expect(find.text('-2 HP'), findsOneWidget);
        expect(find.text('99999'), findsOneWidget);
        expect(find.text('L99 / C1'), findsOneWidget);
        final virtual = game.camera.viewport.virtualSize;
        final factor = math.min(
            game.canvasSize.x / virtual.x, game.canvasSize.y / virtual.y);
        final offset = (game.canvasSize - virtual * factor) / 2;
        for (final node in <PositionComponent>[
          game.movementJoystick,
          game.weaponJoystick,
          game.boostButtonComponent,
          game.reloadButtonComponent
        ]) {
          final center = (node.position * factor + offset).toOffset();
          final width = node.size.x * node.scale.x * factor;
          final height = node.size.y * node.scale.y * factor;
          final rect =
              Rect.fromCenter(center: center, width: width, height: height);
          expect(rect.left, greaterThanOrEqualTo(safe.left - .1));
          expect(rect.right, lessThanOrEqualTo(device.$1 - safe.right + .1));
          expect(rect.bottom, lessThanOrEqualTo(device.$2 - safe.bottom + .1));
          expect(math.min(width, height), greaterThanOrEqualTo(48));
        }
        game.pauseGame();
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
