import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/services/player_registry.dart';

class Secrets implements RegistrySecrets {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String source) async {
    value = source;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'guest ID is stable offline and failed reports retain the latest outbox',
    () async {
      final secrets = Secrets();
      final first = PlayerRegistry(
        secrets: secrets,
        endpoint: Uri.parse('https://example.test'),
        client: () => MockClient((_) async => http.Response('{}', 503)),
      );
      await first.initialize();
      final name = first.temporaryName;
      expect(name, startsWith('Guest-'));
      await first.record('guest', {
        'totalKills': 10,
        'settledRuns': ['a'],
      });
      await first.refresh(force: true);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(
          prefs.getString('regun.stats.outbox.v1')!,
        )['guest']['stats']['totalKills'],
        10,
      );
      final restored = PlayerRegistry(
        secrets: secrets,
        endpoint: Uri.parse('https://example.test'),
        client: () => MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), false);
          final packet = jsonDecode(request.body);
          expect(packet['stats']['totalKills'], 10);
          expect(packet['sequence'], 1);
          return http.Response('{"ok":true}', 200);
        }),
      );
      await restored.initialize();
      expect(restored.temporaryName, name);
      await restored.refresh(force: true);
      expect(jsonDecode(prefs.getString('regun.stats.outbox.v1')!), isEmpty);
    },
  );
  test(
    'a late acknowledgement cannot delete a newer cumulative report',
    () async {
      final pending = Completer<http.Response>(), secrets = Secrets();
      var requests = 0;
      final registry = PlayerRegistry(
        secrets: secrets,
        endpoint: Uri.parse('https://example.test'),
        client: () => MockClient((request) async {
          requests++;
          if (requests == 1) return pending.future;
          expect(jsonDecode(request.body)['stats']['totalKills'], 20);
          return http.Response('{"ok":true}', 200);
        }),
      );
      await registry.record('guest', {'totalKills': 10});
      final first = registry.refresh(force: true);
      await registry.record('guest', {'totalKills': 20});
      pending.complete(http.Response('{"ok":true}', 200));
      await first;
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(
          prefs.getString('regun.stats.outbox.v1')!,
        )['guest']['stats']['totalKills'],
        20,
      );
      await registry.refresh(force: true);
      expect(jsonDecode(prefs.getString('regun.stats.outbox.v1')!), isEmpty);
    },
  );
}
