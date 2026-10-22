import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/game.dart';
import 'package:regun/models/control_layout.dart';
import 'package:regun/presentation/game_layout.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:regun/views/settings_view.dart';
import 'package:regun/widgets/game_presentation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    for (final font in ['PressStart2P', 'Orbitron']) {
      await (FontLoader(
        font,
      )..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf'))).load();
    }
    await LocalPreferences.shared.load();
  });
  test(
    'tablet framing fills its aspect without cropping the phone gameplay view',
    () {
      for (final size in [
        const Size(568, 320),
        const Size(844, 390),
        const Size(932, 430),
      ]) {
        expect(GameLayout.world(size), const Size(1500, 700));
        expect(GameLayout.uiScale(size), 1);
      }
      for (final size in [
        const Size(1024, 768),
        const Size(1366, 1024),
        const Size(834, 1194),
        const Size(1600, 600),
      ]) {
        final world = GameLayout.world(size);
        expect(world.width, greaterThanOrEqualTo(1500));
        expect(world.height, greaterThanOrEqualTo(700));
        expect(world.aspectRatio, closeTo(size.aspectRatio, 1e-9));
        expect(GameLayout.uiScale(size), 1.25);
      }
    },
  );
  test('tablet control geometry is larger, mirrored, separate and never persisted as scaled preferences', () {
    for (final size in [88.0, 96.0, 112.0]) {
      for (final left in [false, true]) {
        final layout = ControlLayout(size: size, leftHanded: left);
        final before = layout.toJson();
        const viewport = Size(1366, 1000);
        final geometry = layout.geometry(viewport);
        expect(layout.displaySize(viewport), size * 1.25);
        expect(
          geometry.separate(
            layout.displaySize(viewport) / 2,
            buttonRadius: layout.displayButtonSize(viewport) / 2,
          ),
          isTrue,
        );
        expect(geometry.movement.dx < viewport.width / 2, !left);
        expect(geometry.dash.dx > viewport.width / 2, !left);
        expect(layout.toJson(), before);
        expect(ControlLayout.fromJson(before).size, size);
        final other = layout.copyWith(leftHanded: !left).geometry(viewport);
        expect(geometry.aim.dx + other.aim.dx, viewport.width);
      }
    }
  });
  Future<RegunGame> mount(WidgetTester tester) async {
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: MaterialApp(
            builder: (context, child) => GamePresentation(child: child!),
            home: const BaseView(loadout: Loadout(training: true)),
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
      await game.ready();
    });
    await tester.pump();
    return game;
  }

  testWidgets(
    'tablet arena fills the native canvas and resizing cancels held input safely',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = await mount(tester);
      expect(game.camera.viewport.size, game.canvasSize);
      expect(
        game.camera.viewport.virtualSize.y,
        closeTo(1500 * 1024 / 1366, 0.001),
      );
      for (final control in <PositionComponent>[
        game.movementJoystick,
        game.weaponJoystick,
        game.boostButtonComponent,
        game.reloadButtonComponent,
        game.grenadeButtonComponent,
      ]) {
        final point = game.camera.viewport.localToGlobal(control.position);
        expect(point.x, inInclusiveRange(0, 1366));
        expect(point.y, inInclusiveRange(0, 1024));
      }
      final finger = await tester.startGesture(
        game.camera.viewport
            .localToGlobal(game.movementJoystick.position)
            .toOffset(),
      );
      await finger.moveBy(const Offset(35, 0));
      await tester.pump();
      expect(game.movementJoystick.relativeDelta.length, greaterThan(.1));
      tester.view.physicalSize = const Size(1024, 1366);
      await tester.pump();
      expect(game.camera.viewport.size, game.canvasSize);
      expect(game.movementJoystick.relativeDelta.length, 0);
      expect(game.camera.viewport.virtualSize.x, 1500);
      expect(
        game.camera.viewport.virtualSize.y,
        closeTo(1500 * 1366 / 1024, 0.001),
      );
      await finger.up();
      await tester.pump(const Duration(milliseconds: 100));
      game.pauseGame();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'tablet presentation preserves phone text and composes accessibility scaling',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [const Size(844, 390), const Size(1366, 1024)]) {
        tester.view.physicalSize = size;
        for (final userScale in [1.0, 1.5]) {
          double? measured;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(userScale)),
                child: GamePresentation(child: child!),
              ),
              home: Builder(
                builder: (context) {
                  measured = MediaQuery.textScalerOf(context).scale(10);
                  return const SizedBox();
                },
              ),
            ),
          );
          expect(measured, 10 * userScale * GameLayout.uiScale(size));
        }
      }
    },
  );
  testWidgets(
    'loadout and shared settings fit tablet landscape and portrait with larger text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [
        const Size(1024, 768),
        const Size(1366, 1024),
        const Size(834, 1194),
      ]) {
        tester.view.physicalSize = size;
        for (final page in [
          const LoadoutView(training: true),
          const SettingsView(),
        ]) {
          await tester.runAsync(() async {
            await tester.pumpWidget(
              ProviderScope(
                overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.5)),
                    child: GamePresentation(child: child!),
                  ),
                  home: page,
                ),
              ),
            );
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$size $page');
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );
}
