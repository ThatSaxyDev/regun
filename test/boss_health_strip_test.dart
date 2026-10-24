import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/widgets/boss_health_strip.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('paired boss strips stay compact at large text $scale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: Row(
                  children: [
                    Expanded(
                      child: BossHealthStrip(
                        name: 'The Last Marshal',
                        fraction: .5,
                        enraged: true,
                      ),
                    ),
                    Expanded(
                      child: BossHealthStrip(
                        name: 'Chain Magistrate',
                        fraction: .9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(BossHealthStrip).first).height,
        lessThanOrEqualTo(36),
      );
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
      expect(
        find.bySemanticsLabel('The Last Marshal, enraged, 50 percent health'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  }
}
