import 'package:flame/components.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/game.dart';
import 'package:regun/models/control_layout.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/base_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentAudio extends SoloudPlay {
  @override
  Future<void> play(String assetPath) async {}
}

void main() {
  testWidgets(
      'movement stays held while the aiming thumb reaches dash; pause releases input',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late RegunGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_SilentAudio())],
          child: const MaterialApp(home: BaseView())));
      game = tester
          .widget<RiverpodAwareGameWidget>(find.byType(RiverpodAwareGameWidget))
          .game! as RegunGame;
      await game.loaded;
      await tester.pump();
      await game.ready();
      game.update(2); // Finish deployment before exercising combat.
    });
    game.update(1 / 60);
    await tester.pump();
    final factor = game.canvasSize.y / game.camera.viewport.virtualSize.y;
    final inset =
        (game.canvasSize - game.camera.viewport.virtualSize * factor) / 2;
    for (final size in [88.0, 96.0, 112.0]) {
      game.setControls(game.controls.copyWith(size: size));
      for (final button in [game.boostButtonComponent, game.reloadButtonComponent]) {
        expect(button.size.x * button.scale.x * factor,
            closeTo(56 * size / 96, .001));
      }
      expect(game.movementJoystick.size.x * game.movementJoystick.scale.x * factor,
          closeTo(size, .001));
    }
    expect(ControlLayout.fromJson(game.controls.toJson()).buttonSize,
        closeTo(56 * 112 / 96, .001));
    Offset touch(PositionComponent component) =>
        (component.position * factor + inset).toOffset();
    final move =
        await tester.startGesture(touch(game.movementJoystick), pointer: 1);
    final aim =
        await tester.startGesture(touch(game.weaponJoystick), pointer: 2);
    await move.moveBy(const Offset(32, 0));
    await aim.moveBy(const Offset(32, 0));
    await move.moveBy(const Offset(10, 0));
    await aim.moveBy(const Offset(10, 0));
    for (var i = 0; i < 3; i++) {
      game.update(1 / 60);
    }
    expect(game.movementJoystick.relativeDelta.x, greaterThan(0));
    expect(game.weaponJoystick.relativeDelta.x, greaterThan(0));
    await aim.up();
    game.update(1 / 60);
    expect(game.movementJoystick.relativeDelta.x, greaterThan(0));
    final before = game.myPlayer.position.clone();
    final dash =
        await tester.startGesture(touch(game.boostButtonComponent) +
            Offset(game.controls.buttonSize / 2 - 2, 0), pointer: 3);
    expect(game.boostButtonComponent.tapped, isTrue);
    for (var i = 0; i < 3; i++) {
      game.update(1 / 60);
    }
    expect(game.myPlayer.position.x - before.x, closeTo(1450 * .05, .01));
    expect(game.boostButtonComponent.checkpoint()['duration'], 1.6);
    expect(game.movementJoystick.relativeDelta.x, greaterThan(0));
    await dash.up();
    await move.up();
    for (var i = 0; i < 3; i++) {
      game.update(1 / 60);
    }
    expect(game.movementJoystick.relativeDelta.isZero(), isTrue);
    final nextAim =
        await tester.startGesture(touch(game.weaponJoystick), pointer: 4);
    await nextAim.moveBy(const Offset(32, 0));
    await nextAim.moveBy(const Offset(10, 0));
    for (var i = 0; i < 3; i++) {
      game.update(1 / 60);
    }
    expect(game.weaponJoystick.relativeDelta.x, greaterThan(0));
    game.pauseGame();
    expect(game.weaponJoystick.relativeDelta.isZero(), isTrue);
    await nextAim.up();
    game.resumeGame();
    expect(game.weaponJoystick.relativeDelta.isZero(), isTrue);
    game.gameNotifier.decreaseBullets();
    final reload = await tester.startGesture(touch(game.reloadButtonComponent) -
        Offset(game.controls.buttonSize / 2 - 2, 0), pointer: 5);
    expect(game.gameState.reloading, isTrue);
    await reload.up();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
