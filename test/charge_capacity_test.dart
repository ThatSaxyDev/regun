import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/presentation/control_art.dart';
import 'package:regun/presentation/grenade_art.dart';
import 'package:regun/theme/pixel_glyph.dart';
import 'package:regun/game.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/services/balance_repository.dart';
import 'package:regun/models/run_checkpoint.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/models/live_balance.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/systems/dash_reserve.dart';
import 'package:regun/systems/grenades.dart';
import 'package:regun/multiplayer/movement_prediction.dart';

class _SilentAudio extends SoloudPlay {
  @override
  Future<void> play(String name) async {}
  @override
  Future<void> playMusic(String name) async {}
  @override
  void pauseMusic(bool value) {}
}

void main() {
  testWidgets(
    'lower admin caps survive the real game checkpoint and pause freezes reserve clocks',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final previous = BalanceRepository.shared.current;
      addTearDown(() => BalanceRepository.shared.current = previous);
      BalanceRepository.shared.current = LiveBalance.create(11, {
        ...LiveBalance.bundled.values,
        'powerups.dashCapacity.capacity': 2,
        'powerups.grenadeCapacity.capacity': 3,
      });
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(_SilentAudio())],
            child: const MaterialApp(
              home: BaseView(loadout: Loadout(training: true)),
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
        for (final power in [PowerUp.dashCapacity, PowerUp.grenadeCapacity]) {
          final cp = game.gameNotifier.checkpoint();
          cp['state'] = game.gameState
              .copyWith(
                gameplayState: GameplayState.powerup,
                powerUpChoices: [power],
                offerId: game.gameState.offerId + 1,
              )
              .toJson();
          game.gameNotifier.restoreCheckpoint(cp);
          game.gameNotifier.playGame();
          game.gameNotifier.applyPowerUp(
            power,
            offerId: game.gameState.offerId,
          );
        }
        game.update(
          2,
        ); // Finish accepted-upgrade presentation before active capacity sync.
        game.update(.05);
        expect(game.boostButtonComponent.reserve.capacity, 2);
        expect(game.grenades.capacity, 3);
        game.boostButtonComponent.reserve.spend(1.6);
        game.grenades.spend(18);
        game.gameNotifier.pauseGame();
        final saved = game.checkpoint();
        expect(RunCheckpoint.valid(saved), isTrue);
        final dash = game.boostButtonComponent.reserve.toJson(),
            grenades = game.grenades.toJson();
        game.update(1);
        expect(game.boostButtonComponent.reserve.toJson(), dash);
        expect(game.grenades.toJson(), grenades);
        expect(game.restoreRun(saved), isTrue);
        expect(game.gameState.rankLimit(PowerUp.dashCapacity), 1);
        expect(game.boostButtonComponent.reserve.toJson(), dash);
        expect(game.grenades.toJson(), grenades);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    },
  );
  test('charge markers render within the original control bounds', () async {
    await (FontLoader(FontFam.pressStart)
          ..addFont(rootBundle.load('assets/fonts/PressStart2P-Regular.ttf')))
        .load();
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xff161218), BlendMode.src);
    ControlArt.action(
      canvas,
      glyph: PixelGlyph.dash,
      label: 'DASH',
      opacity: 1,
      capacity: 3,
      charges: 1,
      chargeProgress: .4,
    );
    canvas.translate(128, 0);
    const GrenadeButtonPainter(
      charges: 2,
      capacity: 4,
      progress: .5,
      remaining: 9,
    ).paint(canvas, const Size(112, 112));
    final picture = recorder.endRecording();
    final image = await picture.toImage(256, 112);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    await Directory('build/test-previews').create(recursive: true);
    await File('build/test-previews/charge-controls.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });

  test('dash reserve grants only the new slots, keeps recharge, and resumes exactly', () {
    final d = DashReserve()..spend(1.6);
    d.advance(.4, 1.6);
    d.setCapacity(2);
    expect(d.charges, 1);
    expect(d.remaining, closeTo(1.2, 1e-8));
    d.setCapacity(2);
    expect(d.charges, 1);
    expect(d.spend(1.6), isTrue);
    expect(d.spend(1.6), isFalse);
    d.setCapacity(3);
    expect(d.charges, 1);
    d.spend(1.6);
    final copy = DashReserve()..restore(d.toJson());
    copy.advance(1.2, 1.6);
    expect(copy.charges, 1);
    expect(copy.remaining, closeTo(1.6, 1e-8));
    copy.advance(3.2, 1.6);
    expect(copy.charges, 3);
    expect(copy.remaining, 0);
    final legacy = DashReserve()..restore({'remaining': .8, 'duration': 1.6});
    expect(legacy.charges, 0);
    expect(
      () => copy.restore({...copy.toJson(), 'capacity': 4}),
      throwsFormatException,
    );
  });
  test('four grenade slots preserve the first clock and still recharge sequentially', () {
    final g = GrenadeInventory()..spend(18);
    g.advance(3, 18);
    g.setCapacity(4);
    expect(g.charges, 3);
    expect(g.remaining, 15);
    for (var i = 0; i < 3; i++) {
      expect(g.spend(18), isTrue);
      g.advance(.25, 18);
    }
    expect(g.charges, 0);
    final saved = GrenadeInventory()..restore(g.toJson());
    saved.advance(14.25, 18);
    expect(saved.charges, 1);
    saved.advance(54, 18);
    expect(saved.charges, 4);
    expect(saved.remaining, 0);
  });
  test(
    'admin totals bound ranks and old snapshots keep their original identity',
    () {
      final s = GameState(
        upgradeStrengths: const {'dashCapacity': 2, 'grenadeCapacity': 3},
        ranks: const {PowerUp.dashCapacity: 1, PowerUp.grenadeCapacity: 1},
      );
      expect(s.dashCapacity, 2);
      expect(s.grenadeCapacity, 3);
      expect(eligiblePowerUps(s), isNot(contains(PowerUp.dashCapacity)));
      expect(eligiblePowerUps(s), isNot(contains(PowerUp.grenadeCapacity)));
      final raw = jsonDecode(
        File('test/fixtures/balance-capacity-legacy.json').readAsStringSync(),
      );
      expect(LiveBalance.fromJson(raw).toJson(), raw);
      expect(
        () => LiveBalance.create(0, {
          ...LiveBalance.bundled.values,
          'powerups.dashCapacity.capacity': 4,
        }),
        throwsFormatException,
      );
    },
  );
  test('online prediction spends stored dashes without resetting the first recharge', () {
    final map = MotionMap({
      'bounds': [-3000, -3000, 3000, 3000],
      'obstacles': [],
    });
    var b = const MotionBody(
      position: Offset.zero,
      dashCapacity: 3,
      dashCharges: 3,
      rechargeRemaining: 0,
    );
    for (var i = 1; i <= 3; i++) {
      b = b.step(
        MotionInput(i, const Offset(1, 0), Offset.zero, i),
        .05,
        map,
        [],
        speed: 300,
        dashCooldown: 1.6,
      );
      b = b.step(null, .15, map, [], speed: 300, dashCooldown: 1.6);
    }
    expect(b.dashCharges, 0);
    expect(b.rechargeRemaining, closeTo(1, 1e-8));
    b = b.step(
      const MotionInput(4, Offset(1, 0), Offset.zero, 4),
      .05,
      map,
      [],
      speed: 300,
      dashCooldown: 1.6,
    );
    expect(b.dashRemaining, 0);
  });
}
