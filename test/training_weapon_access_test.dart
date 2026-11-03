import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/widgets/training_weapon_browser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
}

class _FailingPreferences extends LocalPreferences {
  @override
  Future<bool> saveProfile({
    PlayerProfile? next,
    bool notifyAccount = true,
  }) async => false;
}

class _Browser extends StatelessWidget {
  const _Browser(this.preferences);
  final LocalPreferences preferences;
  @override
  Widget build(BuildContext context) => TrainingWeaponBrowser(
    preferences: preferences,
    builder: (weapons) => Column(
      children: [
        for (final weapon in weapons)
          Text(weapon.title, key: ValueKey('equip-${weapon.name}')),
      ],
    ),
  );
}

void main() {
  setUpAll(() async {
    for (final font in ['PressStart2P', 'Orbitron']) {
      await (FontLoader(
        font,
      )..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf'))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> show(WidgetTester tester, LocalPreferences prefs) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RepaintBoundary(
                  key: const Key('capture'),
                  child: _Browser(prefs),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets(
    'defaults to earned weapons; previews and pins locked unlock without granting it',
    (tester) async {
      final prefs = LocalPreferences();
      await prefs.load();
      prefs.profile.scrap = 77;
      await show(tester, prefs);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('equip-shotgun')), findsOneWidget);
      expect(find.byKey(const ValueKey('equip-railLance')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('training-locked-weapons')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('equip-shotgun')), findsNothing);
      expect(find.byKey(const ValueKey('equip-railLance')), findsNothing);
      final rail = find.byKey(const ValueKey('training-locked-railLance'));
      await tester.ensureVisible(rail);
      await tester.tap(rail);
      await tester.pumpAndSettle();
      expect(find.text('Rail Lance / LOCKED'), findsOneWidget);
      expect(find.text('Earn it: 0 / 7 boss victories'), findsOneWidget);
      final pin = find.byKey(const Key('training-pin-weapon-goal'));
      await tester.ensureVisible(pin);
      await tester.tap(pin);
      await tester.pumpAndSettle();
      expect(prefs.profile.pinnedGoal, 'railLance');
      expect(prefs.profile.weaponUnlocked(WeaponType.railLance), isFalse);
      expect(prefs.profile.scrap, 77);
      expect(prefs.profile.challenges, isEmpty);
      final restored = LocalPreferences();
      await restored.load();
      expect(restored.profile.pinnedGoal, 'railLance');
      await tester.runAsync(() async {
        final image = await tester
            .renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('capture')),
            )
            .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/test-previews/training-weapon-goal.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      await tester.ensureVisible(
        find.byKey(const ValueKey('training-your-weapons')),
      );
      await tester.tap(find.byKey(const ValueKey('training-your-weapons')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('equip-railLance')), findsNothing);
      expect(find.text('Rail Lance / LOCKED'), findsNothing);
      expect(find.byKey(const ValueKey('equip-shotgun')), findsOneWidget);
    },
  );

  testWidgets(
    'Carbine pins the training goal; all-earned profile has a truthful empty locked group',
    (tester) async {
      final prefs = LocalPreferences();
      await prefs.load();
      await show(tester, prefs);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('training-locked-weapons')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('training-locked-carbine')));
      await tester.pumpAndSettle();
      final pin = find.byKey(const Key('training-pin-weapon-goal'));
      await tester.ensureVisible(pin);
      await tester.tap(pin);
      await tester.pumpAndSettle();
      expect(prefs.profile.pinnedGoal, 'training');
      prefs.profile = PlayerProfile(
        challenges: WeaponType.values
            .map((w) => w == WeaponType.carbine ? 'training' : w.name)
            .toSet(),
        totalBossVictories: 100,
        ownedWeapons: WeaponType.values.map((w) => w.name).toSet(),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('All weapons earned. Find them in Your weapons.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('training-pin-weapon-goal')), findsNothing);
    },
  );

  testWidgets('failed goal saving does not pretend it succeeded', (
    tester,
  ) async {
    final prefs = _FailingPreferences();
    await prefs.load();
    await show(tester, prefs);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('training-locked-weapons')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('training-locked-carbine')));
    await tester.pumpAndSettle();
    final pin = find.byKey(const Key('training-pin-weapon-goal'));
    await tester.ensureVisible(pin);
    await tester.tap(pin);
    await tester.pumpAndSettle();
    expect(prefs.profile.pinnedGoal, isNull);
    expect(find.text('Could not save your goal. Try again.'), findsOneWidget);
  });
}
