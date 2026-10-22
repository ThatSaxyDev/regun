import 'package:flutter_test/flutter_test.dart';
import 'package:regun/multiplayer/movement_prediction.dart';

final open = MotionMap({
  'bounds': [-1000, -700, 1000, 700],
  'obstacles': [],
});
Map<String, dynamic> snapshot(
  MotionBody p,
  int ack,
  int tick, {
  int? received,
}) => {
  'x': p.position.dx,
  'y': p.position.dy,
  'dashX': p.dashDirection.dx,
  'dashY': p.dashDirection.dy,
  'dashRemaining': p.dashRemaining,
  'cooldown': p.cooldown,
  'dashSeq': '${p.dashSeq}',
  'ack': '$ack',
  'received': '${received ?? ack}',
  'tick': '$tick',
  'speed': 300,
  'dashCooldown': 1.6,
};
MovementPrediction prediction() => MovementPrediction()
  ..seed(
    'epoch',
    const MotionBody(position: Offset.zero),
    movementSpeed: 300,
    cooldownDuration: 1.6,
  );
void main() {
  test(
    'local motion appears before acknowledgement and never changes server data',
    () {
      final p = prediction();
      final sent = <MotionInput>[];
      p.advance(
        1 / 60,
        const Offset(1, 0),
        const Offset(1, 0),
        0,
        open,
        [],
        sent.add,
      );
      expect(p.position!.dx, closeTo(5, 1e-9));
      expect(sent.length, 1);
      expect(p.acknowledged, 0);
    },
  );
  for (final latency in [.1, .2]) {
    test(
      'delayed simulation acknowledgements replay once at ${latency * 1000}ms',
      () {
        final p = prediction();
        var server = const MotionBody(position: Offset.zero);
        final outgoing = <(double, MotionInput)>[],
            replies = <(double, Map<String, dynamic>)>[];
        var time = 0.0, serverTick = 0;
        var lastAck = 0;
        for (var frame = 0; frame < 240; frame++) {
          time += 1 / 60;
          while (replies.isNotEmpty && replies.first.$1 <= time + 1e-8) {
            p.reconcile('epoch', replies.removeAt(0).$2, open, []);
          }
          final movement = frame < 180 ? const Offset(1, 0) : Offset.zero;
          p.advance(
            1 / 60,
            movement,
            const Offset(1, 0),
            frame >= 60 ? 1 : 0,
            open,
            [],
            (input) => outgoing.add((time + latency / 2, input)),
          );
          if ((frame + 1) % 3 == 0) {
            serverTick++;
            MotionInput? input;
            if (outgoing.isNotEmpty && outgoing.first.$1 <= time + 1e-8) {
              input = outgoing.removeAt(0).$2;
            }
            server = server.step(
              input,
              .05,
              open,
              [],
              speed: 300,
              dashCooldown: 1.6,
            );
            if (input != null) lastAck = input.seq;
            replies.add((
              time + latency / 2,
              snapshot(server, lastAck, serverTick),
            ));
          }
          expect(p.pendingCount, lessThanOrEqualTo(MovementPrediction.limit));
          expect(p.position!.dx.isFinite, isTrue);
        }
        // Stopping and draining acknowledgements converges without reapplying an input.
        for (var i = 0; i < 60; i++) {
          time += .05;
          MotionInput? input;
          if (outgoing.isNotEmpty && outgoing.first.$1 <= time) {
            input = outgoing.removeAt(0).$2;
          }
          server = server.step(
            input,
            .05,
            open,
            [],
            speed: 300,
            dashCooldown: 1.6,
          );
          if (input != null) lastAck = input.seq;
          p.reconcile(
            'epoch',
            snapshot(server, lastAck, ++serverTick),
            open,
            [],
            reducedMotion: true,
          );
        }
        expect(p.position!.dx, closeTo(server.position.dx, 1e-8));
        expect(p.pendingCount, 0);
      },
    );
  }
  test(
    'prediction is bounded when acknowledgements stop; resets on epoch change',
    () {
      final p = prediction();
      for (var i = 0; i < 200; i++) {
        p.advance(
          .016,
          const Offset(1, 0),
          const Offset(1, 0),
          0,
          open,
          [],
          (_) {},
        );
      }
      expect(p.pendingCount, 12);
      expect(p.position!.dx, closeTo(180, 1e-7));
      p.seed(
        'replacement',
        const MotionBody(position: Offset(400, 0)),
        movementSpeed: 270,
        cooldownDuration: .6,
      );
      expect(p.pendingCount, 0);
      expect(p.position, const Offset(400, 0));
      p.reconcile(
        'epoch',
        snapshot(const MotionBody(position: Offset(-300, 0)), 10, 99),
        open,
        [],
      );
      expect(p.position, const Offset(400, 0));
    },
  );
  test('reordered and duplicate acknowledgements cannot rewind state', () {
    final p = prediction();
    p.reconcile(
      'epoch',
      snapshot(const MotionBody(position: Offset(30, 0)), 2, 2),
      open,
      [],
      reducedMotion: true,
    );
    for (final tick in [1, 2]) {
      p.reconcile(
        'epoch',
        snapshot(const MotionBody(position: Offset(-100, 0)), 1, tick),
        open,
        [],
      );
    }
    expect(p.position, const Offset(30, 0));
  });
  test('dash, walls, bodies and speed use matching simulation contracts', () {
    var p = const MotionBody(position: Offset.zero);
    for (var i = 1; i <= 4; i++) {
      p = p.step(
        MotionInput(i, const Offset(1, 0), const Offset(1, 0), 1),
        .05,
        open,
        [],
        speed: 300,
        dashCooldown: 1.6,
      );
    }
    expect(p.position.dx, closeTo(232.5, 1e-8));
    expect(p.cooldown, closeTo(1.4, 1e-8));
    final wall = MotionMap({
      'bounds': [-1000, -700, 1000, 700],
      'obstacles': [
        [80, -200, 100, 200],
      ],
    });
    var blocked = const MotionBody(position: Offset.zero);
    for (var i = 1; i <= 5; i++) {
      blocked = blocked.step(
        MotionInput(i, const Offset(1, 0), const Offset(1, 0), 1),
        .05,
        wall,
        [],
        speed: 300,
        dashCooldown: 1.6,
      );
    }
    expect(blocked.position.dx, 50);
    final occupied = const MotionBody(position: Offset.zero).step(
      const MotionInput(1, Offset(1, 0), Offset(1, 0), 1),
      .05,
      open,
      [const Offset(80, 0)],
      speed: 300,
      dashCooldown: 1.6,
    );
    expect(occupied.position.dx, lessThan(21));
  });
  test('large correction snaps and smaller correction decays without crossing cover', () {
    final p = prediction();
    p.advance(.05, const Offset(1, 0), const Offset(1, 0), 0, open, [], (_) {});
    p.reconcile(
      'epoch',
      snapshot(const MotionBody(position: Offset(-400, 0)), 1, 1),
      open,
      [],
    );
    expect(p.rendered(open, []), const Offset(-400, 0));
    final before = p.rendered(open, [])!;
    p.reconcile(
      'epoch',
      snapshot(const MotionBody(position: Offset(-410, 0)), 1, 2),
      open,
      [],
    );
    expect(p.rendered(open, []), before);
    for (var i = 0; i < 10; i++) {
      p.advance(.016, Offset.zero, const Offset(1, 0), 0, open, [], (_) {});
    }
    expect(p.rendered(open, [])!.dx, closeTo(-410, .3));
  });
  for (final serverWallStep in [.05, .0625]) {
    test(
      'paces to server cadence without filling the prediction horizon at $serverWallStep',
      () {
        final p = prediction();
        final large = MotionMap({
          'bounds': [-100000, -100000, 100000, 100000],
          'obstacles': [],
        });
        var server = const MotionBody(position: Offset.zero);
        final outgoing = <(double, MotionInput)>[];
        final replies = <(double, Map<String, dynamic>)>[];
        final serverQueue = <MotionInput>[];
        var now = 0.0, nextTick = serverWallStep;
        var tick = 0, ack = 0, received = 0, maxPending = 0, stalls = 0;
        for (var frame = 0; frame < 1800; frame++) {
          now += 1 / 60;
          while (replies.isNotEmpty && replies.first.$1 <= now + 1e-8) {
            p.reconcile('epoch', replies.removeAt(0).$2, large, []);
          }
          p.advance(
            1 / 60,
            const Offset(1, 0),
            const Offset(1, 0),
            0,
            large,
            [],
            (input) => outgoing.add((now + .15, input)),
          );
          while (outgoing.isNotEmpty && outgoing.first.$1 <= now + 1e-8) {
            final input = outgoing.removeAt(0).$2;
            serverQueue.add(input);
            received = input.seq;
          }
          while (nextTick <= now + 1e-8) {
            final command = serverQueue.isEmpty
                ? null
                : serverQueue.removeAt(0);
            server = server.step(
              command,
              .05,
              large,
              [],
              speed: 300,
              dashCooldown: 1.6,
            );
            if (command != null) ack = command.seq;
            replies.add((
              now + .15,
              {
                ...snapshot(server, ack, ++tick, received: received),
                'commands': List.filled(serverQueue.length, null),
              },
            ));
            nextTick += serverWallStep;
          }
          maxPending = maxPending < p.pendingCount
              ? p.pendingCount
              : maxPending;
          if (p.stalled) stalls++;
        }
        expect(stalls, 0);
        expect(maxPending, lessThan(12));
        expect(serverQueue.length, lessThanOrEqualTo(3));
        if (serverWallStep > .05) {
          expect(p.simulationRate, inInclusiveRange(.65, .9));
        } else {
          // RTT alone is not a reason to slow ordinary movement.
          expect(p.simulationRate, greaterThan(.94));
        }
      },
    );
  }
}
