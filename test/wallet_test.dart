import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/widgets/wallet_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
}

const _owner = '11111111-1111-1111-1111-111111111111';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in ['Orbitron', 'PressStart2P']) {
      await (FontLoader(
        font,
      )..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf'))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'guests and unverified account profiles cannot spend earned Scrap',
    () async {
      final preferences = LocalPreferences();
      await preferences.load();
      preferences.profile.scrap = 500;
      expect(
        await preferences.buyCosmetic('copper'),
        CosmeticPurchase.signInRequired,
      );
      expect(preferences.profile.scrap, 500);
      await preferences.activateProfile(_owner);
      preferences.profile.scrap = 500;
      expect(
        await preferences.buyCosmetic('copper'),
        CosmeticPurchase.signInRequired,
      );
      expect(preferences.profile.scrap, 500);
      expect(preferences.profile.owned.contains('copper'), isFalse);
    },
  );

  test(
    'a cached verified session without a purchase service cannot spend',
    () async {
      final preferences = LocalPreferences();
      await preferences.activateProfile(_owner);
      preferences.spendingAuthorized = () => true;
      preferences.profile.scrap = 150;
      expect(
        await preferences.buyCosmetic('copper'),
        CosmeticPurchase.onlineRequired,
      );
      expect(preferences.profile.scrap, 150);
      expect(preferences.profile.owned.contains('copper'), isFalse);
    },
  );

  test(
    'only the online purchase callback can grant; repeat taps are serialized',
    () async {
      final preferences = LocalPreferences();
      await preferences.activateProfile(_owner);
      preferences.spendingAuthorized = () => true;
      preferences.profile.scrap = 150;
      final response = Completer<CosmeticPurchase>();
      var requests = 0;
      preferences.purchaseOnline = (_) {
        requests++;
        return response.future;
      };
      final first = preferences.buyCosmetic('copper');
      expect(
        await preferences.buyCosmetic('moss'),
        CosmeticPurchase.unavailable,
      );
      expect(preferences.profile.scrap, 150);
      expect(preferences.profile.owned.contains('copper'), isFalse);
      response.complete(CosmeticPurchase.onlineRequired);
      expect(await first, CosmeticPurchase.onlineRequired);
      expect(requests, 1);
      expect(preferences.profile.scrap, 150);
      expect(preferences.profile.owned.contains('copper'), isFalse);
    },
  );

  test('unsaved rewards survive refresh, retry without duplicate grant, and owner changes clear online balance', () async {
    final preferences = LocalPreferences();
    await preferences.activateProfile(_owner);
    preferences.spendingAuthorized = () => true;
    preferences.profile.scrap = 55;
    preferences.updateOnlineScrap(_owner, 99);
    preferences.persistAccountProfile = (_, _) async =>
        throw StateError('disk');
    expect(await preferences.saveProfile(), isFalse);
    await preferences.load();
    expect(preferences.profile.scrap, 55);
    expect(preferences.profileSaveFailed, isTrue);
    expect(
      await preferences.buyCosmetic('copper'),
      CosmeticPurchase.unavailable,
    );
    preferences.persistAccountProfile = null;
    expect(await preferences.saveProfile(), isTrue);
    expect(preferences.profile.scrap, 55);
    await preferences.activateProfile('guest');
    expect(preferences.profile.scrap, 0);
    expect(preferences.onlineScrap, isNull);
    preferences.updateOnlineScrap(_owner, 999);
    expect(preferences.onlineScrap, isNull);
  });

  test(
    'restored account source is not overwritten by stale preference mirror',
    () async {
      final preferences = LocalPreferences();
      await preferences.activateProfile(_owner);
      preferences.spendingAuthorized = () => true;
      preferences.profile.scrap = 80;
      await preferences.saveProfile();
      final store = await SharedPreferences.getInstance();
      final stale = preferences.profile.toJson()..['scrap'] = 1;
      await store.setString('profile.account.$_owner', jsonEncode(stale));
      preferences.persistAccountProfile = (_, _) async {};
      await preferences.load();
      expect(preferences.profile.scrap, 80);
    },
  );

  testWidgets(
    'wallet reacts to grants and explains unavailable Credits without checkout',
    (tester) async {
      final preferences = LocalPreferences();
      await preferences.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
          child: MaterialApp(
            home: Scaffold(body: WalletBar(preferences: preferences)),
          ),
        ),
      );
      expect(find.text('0'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      preferences.profile.scrap = 1240;
      await preferences.saveProfile();
      await tester.pump();
      expect(find.text('1,240'), findsOneWidget);
      await tester.tap(find.text('CREDITS'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Not available yet.'), findsOneWidget);
      expect(find.text('Buy'), findsNothing);
    },
  );

  testWidgets(
    'wallet preserves readable values and safe edges on small/large text layouts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final preferences = LocalPreferences();
      await preferences.load();
      preferences.profile.scrap = 1234567890;
      for (final size in [
        const Size(320, 568),
        const Size(844, 390),
        const Size(1200, 800),
      ]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SafeArea(
                    minimum: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        RepaintBoundary(
                          key: const Key('wallet-capture'),
                          child: WalletBar(preferences: preferences),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text('1,234,567,890'), findsOneWidget);
          final rect = tester.getRect(find.byType(WalletBar));
          expect(rect.left, greaterThanOrEqualTo(16));
          expect(rect.right, lessThanOrEqualTo(size.width - 16));
        }
      }
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('wallet-capture')),
        );
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/test-previews').create(recursive: true);
        await File('build/test-previews/wallet.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    },
  );
}
