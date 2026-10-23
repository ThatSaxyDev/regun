import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/utils/soloud_play.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/notifiers/game_notifier.dart';
import 'package:regun/widgets/run_results_panel.dart';
import 'package:regun/widgets/wallet_bar.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
}

void main() {
  setUpAll(() async {
    for (final font in ['PressStart2P', 'Orbitron']) {
      await (FontLoader(
        font,
      )..addFont(rootBundle.load('assets/fonts/$font-Regular.ttf'))).load();
    }
  });
  for (final viewport in [
    const Size(844, 390),
    const Size(932, 430),
    const Size(1200, 600),
    const Size(568, 320),
    const Size(390, 844),
  ]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'results use landscape space and pin actions at $viewport / $scale',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var restarts = 0, exits = 0;
          final state = GameState().copyWith(
            survivalSeconds: 57,
            kills: 52,
            score: 709,
            causeOfDeath: 'Mummy strike',
            ranks: {for (final p in PowerUp.values.take(22)) p: 8},
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: viewport,
                    textScaler: TextScaler.linear(scale),
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 21),
                  ),
                  child: Scaffold(
                    body: RepaintBoundary(
                      key: const Key('results-capture'),
                      child: RunResultsPanel(
                        state: state,
                        earnedScrap: 5,
                        scrapBreakdown:
                            'Salvage 0 / Kills 5 / Bosses 0 / Survival 0',
                        record: 'ASSISTED BEST 10781 / LONGEST 7:36',
                        nextGoal: 'Rail Lance / 6 / 7 boss victories',
                        unlocks: const ['A new survivor'],
                        onRestart: () => restarts++,
                        onMenu: () => exits++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('RESTART').hitTestable(), findsOneWidget);
          expect(find.text('MENU').hitTestable(), findsOneWidget);
          final title = tester.getRect(find.text('END OF THE LINE'));
          final wallet = tester.getRect(find.byType(WalletBar));
          if (viewport.width >= 844 && scale == 1) {
            expect(wallet.left, greaterThan(title.right));
            expect((wallet.center.dy - title.center.dy).abs(), lessThan(3));
            expect(find.byType(SingleChildScrollView), findsNothing);
            await tester.tap(find.byTooltip('Next build page'));
            await tester.pumpAndSettle();
            expect(find.byTooltip('Previous build page'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(
                  find.byKey(const Key('results-capture')),
                )
                .toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              'build/test-previews/results-${viewport.width.toInt()}-$scale.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
          await tester.tap(find.text('RESTART'));
          await tester.tap(find.text('MENU'));
          expect(restarts, 1);
          expect(exits, 1);
        },
      );
    }
  }
}
