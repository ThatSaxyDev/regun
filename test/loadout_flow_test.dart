import 'package:regun/widgets/wallet_bar.dart';
import 'package:regun/widgets/survivor_portrait.dart';
import 'package:regun/data/loadout.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalPreferences.shared.load();
    await LocalPreferences.shared.resetProgress();
    await RegunArt.shared.load();
    for (final family in ['PressStart2P', 'Orbitron']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))).load();
    }
  });

  Future<void> show(
    WidgetTester tester, {
    bool training = true,
    Size size = const Size(844, 390),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
        child: MaterialApp(
          key: UniqueKey(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
              padding: EdgeInsets.fromLTRB(
                size.width > size.height ? 24 : 0,
                0,
                size.width > size.height ? 24 : 0,
                21,
              ),
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const Key('loadout-capture'),
            child: LoadoutView(training: training),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final arena in ['breach', 'foundry']) {
        await precacheImage(
          AssetImage('assets/art/arenas/${arena}_floor.png'),
          tester.element(find.byType(LoadoutView)),
        );
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String id) async {
    if (id.startsWith('weapon-') &&
        find
            .byKey(const ValueKey('training-your-weapons'))
            .evaluate()
            .isNotEmpty) {
      final gun = WeaponType.values.firstWhere((w) => 'weapon-${w.name}' == id);
      final filter = find.byKey(
        ValueKey(
          LocalPreferences.shared.profile.weaponUnlocked(gun)
              ? 'training-your-weapons'
              : 'training-try-locked',
        ),
      );
      await tester.ensureVisible(filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
    }
    final option = find.byKey(ValueKey('loadout-$id'));
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('loadout-capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/loadout-$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'Training previews and pins a locked gun without unlocking normal play',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await LocalPreferences.shared.resetProgress();
      });
      await show(tester);
      await tester.tap(find.text('WEAPON'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('loadout-weapon-shotgun')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('loadout-weapon-railLance')),
        findsNothing,
      );
      await select(tester, 'weapon-railLance');
      await tester.tap(find.text('ARENA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WEAPON'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('loadout-weapon-railLance')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('loadout-weapon-shotgun')),
        findsNothing,
      );
      expect(find.text('Rail Lance / TRAINING ONLY'), findsOneWidget);
      expect(find.text('Unlock: 0 / 7 boss victories'), findsOneWidget);
      final pin = find.byKey(const Key('training-pin-weapon-goal'));
      await tester.ensureVisible(pin);
      await tester.runAsync(() async {
        await tester.tap(pin);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(LocalPreferences.shared.profile.pinnedGoal, 'railLance');
      expect(
        LocalPreferences.shared.profile.weaponUnlocked(WeaponType.railLance),
        isFalse,
      );
      expect(
        LocalPreferences.shared.profile.preferredWeapon,
        WeaponType.shotgun,
      );
      expect(find.text('START').hitTestable(), findsOneWidget);
      await tester.runAsync(() async {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('loadout-weapon-railLance'))),
        alignment: 0,
      );
      await tester.pump();
      await capture(tester, 'training-locked-goal');
      await show(tester, training: false);
      expect(find.byKey(const ValueKey('training-try-locked')), findsNothing);
      await tester.tap(find.text('WEAPON'));
      await tester.pumpAndSettle();
      await select(tester, 'weapon-railLance');
      expect(
        tester.widget<Text>(find.byKey(const Key('loadout-summary'))).data,
        contains(WeaponType.shotgun.title),
      );
      expect(
        LocalPreferences.shared.profile.weaponUnlocked(WeaponType.railLance),
        isFalse,
      );
      // Finish asynchronous atlas callbacks before leaving this test's clock.
      await tester.pumpWidget(const SizedBox.shrink());
      for (var frame = 0; frame < 3; frame++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
      }
    },
  );

  testWidgets(
    'all ten survivor identities retain readable details and pinned controls',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester);
      final wallet = tester.getRect(find.byType(WalletBar));
      final title = tester.getRect(find.text('TRAINING'));
      expect(find.text('SCRAP'), findsNothing);
      expect(find.text('CREDITS'), findsNothing);
      expect(wallet.left, greaterThan(title.right));
      expect(wallet.center.dy, closeTo(title.center.dy, 1));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      for (final c in CharacterType.values) {
        await select(tester, 'survivor-${c.name}');
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('loadout-summary')), findsOneWidget);
        expect(tester.getRect(find.byType(WalletBar)), wallet);
        expect(find.text('START').hitTestable(), findsOneWidget);
        expect(find.textContaining(c.role), findsOneWidget);
        if (c == CharacterType.flint || c == CharacterType.harrow) {
          expect(RegunArt.shared.contains('characters/${c.name}'), isTrue);
          expect(
            find.descendant(
              of: find.byWidgetPredicate(
                (w) => w is SurvivorPortrait && w.character == c,
              ),
              matching: find.byType(CustomPaint),
            ),
            findsNWidgets(2),
          );
          await capture(tester, 'ten-${c.name}');
        }
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('WEAPON'));
      await tester.pumpAndSettle();
      for (final gun in WeaponType.values) {
        await select(tester, 'weapon-${gun.name}');
        await tester.runAsync(() async {
          await RegunArt.shared.acquire(gun.atlasName);
        });
        await tester.pumpAndSettle();
        final held = find.byWidgetPredicate(
          (w) => w is SurvivorPortrait && w.weapon == gun,
        );
        expect(held, findsOneWidget);
        expect(
          find.descendant(of: held, matching: find.byType(CustomPaint)),
          findsOneWidget,
        );
        if (gun == WeaponType.anchorEngine) {
          await capture(tester, 'held-anchor');
        }
        RegunArt.shared.release(gun.atlasName);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'catalogs retain the assembled kit and pinned navigation while browsing',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester);
      await capture(tester, 'survivor');
      final tabs = tester.getRect(find.text('ARENA'));
      final start = tester.getRect(find.text('START'));
      final preview = tester.getRect(
        find.byKey(const Key('loadout-kit-preview')),
      );
      await select(tester, 'survivor-warden');
      await tester.tap(find.text('WEAPON'));
      await tester.pumpAndSettle();
      await select(tester, 'weapon-revolver');
      await capture(tester, 'weapon');
      // Verify actual painted pixels, not just a mounted thumbnail placeholder.
      final thumbnail = tester
          .getRect(find.byKey(const ValueKey('loadout-art-revolver')))
          .deflate(2);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('loadout-capture')),
      );
      final brightPixels = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final pixels = bytes!.buffer.asUint8List();
        var count = 0;
        for (var y = thumbnail.top.ceil(); y < thumbnail.bottom.floor(); y++) {
          for (
            var x = thumbnail.left.ceil();
            x < thumbnail.right.floor();
            x++
          ) {
            final offset = (y * image.width + x) * 4;
            if (pixels[offset] > 140 && pixels[offset + 1] > 100) count++;
          }
        }
        image.dispose();
        return count;
      });
      expect(
        brightPixels,
        greaterThan(10),
        reason: 'The equipped weapon thumbnail must paint.',
      );

      await tester.tap(find.text('ARENA'));
      await tester.pumpAndSettle();
      await select(tester, 'arena-foundry');
      await capture(tester, 'arena');
      await tester.tap(find.text('SURVIVOR'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('loadout-survivor-warden')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Warden / Revolver / The Foundry'), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -800),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('ARENA')), tabs);
      expect(tester.getRect(find.text('START')), start);
      expect(
        tester.getRect(find.byKey(const Key('loadout-kit-preview'))),
        preview,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('normal unlocks remain enforced across all three catalogs', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await show(tester, training: false);
    await select(tester, 'survivor-scrapper');
    await tester.tap(find.text('WEAPON'));
    await tester.pumpAndSettle();
    await select(tester, 'weapon-arcCaster');
    await tester.tap(find.text('ARENA'));
    await tester.pumpAndSettle();
    await select(tester, 'arena-foundry');
    expect(find.text('Rook / Pump Shotgun / The Breach'), findsOneWidget);
    expect(find.text('Locked / Complete a cycle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'catalog navigation and Start stay visible at compact and enlarged sizes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(568, 320),
        const Size(844, 390),
        const Size(390, 844),
      ]) {
        for (final scale in [1.0, 1.5]) {
          await show(tester, size: size, scale: scale);
          for (final tab in ['SURVIVOR', 'WEAPON', 'ARENA']) {
            await tester.tap(find.text(tab));
            await tester.pumpAndSettle();
            await tester.drag(
              find.byType(SingleChildScrollView),
              const Offset(0, -2000),
            );
            await tester.pumpAndSettle();
            for (final label in [
              'SURVIVOR',
              'WEAPON',
              'ARENA',
              'BACK',
              'START',
            ]) {
              expect(
                find.text(label).hitTestable(),
                findsOneWidget,
                reason: '$size / $scale / $label',
              );
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$size / $scale / $tab',
            );
          }
        }
      }
    },
  );
}
