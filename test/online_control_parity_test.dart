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

void main() {
  setUpAll(() async {
    await RegunArt.shared.load();
  });
  for (final left in [false, true]) {
    for (final floating in [false, true]) {
      testWidgets(
        'online shares solo control skin and aiming-side cluster left=$left floating=$floating',
        (tester) async {
          tester.view.physicalSize = const Size(844, 390);
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
          expect(tester.getSize(sticks.first), const Size.square(112));
          expect(
            tester.getSize(actions.first).width,
            closeTo(controls.buttonSize, 1e-8),
          );
          final geometry = controls.geometry(const Size(844, 390));
          expect(tester.getCenter(sticks.first), geometry.movement);
          expect(tester.getCenter(sticks.last), geometry.aim);
          final at = floating
              ? geometry.movement + const Offset(0, -18)
              : geometry.movement;
          final move = await tester.startGesture(at, pointer: 1);
          await move.moveBy(const Offset(24, 0));
          await tester.pump();
          expect(s.moveX, greaterThan(.5));
          final aim = await tester.startGesture(geometry.aim, pointer: 2);
          await aim.moveBy(const Offset(24, 0));
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
