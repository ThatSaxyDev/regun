import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/ariet_combat.dart';
import 'package:regun/systems/ariet_rig.dart';

ArietCombat make({
  int? quota,
  void Function(ArietDrop)? deploy,
  bool Function(double, String)? hurt,
  bool Function(Offset, Offset, double)? clear,
}) => ArietCombat(
  rig: ArietRig(),
  reinforcementCount: quota,
  clear: clear ?? (_, __, ___) => true,
  hurt: hurt ?? (_, __) => true,
  signal: (_) {},
  landingLegal: (_, __) => true,
  deploy: deploy ?? (_) {},
);

void main() {
  test(
    'rotary contacts register again after protection in the same volley',
    () {
      var hits = 0;
      final f =
          make(
              quota: 0,
              hurt: (_, __) {
                hits++;
                return true;
              },
            )
            ..phase = ArietPhase.recovery
            ..player = Offset.zero;
      void shot() => f.rounds.add(ArietRound(const Offset(-50, 0), 0, pass: 7));
      shot();
      f.advance(.1);
      expect(hits, 1);
      shot();
      f.advance(.1);
      expect(hits, 1);
      f.advance(.45);
      shot();
      f.advance(.1);
      expect(hits, 2);
      expect(f.rounds, isEmpty);
    },
  );

  test(
    'heavy shell detonates exactly at committed range, once, without overshoot',
    () {
      var hits = 0;
      final f =
          make(
              quota: 0,
              hurt: (_, __) {
                hits++;
                return true;
              },
            )
            ..phase = ArietPhase.recovery
            ..player = const Offset(0, 9000);
      final r = ArietRound(
        Offset.zero,
        0,
        cannon: true,
        burstAt: const Offset(300, 0),
      );
      f.rounds.add(r);
      f.advance(.39);
      expect(f.rounds, contains(r));
      f.advance(.1);
      expect(f.rounds, isEmpty);
      expect(r.position.dx, closeTo(300, .001));
      expect(f.impacts.where((b) => b.rocketBlast), hasLength(1));
      f.advance(.1);
      expect(hits, 0);
    },
  );

  test('heavy shell contact and cover precede range fuse and retain cover-tested blast', () {
    var hits = 0;
    final f =
        make(
            quota: 0,
            hurt: (d, _) {
              hits++;
              expect(d, 2);
              return true;
            },
          )
          ..phase = ArietPhase.recovery
          ..player = const Offset(200, 0);
    f.rounds.add(
      ArietRound(Offset.zero, 0, cannon: true, burstAt: const Offset(600, 0)),
    );
    f.advance(.4);
    expect(hits, 1);
    expect(f.rounds, isEmpty);
    f.advance(.1);
    expect(hits, 1);
    final covered =
        make(
            quota: 0,
            hurt: (_, __) {
              hits++;
              return true;
            },
            clear: (a, b, _) => a.dx < 150 && b.dx < 150,
          )
          ..phase = ArietPhase.recovery
          ..player = const Offset(180, 0);
    covered.rounds.add(
      ArietRound(Offset.zero, 0, cannon: true, burstAt: const Offset(600, 0)),
    );
    covered.advance(1);
    expect(hits, 1);
    expect(covered.rounds, isEmpty);
  });

  test(
    'encounter variants choose none, one, or a late separated second escort',
    () {
      for (final quota in [0, 1, 2]) {
        final times = <double>[], sites = <Offset>[];
        late ArietCombat f;
        f =
            make(
                quota: quota,
                deploy: (d) {
                  times.add(f.elapsed);
                  sites.add(d.landing);
                },
              )
              ..enraged = true
              ..player = const Offset(650, 0);
        for (var i = 0; i < 120 * 65; i++) {
          f.advance(1 / 120);
          expect(
            f.drops.where((d) => !d.activated && !d.aborted),
            hasLength(lessThanOrEqualTo(1)),
          );
        }
        expect(times, hasLength(quota));
        expect(f.totalDrops, quota);
        if (quota == 2) {
          expect(times[1] - times[0], greaterThanOrEqualTo(20));
          expect((sites[1] - sites[0]).distance, greaterThanOrEqualTo(420));
        }
      }
      final counts = <int>{};
      for (var seed = 0; seed < 100; seed++) {
        counts.add(
          ArietCombat(
            rig: ArietRig(),
            seed: seed,
            clear: (_, __, ___) => true,
            hurt: (_, __) => true,
            signal: (_) {},
            landingLegal: (_, __) => true,
            deploy: (_) {},
          ).escortQuota,
        );
      }
      expect(counts, {0, 1, 2});
    },
  );

  test('pending deployment survives pause and checkpoint without replaying its release', () {
    final f = make(quota: 2)
      ..enraged = true
      ..player = const Offset(650, 0);
    for (var i = 0; i < 2400 && f.totalDrops == 0; i++) {
      f.advance(1 / 120);
    }
    expect(f.totalDrops, 1);
    final saved = f.checkpoint();
    expect(ArietCombat.validCheckpoint(saved), isTrue);
    var deployed = 0;
    final resumed = make(quota: 0, deploy: (_) => deployed++)..restore(saved);
    resumed.paused = true;
    resumed.advance(10);
    expect(deployed, 0);
    resumed.paused = false;
    resumed.advance(2);
    expect(deployed, 1);
    expect(resumed.totalDrops, 1);
    final again = make(quota: 0, deploy: (_) => deployed++)
      ..restore(resumed.checkpoint());
    again.advance(2);
    expect(deployed, 1);
    final bad = Map<String, dynamic>.from(saved)..['quota'] = 3;
    expect(ArietCombat.validCheckpoint(bad), isFalse);
  });
}
