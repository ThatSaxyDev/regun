import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:regun/widgets/online_match_menu.dart';
import 'package:regun/widgets/game_notice.dart';
import 'package:regun/views/settings_view.dart';
import 'package:regun/views/controls_view.dart';
import 'package:regun/widgets/control_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/models/control_layout.dart';
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/multiplayer/generated/room.dart';
import 'package:regun/presentation/control_art.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/widgets/online_arena.dart';

import 'online_test.dart' show FakeSession, QuietAudio, member, room, id;

class _LeavingSession extends FakeSession {
  bool left = false;
  @override
  Future<void> leave() async {
    left = true;
  }
}

Future<ByteData> _displayPixels(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  setUpAll(() async {
    if (!kIsWeb) await RegunArt.shared.load();
  });
  for (final screen in [const Size(844, 390), const Size(1366, 1024)]) {
    for (final left in [false, true]) {
      for (final floating in [false, true]) {
        testWidgets(
          'online shares solo control skin and aiming-side cluster screen=$screen left=$left floating=$floating',
          (tester) async {
            tester.view.physicalSize = screen;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final old = LocalPreferences.shared.controls;
            addTearDown(() => LocalPreferences.shared.controls = old);
            LocalPreferences.shared.controls = ControlLayout(
              leftHanded: left,
              floating: floating,
              size: 112,
            );
            final controls = LocalPreferences.shared.controls;
            final s = FakeSession()
              ..connected = true
              ..identity = id(1).toHexString
              ..room = room()
              ..members = [member(1)]
              ..match = OnlineMatch({'version': 1, 'phase': 'active'});
            s.room = Room.fromJson(
              room().toJson()
                ..['phase'] = 'active'
                ..['owner'] = id(1),
            );
            s.fighters[s.identity!] = OnlineGun(s.identity!, {
              'health': 6,
              'weapon': 'shotgun',
              'survivor': 'rook',
            });
            await tester.pumpWidget(
              ProviderScope(
                overrides: [soloudPlayProvider.overrideWithValue(QuietAudio())],
                child: MaterialApp(home: OnlineArena(session: s)),
              ),
            );
            await tester.pump(const Duration(milliseconds: 100));
            final sticks = find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is OnlineStickSkin,
            );
            final actions = find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is OnlineActionSkin,
            );
            expect(sticks, findsNWidgets(2));
            expect(actions, findsNWidgets(2));
            expect(
              tester.getSize(sticks.first),
              Size.square(controls.displaySize(screen)),
            );
            expect(
              tester.getSize(actions.first).width,
              closeTo(controls.displayButtonSize(screen), 1e-8),
            );
            final geometry = controls.geometry(screen);
            expect(tester.getCenter(sticks.first), geometry.movement);
            expect(tester.getCenter(sticks.last), geometry.aim);
            final at = floating
                ? geometry.movement + const Offset(0, -18)
                : geometry.movement;
            final move = await tester.startGesture(at, pointer: 1);
            await move.moveBy(Offset(controls.displaySize(screen) / 4, 0));
            await tester.pump();
            expect(s.moveX, greaterThan(.5));
            final aim = await tester.startGesture(geometry.aim, pointer: 2);
            await aim.moveBy(Offset(controls.displaySize(screen) / 4, 0));
            await tester.pump();
            expect(s.firing, isTrue);
            await aim.up();
            final dash = await tester.startGesture(geometry.dash, pointer: 3);
            await tester.pump();
            expect(s.dashes, 1);
            expect(s.moveX, greaterThan(.5));
            await dash.up();
            await move.up();
            await tester.pump();
            expect(s.moveX, 0);
            expect(s.firing, isFalse);
            await tester.pumpWidget(const SizedBox());
            await s.close();
          },
        );
      }
    }
  }
  testWidgets(
    'online arena fills the display while the menu stays in the safe area',
    (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(
        left: 59,
        right: 24,
        bottom: 21,
      );
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final old = LocalPreferences.shared.controls;
      addTearDown(() => LocalPreferences.shared.controls = old);
      final s = FakeSession()
        ..connected = true
        ..identity = id(1).toHexString
        ..room = room()
        ..members = [member(1)]
        ..match = OnlineMatch({'version': 1, 'phase': 'active'});
      s.room = Room.fromJson(
        room().toJson()
          ..['phase'] = 'active'
          ..['owner'] = id(1),
      );
      s.fighters[s.identity!] = OnlineGun(s.identity!, {
        'health': 6,
        'weapon': 'shotgun',
        'survivor': 'rook',
      });
      const display = ValueKey('online display');
      await tester.pumpWidget(
        RepaintBoundary(
          key: display,
          child: ProviderScope(
            overrides: [soloudPlayProvider.overrideWithValue(QuietAudio())],
            child: MaterialApp(home: OnlineArena(session: s)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final pixels = await _displayPixels(tester, display);
      for (final (x, y) in [(0, 0), (843, 0), (0, 389), (843, 389)]) {
        expect(
          pixels.getUint32((y * 844 + x) * 4),
          isNot(0x161b18ff),
          reason: 'Arena should cover display corner ($x, $y)',
        );
      }
      final menu = tester.getRect(find.text('MENU'));
      expect(menu.top, lessThan(60));
      expect(menu.right, lessThan(844 - 24));
      final sticks = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OnlineStickSkin,
      );
      final geometry = LocalPreferences.shared.controls.geometry(
        const Size(844 - 59 - 24, 390 - 21),
      );
      expect(
        tester.getCenter(sticks.first),
        geometry.movement + const Offset(59, 0),
      );
      await tester.tap(find.text('MENU'));
      await tester.pump();
      expect(s.menuOpen, isTrue);
      expect(s.firing, isFalse);
      await tester.tap(find.text('SETTINGS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SettingsView), findsOneWidget);
      await tester.tap(find.text('CONTROLS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ControlsView), findsOneWidget);
      final slider = tester.widget<ControlSlider>(
        find.byWidgetPredicate(
          (w) => w is ControlSlider && w.label == 'Sensitivity',
        ),
      );
      slider.onChanged(1.25);
      await tester.pump();
      expect(LocalPreferences.shared.controls.sensitivity, 1.25);
      expect(s.menuOpen, isTrue);
      expect(s.firing, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await s.close();
    },
  );
  testWidgets('online desktop projection and web touch framing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 540);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final s = FakeSession()
      ..connected = true
      ..identity = id(1).toHexString
      ..room = Room.fromJson(
        room().toJson()
          ..['phase'] = 'active'
          ..['owner'] = id(1),
      )
      ..members = [member(1)]
      ..match = OnlineMatch({'version': 1, 'phase': 'active'});
    addTearDown(s.close);
    s.fighters[s.identity!] = OnlineGun(s.identity!, {
      'health': 6,
      'weapon': 'shotgun',
      'survivor': 'rook',
    });
    const display = ValueKey('desktop online display');
    const background = 0x161b18ff;
    Future<void> mountArena() => tester.pumpWidget(
      RepaintBoundary(
        key: display,
        child: ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(QuietAudio())],
          child: MaterialApp(home: OnlineArena(session: s)),
        ),
      ),
    );
    if (kIsWeb) {
      await tester.runAsync(mountArena);
    } else {
      await mountArena();
    }
    await tester.pump(const Duration(milliseconds: 100));

    final pixels = await _displayPixels(tester, display);
    expect(pixels.getUint32(0), isNot(background));

    tester.view.physicalSize = const Size(1200, 540);
    await tester.pump();
    final widePixels = await _displayPixels(tester, display);
    expect(widePixels.getUint32((270 * 1200 + 10) * 4), background);
    expect(widePixels.getUint32((270 * 1200 + 120) * 4), isNot(background));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    const aimPoint = Offset(780, 270);
    await mouse.addPointer(location: aimPoint);
    await mouse.moveTo(aimPoint);
    expect(s.aimX, closeTo(1, .01));
    expect(s.aimY, closeTo(0, .01));
    expect(s.firing, isFalse);
    await mouse.down(aimPoint);
    expect(s.firing, isTrue);
    await mouse.up();
    expect(s.firing, isFalse);
    await mouse.down(const Offset(10, 270));
    expect(s.firing, isFalse);
    await mouse.up();
    await mouse.removePointer();

    if (kIsWeb) {
      const screen = Size(844, 390);
      tester.view.physicalSize = screen;
      await tester.pump();
      final geometry = LocalPreferences.shared.controls.geometry(screen);
      final touch = await tester.startGesture(geometry.movement);
      await touch.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(s.moveX, greaterThan(.5));
      final touchPixels = await _displayPixels(tester, display);
      for (final (x, y) in [(0, 0), (843, 0), (0, 389), (843, 389)]) {
        expect(touchPixels.getUint32((y * 844 + x) * 4), isNot(background));
      }
      await touch.up();
      expect(s.moveX, 0);
    }
    await tester.pumpWidget(const SizedBox());
  }, variant: const TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets(
    'online leave warns about forfeit and only leaves after confirmation',
    (tester) async {
      final s = _LeavingSession()
        ..connected = true
        ..menuOpen = true
        ..room = Room.fromJson(
          room().toJson()
            ..['mode'] = 'versus'
            ..['owner'] = id(1),
        )
        ..match = OnlineMatch({'version': 1, 'phase': 'active'});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(QuietAudio())],
          child: MaterialApp(
            home: Scaffold(
              body: OnlineMatchMenu(session: s, resume: () {}),
            ),
          ),
        ),
      );
      await tester.tap(find.text('LEAVE (FORFEIT)'));
      await tester.pumpAndSettle();
      expect(find.byType(GameNotice), findsOneWidget);
      expect(find.text('Leaving now forfeits this match.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('run-action-cancel')));
      await tester.pumpAndSettle();
      expect(s.left, isFalse);
      expect(s.menuOpen, isTrue);
      await tester.tap(find.text('LEAVE (FORFEIT)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-action-confirm')));
      await tester.pumpAndSettle();
      expect(s.left, isTrue);
      expect(s.menuOpen, isFalse);
      await tester.pumpWidget(const SizedBox());
      await s.close();
    },
  );
}
