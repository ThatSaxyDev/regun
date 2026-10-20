import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../tool/multiplayer/smoke.dart' as smoke;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native hosted co-op and 1v1/2v2/3v3 transport', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Checking multiplayer connection…')),
        ),
      ),
    );
    await tester.runAsync(() async {
      final file = File(
        '${(await getApplicationDocumentsDirectory()).path}/regun-online-smoke.json',
      );
      final report = <String, Object?>{
        'status': 'started',
        'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'platform': Platform.operatingSystem,
      };
      Future<void> save() =>
          file.writeAsString(jsonEncode(report), flush: true);
      await save();
      try {
        await smoke.main();
        report['status'] = 'passed';
        report['checks'] = [
          'coop-room-movement-ping-reconnect',
          'versus-1v1',
          'versus-2v2',
          'versus-3v3',
        ];
        await save();
      } catch (error) {
        report['status'] = 'failed';
        report['error'] = error.toString();
        await save();
        rethrow;
      }
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}
