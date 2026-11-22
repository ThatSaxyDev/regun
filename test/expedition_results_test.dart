import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/systems/expedition.dart';
import 'package:regun/utils/soloud_play.dart';
import 'package:regun/widgets/expedition_results.dart';

class _Quiet extends SoloudPlay {
  @override
  Future<void> play(String asset) async {}
}

void main() {
  for (final (size, scale) in [
    (const Size(320, 568), 2.0),
    (const Size(568, 320), 1.5),
    (const Size(960, 540), 1.75),
    (const Size(1024, 768), 1.0),
    (const Size(1440, 900), 1.0),
  ]) {
    testWidgets(
      'results reflow and keep the action reachable at $size × $scale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final run = Expedition(17)
          ..region = ExpeditionRegion.relay
          ..phase = ExpeditionPhase.victory;
        var returned = false;
        var retried = false;

        Future<void> show({
          bool saveFailed = false,
          bool saving = false,
        }) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [soloudPlayProvider.overrideWithValue(_Quiet())],
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: ExpeditionResults(
                  run: run,
                  loadout: const Loadout(),
                  elapsed: '24:51',
                  kills: 435,
                  buildEntries: [
                    (name: 'Arc Primer', rank: null),
                    for (var i = 0; i < 18; i++)
                      (name: 'Reinforced ordnance $i', rank: '×3'),
                  ],
                  threatUnlocked: true,
                  saving: saving,
                  saveFailed: saveFailed,
                  onReturn: () => returned = true,
                  onRetrySave: () => retried = true,
                ),
              ),
            ),
          );
          await tester.pump();
        }

        await show(saving: true);
        expect(find.text('EXPEDITION COMPLETE'), findsOneWidget);
        expect(find.text('Saving results…'), findsOneWidget);
        await tester.tap(find.text('RETURN TO OUTPOST'));
        expect(returned, isFalse);
        expect(tester.takeException(), isNull);

        await show(saveFailed: true);
        expect(find.text('RETRY SAVE').hitTestable(), findsOneWidget);
        await tester.tap(find.text('RETRY SAVE'));
        expect(retried, isTrue);
        expect(tester.takeException(), isNull);

        run.phase = ExpeditionPhase.defeat;
        await show();
        expect(find.text('EXPEDITION LOST'), findsOneWidget);
        expect(find.text('RETURN TO OUTPOST').hitTestable(), findsOneWidget);
        await tester.tap(find.text('RETURN TO OUTPOST'));
        expect(returned, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
