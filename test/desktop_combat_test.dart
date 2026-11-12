import 'package:regun/desktop/web_landscape_prompt.dart';
import 'package:regun/desktop/desktop_bindings.dart';
import 'package:regun/desktop/desktop_controller.dart';
import 'package:regun/widgets/game_presentation.dart';
import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/desktop/desktop_frame_pacer.dart';
import 'package:regun/game.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}

  @override
  Future<void> playMusic(String theme) async {}
}

Future<RegunGame> _mountTraining(WidgetTester tester) async {
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
            child: WebLandscapePrompt(child: child!),
          ),
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
      advance(frame(1, 0, grenade: 1), 45);
      expect(game.aimIntent.isZero(), isTrue);
      expect(game.desktopGrenadeDirection.x, -1);
      final grenadesBeforeRelease = game.grenades.charges;
      advance(frame(1, 0), 1);
      expect(game.grenades.charges, grenadesBeforeRelease - 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );
}
