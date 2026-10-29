import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/ariet_combat.dart';
import 'package:regun/systems/ariet_rig.dart';

ArietCombat fight({
  bool Function(double, String)? hurt,
  bool Function(Offset, Offset, double)? clear,
}) => ArietCombat(
  rig: ArietRig(),
  clear: clear ?? (_, __, ___) => true,
  hurt: hurt ?? (_, __) => true,
  signal: (_) {},
  landingLegal: (_, __) => true,
  deploy: (_) {},
);

void main() {
  test('launcher acquires rear targets and commits its release fan before guidance starts', () {
    final f = fight()
      ..phase = ArietPhase.seekerLock
      ..player = const Offset(-600, 0);
    f.advance(.8);
    final lock = f.locked;
    f.player = const Offset(600, 0);
    f.advance(.15);
    final rocket = f.rounds.singleWhere((r) => r.seeker);
    final initial = ArietCombat.heading(lock - f.rig.launcherSocket);
    expect(ArietRig.difference(rocket.heading, initial).abs(), lessThan(.5));
    expect(
      ArietRig.difference(
        rocket.heading,
        ArietCombat.heading(f.player - f.rig.launcherSocket),
      ).abs(),
      greaterThan(1),
    );
    expect(rocket.age, lessThan(.1));
  });
  test('seeker salvos commit four or six staggered visible rockets within shared capacity', () {
    for (final enrage in [false, true]) {
      final f = fight()
        ..enraged = enrage
        ..phase = ArietPhase.seekerLock
        ..player = const Offset(10000, 10000);
      f.advance(.85);
      expect(f.totalSeekers, 0);
      for (var i = 0; i < 240; i++) {
        f.advance(1 / 120);
        expect(
          f.rounds.where((r) => r.seeker).length,
          lessThanOrEqualTo(enrage ? 6 : 4),
        );
        expect(f.rounds.length, lessThanOrEqualTo(32));
      }
      expect(f.totalSeekers, enrage ? 6 : 4);
      expect(f.launcherCell, enrage ? 5 : 3);
      expect(f.rounds.where((r) => r.seeker).length, enrage ? 6 : 4);
    }
  });
  test('expired seekers visibly burst without adding expiry damage', () {
    var hits = 0;
    final f =
        fight(
            hurt: (_, __) {
              hits++;
              return true;
            },
          )
          ..phase = ArietPhase.recovery
          ..player = const Offset(0, 9000);
    final r = ArietRound(Offset.zero, 0, seeker: true)..age = 3.49;
    f.rounds.add(r);
    f.advance(.025);
    expect(r.removed, isTrue);
    expect(f.rounds, isEmpty);
    expect(f.impacts.where((i) => i.rocketBlast), hasLength(1));
    final burnout = f.impacts.single;
    final at = burnout.position;
    f.paused = true;
    f.advance(2);
    expect(burnout.position, at);
    f.paused = false;
    f.advance(.1);
    expect(burnout.position, at);
    expect(burnout.radius, greaterThanOrEqualTo(70));
    expect(hits, 0);
    f.advance(.6);
    expect(f.impacts.where((i) => i.rocketBlast), isEmpty);
  });
  test('entire roof bearing and recoil sweeps clear other receiver/support envelopes', () {
    final r = ArietRig();
    for (final hullYaw in [0.0, .7, math.pi]) {
      r.yaw = hullYaw;
      for (var station = 0; station < 4; station++) {
        for (var degree = 0; degree < 360; degree++) {
          for (final recoil in [0.0, 7.0, 15.0]) {
            expect(
              r.barrelClear(
                station,
                hullYaw + degree * math.pi / 180,
                recoil: recoil,
              ),
              isTrue,
              reason: 'station=$station degree=$degree recoil=$recoil',
            );
          }
        }
      }
    }
  });
  test('all 16 azimuths at close/mid/retreat range receive actual damage within four seconds', () {
    for (final range in [0.0, 60.0, 100.0, 150.0, 300.0, 650.0]) {
      for (var n = 0; n < 16; n++) {
        var damage = 0.0;
        final f =
            fight(
                hurt: (d, _) {
                  damage += d;
                  return true;
                },
              )
              ..phase = ArietPhase.navigate
              ..player = ArietCombat.unit(n * math.pi / 8) * range;
        f.advance(4);
        expect(
          damage,
          greaterThan(0),
          reason:
              'range=$range azimuth=$n phase=${f.phase} rounds=${f.totalNose}/${f.totalCannon}',
        );
      }
    }
  });

  test('roof cannon keeps committed fire while the jet strafes; released shells never home', () {
    var hits = 0;
    final f =
        fight(
            hurt: (_, __) {
              hits++;
              return true;
            },
          )
          ..phase = ArietPhase.cannonLock
          ..player = const Offset(-400, 0);
    f.advance(1.18);
    final released = f.rounds.firstWhere((r) => r.cannon);
    final locked = released.heading;
    f.player = const Offset(-400, 400);
    f.advance(.05);
    expect(released.heading, locked);
    f.player = const Offset(-400, 0);
    f.advance(1.8);
    expect(f.totalCannon, 4);
    expect(hits, greaterThan(0));
    expect(f.rig.position.distance, greaterThan(100));
  });

  test('seeker has both guidance delays, bounded turn and once-only interception without damage', () {
    var hits = 0;
    final f =
        fight(
            hurt: (_, __) {
              hits++;
              return true;
            },
          )
          ..phase = ArietPhase.seekers
          ..player = const Offset(800, 400);
    f.advance(.02);
    final r = f.rounds.single;
    final initial = r.heading;
    f.advance(.5);
    expect(r.heading, initial);
    f.advance(.1);
    expect(
      (ArietRig.difference(r.heading, initial)).abs(),
      lessThanOrEqualTo(1.8 * .03),
    );
    final before = r.heading;
    f.advance(.1);
    expect(
      ArietRig.difference(r.heading, before).abs(),
      lessThanOrEqualTo(.18 + 1e-9),
    );
    final p = r.position;
    f.paused = true;
    expect(f.intercept(r), isFalse);
    f.advance(4);
    expect(r.position, p);
    f.paused = false;
    expect(f.intercept(r), isTrue);
    expect(f.intercept(r), isFalse);
    expect(f.totalIntercepts, 1);
    expect(hits, 0);
    f.beginDestruction();
    expect(f.rounds, isEmpty);
  });

  test('unarmed seeker requires minimum travel, expiry is harmless and wall blast respects cover', () {
    var hits = 0;
    final f =
        fight(
            hurt: (_, __) {
              hits++;
              return true;
            },
          )
          ..phase = ArietPhase.recovery
          ..player = const Offset(0, 2000);
    final r = ArietRound(Offset.zero, 0, seeker: true)..age = .7;
    f.rounds.add(r);
    f.advance(.1);
    expect(r.heading, 0);
    f.advance(4);
    expect(r.removed, isTrue);
    expect(hits, 0);
    final covered =
        fight(
            clear: (a, b, _) => a.dx <= 40 && b.dx <= 40,
            hurt: (_, __) {
              hits++;
              return true;
            },
          )
          ..phase = ArietPhase.recovery
          ..player = const Offset(60, 0);
    covered.rounds.add(ArietRound(Offset.zero, 0, seeker: true));
    covered.advance(.5);
    expect(hits, 0);
    expect(covered.rounds, isEmpty);
  });

  test('flak reserves whole packets, plants aim, flies before bursting and bounds volley damage', () {
    var hits = 0;
    final f =
        fight(
            hurt: (_, __) {
              hits++;
              return true;
            },
          )
          ..phase = ArietPhase.flakLock
          ..player = const Offset(250, -30);
    f.flakTargets.addAll([f.player, f.player + const Offset(0, 40)]);
    f.rig.flakYaw = ArietCombat.heading(f.player - f.rig.flakSocket);
    final targets = f.flakTargets.toList();
    f.advance(.85);
    expect(f.totalFlak, 0);
    expect(f.flakTargets, targets);
    f.advance(.1);
    expect(f.totalFlak, 1);
    expect(f.rounds.any((r) => r.flakPacket), isTrue);
    expect(hits, 0);
    f.advance(1);
    expect(f.totalFlak, 2);
    expect(hits, 1);
    final quietStart = f.elapsed;
    f.advance(1);
    expect(f.phase, ArietPhase.recovery);
    expect(f.elapsed - quietStart, closeTo(1, 1e-8));
  });

  test('full capacity waits without truncating flak; death cancels every pending release', () {
    final f = fight()
      ..phase = ArietPhase.flakLock
      ..player = const Offset(800, 0);
    f.flakTargets.addAll([const Offset(200, 0), const Offset(200, 60)]);
    for (var i = 0; i < 30; i++) {
      f.rounds.add(ArietRound(const Offset(-2000, -2000), 0));
    }
    f.advance(.95);
    expect(f.totalFlak, 0);
    expect(f.phase, ArietPhase.flakLock);
    f.advance(1);
    expect(f.totalFlak, 2);
    expect(f.rounds.length + f.reservedRounds, lessThanOrEqualTo(32));
    f.beginDestruction();
    f.advance(5);
    expect(f.rounds, isEmpty);
    expect(f.flakTargets, isEmpty);
  });

  test('both phases and orbit directions retain full bearing and all four weapon families', () {
    for (final enrage in [false, true]) {
      for (final speed in [-.8, .8, -2.0, 2.0]) {
        var hits = 0;
        final f = fight(
          hurt: (_, __) {
            hits++;
            return true;
          },
        )..enraged = enrage;
        final seen = <ArietPhase>{};
        for (var i = 0; i < 120 * 90; i++) {
          f.player = ArietCombat.unit(i / 120 * speed) * 350;
          f.advance(1 / 120);
          seen.add(f.phase);
          expect(f.rounds.length + f.reservedRounds, lessThanOrEqualTo(32));
        }
        expect(
          seen,
          containsAll([
            ArietPhase.strafe,
            ArietPhase.cannon,
            ArietPhase.flak,
            ArietPhase.seekers,
          ]),
          reason: 'enrage=$enrage speed=$speed',
        );
        expect(f.totalNose, greaterThan(0));
        expect(f.totalCannon, greaterThan(0));
        expect(f.totalFlak, greaterThan(0));
        expect(f.totalSeekers, greaterThan(0));
        expect(
          hits,
          greaterThan(0),
          reason:
              'orbit must receive actual damage: enrage=$enrage speed=$speed pos=${f.rig.position} nose=${f.totalNose}',
        );
      }
    }
  });
}
