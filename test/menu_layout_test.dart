import 'package:regun/widgets/wallet_bar.dart';
import 'package:regun/views/controls_view.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/views/collection_view.dart';
import 'package:regun/views/loadout_view.dart';
import 'package:regun/views/settings_view.dart';
import 'package:regun/widgets/menu_layout.dart';
import 'package:regun/utils/soloud_play.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
}

void main() {
  testWidgets(
      'collection rows align, all tabs fit, and the final card clears the edge',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final font in [
        ('PressStart2P', 'PressStart2P-Regular.ttf'),
        ('Orbitron', 'Orbitron-Bold.ttf')
      ]) {
        await (FontLoader(font.$1)
              ..addFont(rootBundle.load('assets/fonts/${font.$2}')))
            .load();
      }
      await RegunArt.shared.load();
    });
    const capture = Key('collection-capture');
    await tester.pumpWidget(ProviderScope(
        overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.fromLTRB(47, 0, 47, 21)),
                child: child!),
            home:
                const RepaintBoundary(key: capture, child: CollectionView()))));
    await tester.pumpAndSettle();
    final wallet = tester.getRect(find.byType(WalletBar));
    final title = tester.getRect(find.text('COLLECTION'));
    expect(find.text('SCRAP'), findsNothing);
    expect(find.text('CREDITS'), findsNothing);
    expect(wallet.left, greaterThan(title.right));
    expect(wallet.center.dy, closeTo(title.center.dy, 1));
    expect(wallet.right, lessThan(tester.getRect(find.text('BACK')).left));
    for (final label in [
      'UPGRADES',
      'FUSIONS',
      'ENEMIES',
      'CHALLENGES',
      'STYLE',
      'ABOUT'
    ]) {
      expect(find.text(label).hitTestable(), findsOneWidget);
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThan(47));
      expect(rect.right, lessThan(797));
    }
    await tester.tap(find.text('FUSIONS'));
    await tester.pumpAndSettle();
    final first =
        tester.getRect(find.byKey(const ValueKey('collection-card-Firebreak')));
    final second = tester
        .getRect(find.byKey(const ValueKey('collection-card-Storm Circuit')));
    expect(first.top, second.top);
    expect(first.bottom, second.bottom);
    expect(first.width, closeTo(second.width, .01));
    expect(first.left, greaterThan(47));
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/test-previews').create(recursive: true);
      await File('build/test-previews/collection-alignment.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    final back = tester.getRect(find.text('BACK'));
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    final last = tester
        .getRect(find.byKey(const ValueKey('collection-card-Hunter Swarm')));
    expect(last.bottom, lessThan(390 - 21 - 16));
    expect(tester.getRect(find.text('BACK')), back);
    expect(tester.getRect(find.byType(WalletBar)), wallet);
    // Switching from the bottom of a long section starts the next section at its top.
    await tester.tap(find.text('ABOUT'));
    await tester.pumpAndSettle();
    expect(find.text('REGUN').hitTestable(), findsOneWidget);
    for (final tab in ['UPGRADES', 'ENEMIES', 'CHALLENGES', 'STYLE']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(find.text('BACK').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull, reason: tab);
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'menu pages fit compact, notched, portrait and enlarged-text layouts',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var index = 0;
    for (final size in [
      const Size(568, 320),
      const Size(844, 390),
      const Size(390, 844)
    ]) {
      tester.view.physicalSize = size;
      for (final scale in [1.0, 1.5]) {
        for (final page in [
          const CollectionView(),
          const LoadoutView(training: true),
          const SettingsView(),
          const ControlsView()
        ]) {
          await tester.pumpWidget(ProviderScope(
              overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
              child: MaterialApp(
                  key: ValueKey(index++),
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(scale),
                          disableAnimations: true,
                          padding: EdgeInsets.only(
                              left: size.width > size.height ? 24 : 0,
                              right: size.width > size.height ? 24 : 0,
                              bottom: 21)),
                      child: child!),
                  home: page)));
          await tester.pumpAndSettle();
          expect(find.text('BACK').hitTestable(), findsOneWidget);
          expect(find.byType(MenuScrollBody), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: '$size, $scale, ${page.runtimeType}');
          await tester.drag(
              find.byType(SingleChildScrollView), const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(find.text('BACK').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}
