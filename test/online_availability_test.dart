import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:regun/services/online_availability.dart';

void main() {
  test(
    'unknown starts closed and same installed client follows remote on/off',
    () async {
      var enabled = true;
      final policy = OnlineAvailability(
        client: () => MockClient((request) async {
          expect(request.url.path, '/features');
          expect(request.headers['Cache-Control'], 'no-cache');
          return http.Response(
            jsonEncode({'schemaVersion': 1, 'onlinePlay': enabled}),
            200,
          );
        }),
      );
      addTearDown(policy.dispose);
      expect(policy.enabled, isFalse);
      expect(await policy.refresh(), isTrue);
      enabled = false;
      expect(await policy.refresh(), isFalse);
      expect(policy.state, OnlineAvailabilityState.disabled);
      enabled = true;
      expect(await policy.refresh(), isTrue);
    },
  );

  test(
    'HTTP, malformed and stale-enabled failures close entry and can recover',
    () async {
      var response = http.Response(
        '{"schemaVersion":1,"onlinePlay":true}',
        200,
      );
      final policy = OnlineAvailability(
        client: () => MockClient((_) async => response),
      );
      addTearDown(policy.dispose);
      for (final bad in [
        http.Response('offline', 503),
        http.Response('not json', 200),
        http.Response('{"schemaVersion":1,"onlinePlay":"true"}', 200),
        http.Response('{"schemaVersion":2,"onlinePlay":true}', 200),
        http.Response('x' * 4097, 200),
      ]) {
        response = http.Response('{"schemaVersion":1,"onlinePlay":true}', 200);
        expect(await policy.refresh(), isTrue);
        response = bad;
        expect(await policy.refresh(), isFalse);
        expect(policy.state, OnlineAvailabilityState.unavailable);
      }
    },
  );

  test(
    'concurrent checks coalesce and disposal ignores late responses',
    () async {
      var calls = 0;
      final pending = Completer<http.Response>();
      final policy = OnlineAvailability(
        client: () => MockClient((_) {
          calls++;
          return pending.future;
        }),
      );
      final first = policy.refresh(), second = policy.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(identical(first, second), isTrue);
      policy.dispose();
      pending.complete(
        http.Response('{"schemaVersion":1,"onlinePlay":true}', 200),
      );
      expect(await first, isFalse);
    },
  );

  testWidgets('a stalled policy request times out without enabling Online', (tester) async {
    final pending = Completer<http.Response>();
    final policy = OnlineAvailability(client: () => MockClient((_) => pending.future));
    final request = policy.refresh();
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(await request, isFalse);
    expect(policy.state, OnlineAvailabilityState.unavailable);
    policy.dispose();
  });

  test('transport failures never enable a cached policy', () async {
    final policy = OnlineAvailability(
      client: () =>
          MockClient((_) async => throw http.ClientException('offline')),
    );
    addTearDown(policy.dispose);
    expect(await policy.refresh(), isFalse);
  });
}
