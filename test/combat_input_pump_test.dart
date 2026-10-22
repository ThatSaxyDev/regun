import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/multiplayer/combat_input_pump.dart';

void main() {
  test('fire/release/reload do not wait for earlier round trips', () async {
    final p = CombatInputPump(), requests = <(bool, int)>[];
    final replies = <Completer<bool>>[];
    Future<bool> send(bool held, int reload) {
      requests.add((held, reload));
      final c = Completer<bool>();
      replies.add(c);
      return c.future;
    }

    p.tick(0, true, 0, send);
    p.tick(.05, false, 0, send);
    p.tick(.1, false, 1, send);
    expect(requests, [(true, 0), (false, 0), (false, 1)]);
    expect(p.inFlight, 3);
    for (final r in replies) {
      r.complete(true);
    }
    await Future<void>.delayed(Duration.zero);
    expect(p.inFlight, 0);
  });
  test(
    'steady state uses keepalive with bounded outstanding requests',
    () async {
      final p = CombatInputPump(), replies = <Completer<bool>>[];
      Future<bool> send(bool _, int __) {
        final c = Completer<bool>();
        replies.add(c);
        return c.future;
      }

      for (var i = 0; i < 100; i++) {
        p.tick(i * .05, true, 0, send);
      }
      expect(replies.length, 6);
      expect(p.inFlight, 6);
      p.reset();
      p.tick(5.1, false, 0, send);
      for (final c in replies.take(6)) {
        c.complete(false);
      }
      await Future<void>.delayed(Duration.zero);
      expect(
        p.inFlight,
        1,
      ); // old epoch completions cannot change new ownership.
      replies.last.complete(true);
    },
  );
  test(
    'a rejected edge retries latest intent without replaying old reload',
    () async {
      final p = CombatInputPump(), requests = <(bool, int)>[];
      Future<bool> send(bool held, int reload) async {
        requests.add((held, reload));
        return requests.length != 1;
      }

      p.tick(0, true, 0, send);
      await Future<void>.delayed(Duration.zero);
      p.tick(.05, false, 1, send);
      await Future<void>.delayed(Duration.zero);
      p.tick(.1, false, 1, send);
      expect(requests, [(true, 0), (false, 1)]);
    },
  );
  test(
    'release/repress burst is sent even if held state was sampled unchanged',
    () {
      final p = CombatInputPump();
      var calls = 0;
      Future<bool> send(bool held, int reload) async {
        calls++;
        return true;
      }

      p.tick(0, true, 0, send, burst: 1);
      p.tick(.05, true, 0, send, burst: 2);
      expect(calls, 2);
    },
  );
}
