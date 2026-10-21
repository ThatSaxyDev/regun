import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spacetimedb/spacetimedb.dart';
import 'package:regun/multiplayer/online_session.dart';
import 'package:regun/widgets/online_arena.dart';
import 'package:regun/presentation/regun_art.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native authoritative room combat and scene transport', (
    tester,
  ) async {
    final a = OnlineSession(tokens: InMemoryTokenStore()),
        b = OnlineSession(tokens: InMemoryTokenStore());
    Future<void> until(bool Function() check, String label) async {
      final end = DateTime.now().add(const Duration(seconds: 15));
      while (!check()) {
        if (DateTime.now().isAfter(end)) throw StateError(label);
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    }

    await tester.runAsync(() async {
      await RegunArt.shared.load();
      await a.connect();
      await b.connect();
      expect(a.combatAvailable, true);
      await a.create(
        name: 'Simulator',
        mode: 'coop',
        teamSize: 0,
        map: 'breach',
      );
      await until(() => a.room != null, 'create');
      await b.join(a.room!.code, 'Test partner');
      await until(
        () =>
            a.members.length == 2 &&
            a.fighters.length == 2 &&
            a.fighters.values.every((f) => f.enabled),
        'attach',
      );
      await a.chooseLoadout('carbine', 'rook');
      await b.chooseLoadout('arcCaster', 'warden');
      await a.ready();
      await b.ready();
      await until(() => a.canStart, 'ready');
      await a.start();
      await until(() => a.controlsEnabled && b.controlsEnabled, 'start');
    });
    final listener = a.changes.stream.listen((_) {});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: OnlineArena(session: a)),
      ),
    );
    await tester.runAsync(() async {
      a.moveX = .4;
      a.firing = true;
      b.moveY = .3;
      await until(() => a.scene.any((e) => e.kind == 'enemy'), 'enemy scene');
      await until(() => (a.gun?.shots ?? 0) > 0, 'server weapon');
      a.neutral();
      b.neutral();
      await a.suspend();
      await a.resume();
      await until(
        () => a.connected && a.gun?.enabled == true,
        'native combat reconnect',
      );
      final file = File(
        '${(await getApplicationDocumentsDirectory()).path}/regun-online-combat.json',
      );
      await file.writeAsString(
        jsonEncode({
          'status': 'passed',
          'platform': Platform.operatingSystem,
          'checks': [
            'native-combat-schema',
            'two-loadouts',
            'server-shots',
            'enemy-scene',
            'reconnect',
          ],
          'at': DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await listener.cancel();
    await tester.runAsync(() async {
      await a.leave();
      await b.leave();
      await a.close();
      await b.close();
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}
