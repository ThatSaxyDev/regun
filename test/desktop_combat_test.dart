import 'package:regun/desktop/web_landscape_prompt.dart';
import 'package:regun/desktop/desktop_bindings.dart';
import 'package:regun/desktop/desktop_controller.dart';
import 'package:regun/desktop/controller_device.dart';
import 'package:regun/widgets/game_presentation.dart';
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/weapons/grenade_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/desktop/desktop_frame_pacer.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/systems/grenades.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}

  @override
  Future<void> playMusic(String theme) async {}
}

Future<RegunGame> _mountTraining(
  WidgetTester tester, {
  Future<List<ControllerDevice>?> Function()? readDevices,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late RegunGame game;
  await tester.runAsync(() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
        child: MaterialApp(
          builder: (_, child) => GamePresentation(
            scale: DesktopBindings.textBaseline,
            child: readDevices == null
                ? WebLandscapePrompt(child: child!)
                : DesktopController(readDevices: readDevices, child: child!),
          ),
          home: readDevices == null
              ? const BaseView(loadout: Loadout(training: true))
              : const Scaffold(body: Text('Training closed')),
          initialRoute: readDevices == null ? null : '/training',
          routes: {
            if (readDevices != null)
              '/training': (_) =>
                  const BaseView(loadout: Loadout(training: true)),
          },
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
  });
  await tester.pump();
  return game;
}

void main() {
  test('frame cap preserves elapsed simulation time', () {
    for (final rate in [60, 120]) {
      final pacer = DesktopFramePacer();
      var frames = 0;
      var elapsed = 0.0;
      pacer.advance(0, rate);
      for (var i = 0; i < 240; i++) {
        final step = pacer.advance(1 / 120, rate);
        if (step == null) continue;
        frames++;
        elapsed += step;
      }
      expect(frames, rate * 2);
      expect(elapsed, closeTo(2, 1e-8));
    }
  });

  testWidgets('desktop hover aims without firing and pause clears held input', (
    tester,
  ) async {
    final game = await _mountTraining(tester);
    expect(
      game.camera.viewport.virtualSize.x / game.camera.viewport.virtualSize.y,
      closeTo(16 / 9, .001),
    );
    expect(game.movementJoystick.showTouchControl, isFalse);
    expect(game.boostButtonComponent.showTouchControl, isFalse);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final point = game.camera
        .localToGlobal(game.myPlayer.position + Vector2(200, 0))
        .toOffset();
    await mouse.addPointer(location: point);
    await mouse.moveTo(point);
    expect(game.aimIntent.x, closeTo(1, .01));
    expect(game.fireIntent, isFalse);

    await mouse.down(point);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    expect(game.movementIntent.y, -1);
    expect(game.fireIntent, isTrue);
    game.update(1 / 60);
    expect(game.shotsFired, 1);

    double? recharge(String action) => tester
        .widget<LinearProgressIndicator>(
          find.byWidgetPredicate(
            (widget) =>
                widget is LinearProgressIndicator &&
                widget.semanticsLabel == '$action recharge',
          ),
        )
        .value;

    await tester.pump();
    expect(recharge('Dash'), 1);
    expect(recharge('Grenade'), 1);
    expect(game.boostButtonComponent.reserve.spend(1.6), isTrue);
    expect(game.grenades.spend(18), isTrue);
    game.update(.1);
    await tester.pump();
    final dashProgress = recharge('Dash')!;
    final grenadeProgress = recharge('Grenade')!;
    expect(dashProgress, lessThan(1));
    expect(grenadeProgress, lessThan(1));
    game.update(.5);
    await tester.pump();
    expect(recharge('Dash'), greaterThan(dashProgress));
    expect(recharge('Grenade'), greaterThan(grenadeProgress));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(game.gameState.gameplayState, GameplayState.paused);
    expect(game.fireIntent, isFalse);
    expect(game.movementIntent.length2, 0);
    await mouse.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    game.resumeGame();
    await tester.pump();
    tester.view.physicalSize = const Size(600, 900);
    await tester.pump();
    await tester.pump();
    expect(find.text('LANDSCAPE REQUIRED'), findsOneWidget);
    expect(find.byType(RiverpodAwareGameWidget), findsNothing);
    expect(game.viewportBlocked, isTrue);
    expect(game.gameState.gameplayState, GameplayState.paused);
    tester.view.physicalSize = const Size(960, 540);
    await tester.pump();
    expect(game.viewportBlocked, isFalse);
    expect(game.gameState.gameplayState, GameplayState.paused);
    game.resumeGame();
    await tester.pump();
    expect(game.fireIntent, isFalse);
    expect(game.camera.viewport.virtualSize.y, 1080);
    expect(game.gameNotifier.offerSupplyUpgrade(), isTrue);
    await tester.pump();
    final choose = find.text('Choose');
    expect(choose, findsWidgets);
    final reroll = find.byKey(const Key('upgrade-reroll'));
    expect(reroll, findsOneWidget);
    expect(
      tester.getCenter(reroll).dy - tester.getCenter(choose.first).dy,
      lessThan(120),
    );
    await tester.tap(choose.first);
    await tester.pump();
    expect(game.gameState.gameplayState, GameplayState.playing);
    await mouse.removePointer();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets(
    'controller returns to running direction after aim and fire release',
    (tester) async {
      final game = await _mountTraining(tester);
      final dispatch = DesktopController.handlers.last;
      ControllerFrame frame(
        double moveX,
        double aimX, {
        double fire = 0,
        double grenade = 0,
      }) => ControllerFrame(
        List<double>.filled(20, 0)
          ..[0] = moveX
          ..[2] = aimX
          ..[10] = grenade
          ..[11] = fire,
      );
      void advance(ControllerFrame input, int frames) {
        for (var i = 0; i < frames; i++) {
          expect(dispatch(input), isTrue);
          game.update(1 / 60);
        }
      }

      final survivor = game.loadout.character.name;
      Sprite? pose() => game.myPlayer.animation?.frames.first.sprite;
      dispatch(frame(0, 0));
      advance(frame(1, -1, fire: 1), 1);
      expect(game.shotsFired, 1);
      expect(game.myPlayer.aimDirection.x, -1);
      expect(pose(), same(RegunArt.shared.survivorRunFrame(survivor, 2, 0)));

      advance(frame(1, 0, fire: 1), 45);
      expect(game.fireIntent, isTrue);
      expect(game.myPlayer.aimDirection.x, -1);

      advance(frame(1, 0), 1);
      expect(game.movementIntent.x, 1);
      expect(game.fireIntent, isFalse);
      expect(game.aimIntent.isZero(), isTrue);
      expect(pose(), same(RegunArt.shared.survivorRunFrame(survivor, 0, 0)));
      advance(frame(1, 0), 35);
      expect(game.myPlayer.aimDirection.x, -1);
      advance(frame(1, 0), 40);
      expect(game.myPlayer.aimDirection.x, closeTo(1, .001));

      advance(frame(1, -1), 1);
      expect(game.myPlayer.aimDirection.x, -1);
      expect(game.fireIntent, isFalse);
      advance(frame(1, -1, grenade: 1), 1);
      expect(game.desktopGrenadePower, 1);
      advance(frame(1, -.55, grenade: 1), 1);
      final power = game.desktopGrenadePower;
      expect(power, inExclusiveRange(.4, 1));
      advance(frame(1, 0, grenade: 1), 45);
      expect(game.aimIntent.isZero(), isTrue);
      expect(game.desktopGrenadeDirection.x, -1);
      expect(game.desktopGrenadePower, power);
      final grenadesBeforeRelease = game.grenades.charges;
      expect(dispatch(frame(1, 0)), isTrue);
      expect(game.grenades.charges, grenadesBeforeRelease - 1);
      await tester.runAsync(() async {
        game.update(0);
        await game.ready();
      });
      final grenade = game.world.children.whereType<GrenadeComponent>().single;
      expect(
        grenade.flight.velocity.dx,
        closeTo(-GrenadeSpec.speed * power, .001),
      );
      final touch = await tester.startGesture(
        const Offset(450, 250),
        kind: PointerDeviceKind.touch,
      );
      expect(game.usingDesktopInput, isFalse);
      await touch.up();
      dispatch(frame(0, 0));
      advance(frame(-1, 0), 1);
      expect(game.usingDesktopInput, isTrue);
      expect(game.movementIntent.x, -1);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'mouse position sets grenade range for mouse and keyboard release',
    (tester) async {
      final game = await _mountTraining(tester);
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      Offset at(double distance) => game.camera
          .localToGlobal(game.myPlayer.position + Vector2(distance, 0))
          .toOffset();
      final near = at(230);
      await mouse.addPointer(location: near);
      await mouse.moveTo(near);
      await mouse.down(near);
      final shortPower = game.desktopGrenadePower;
      expect(shortPower, inExclusiveRange(.4, 1));
      expect(game.grenades.charges, 2);
      await mouse.up();
      await tester.runAsync(() async {
        game.update(0);
        await game.ready();
      });
      final grenades = game.world.children.whereType<GrenadeComponent>();
      expect(
        grenades.single.flight.velocity.dx,
        closeTo(GrenadeSpec.speed * shortPower, .001),
      );

      game.update(.3);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyG);
      await mouse.moveTo(at(500));
      expect(game.desktopGrenadePower, 1);
      expect(game.grenades.charges, 1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyG);
      await tester.runAsync(() async {
        game.update(0);
        await game.ready();
      });
      expect(
        grenades.last.flight.velocity.dx,
        closeTo(GrenadeSpec.speed, .001),
      );
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );
  testWidgets(
    'controller pause, settings, resume and disconnect during grenade aim',
    (tester) async {
      List<ControllerDevice> devices = [];
      final game = await _mountTraining(
        tester,
        readDevices: () async => devices,
      );
      Future<void> frame({int? button, double move = 0, double aim = 0}) async {
        devices = [
          ControllerDevice(
            'pad',
            'DualSense',
            List<double>.filled(20, 0)
              ..[0] = move
              ..[2] = aim
              ..[4 + (button ?? 0)] = button == null ? 0 : 1,
          ),
        ];
        await tester.pump(const Duration(milliseconds: 17));
        await tester.pump();
      }

      Future<void> press(int button) async {
        await frame(button: button);
        await frame();
      }

      await frame();
      await press(9);
      expect(game.gameState.gameplayState, GameplayState.paused);
      expect(find.text('RESUME'), findsOneWidget);
      await press(13);
      await press(0);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(SettingsView), findsOneWidget);
      await press(1);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SettingsView), findsNothing);
      expect(game.gameState.gameplayState, GameplayState.paused);

      await press(1);
      expect(game.gameState.gameplayState, GameplayState.playing);
      await frame();
      await frame(button: 6, move: 1, aim: .6);
      expect(game.desktopInput!.grenade, isTrue);
      expect(game.movementIntent.x, 1);
      final charges = game.grenades.charges;
      devices = [];
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(game.gameState.gameplayState, GameplayState.paused);
      expect(game.desktopInput!.grenade, isFalse);
      expect(game.fireIntent, isFalse);
      expect(game.movementIntent.length2, 0);
      expect(game.grenades.charges, charges);
      expect(find.text('Controller disconnected · DualSense'), findsOneWidget);

      await frame(button: 0);
      expect(game.gameState.gameplayState, GameplayState.paused);
      await frame();
      await press(13);
      await press(13);
      await press(13);
      await press(0);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('RETURN TO MENU?'), findsOneWidget);
      await press(1);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('RETURN TO MENU?'), findsNothing);
      expect(game.gameState.gameplayState, GameplayState.paused);
      await press(0);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('RETURN TO MENU?'), findsOneWidget);
      await press(15);
      await press(0);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Training closed'), findsOneWidget);
      expect(find.byType(BaseView), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );
}
