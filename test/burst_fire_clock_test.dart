import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/presentation/weapon_art_spec.dart';
import 'package:regun/systems/burst_fire_clock.dart';

void main() {
  test(
    'three releases keep their timestamps across fine and stalled frames',
    () {
      for (final frames in [
        List.filled(100, .01),
        List.filled(20, .05),
        [1.0],
      ]) {
        final clock = BurstFireClock();
        final times = <double>[];
        var now = 0.0;
        for (final dt in frames) {
          clock.advance(
            dt,
            held: true,
            interval: .6,
            ready: () => true,
            release: (offset) {
              times.add(now + offset);
              return true;
            },
          );
          now += dt;
        }
        expect(times.length, 6);
        for (var i = 0; i < times.length; i++) {
          expect(times[i], closeTo([0, .1, .2, .6, .7, .8][i], 1e-8));
        }
      }
    },
  );

  test('release cancels unissued rounds without skipping burst recovery', () {
    final clock = BurstFireClock();
    var shots = 0;
    bool release(double offset) {
      shots++;
      return true;
    }

    clock.advance(
      .05,
      held: true,
      interval: .6,
      ready: () => true,
      release: release,
    );
    expect(shots, 1);
    clock.advance(
      .05,
      held: false,
      interval: .6,
      ready: () => true,
      release: release,
    );
    expect(clock.pending, 0);
    clock.advance(
      .49,
      held: true,
      interval: .6,
      ready: () => true,
      release: release,
    );
    expect(shots, 1);
    clock.advance(
      .01,
      held: true,
      interval: .6,
      ready: () => true,
      release: release,
    );
    expect(shots, 2);
  });

  test('empty/reload cancels remainder and saturation spends nothing', () {
    final clock = BurstFireClock();
    var ammo = 1, shots = 0;
    clock.advance(
      .3,
      held: true,
      interval: .6,
      ready: () => ammo > 0,
      release: (_) {
        ammo--;
        shots++;
        return true;
      },
    );
    expect(shots, 1);
    expect(clock.pending, 0);
    clock.reset();
    clock.advance(
      .02,
      held: true,
      interval: .6,
      ready: () => true,
      release: (_) => false,
    );
    expect(clock.pending, 0);
    clock.advance(
      .05,
      held: true,
      interval: .6,
      ready: () => true,
      release: (_) {
        shots++;
        return true;
      },
    );
    expect(shots, 2);
  });

  test('Quick Trigger preserves subshot spacing and clamps burst starts', () {
    final clock = BurstFireClock(), times = <double>[];
    clock.advance(
      .51,
      held: true,
      interval: .01,
      ready: () => true,
      release: (offset) {
        times.add(offset);
        return true;
      },
    );
    expect(times.length, 6);
    for (var i = 0; i < 6; i++) {
      expect(times[i], closeTo(i * .1, 1e-8));
    }
    expect(() => clock.reset(recovery: double.nan), throwsFormatException);
    expect(() => clock.reset(recovery: .7), throwsFormatException);
    expect(
      () => clock.advance(
        -1,
        held: true,
        interval: .6,
        ready: () => true,
        release: (_) => true,
      ),
      throwsArgumentError,
    );
  });

  test('Continue retains recovery but cannot replay pending subshots', () {
    final clock = BurstFireClock();
    clock.advance(
      .05,
      held: true,
      interval: .6,
      ready: () => true,
      release: (_) => true,
    );
    final restored = BurstFireClock()..reset(recovery: clock.recovery);
    expect(restored.pending, 0);
    var shots = 0;
    restored.advance(
      .54,
      held: true,
      interval: .6,
      ready: () => true,
      release: (_) {
        shots++;
        return true;
      },
    );
    expect(shots, 0);
  });

  test('explicit frames retain originals and muzzle sockets rotate/mirror', () {
    expect(WeaponArtSpec.of(WeaponType.shotgun).mechanism, 4);
    expect(WeaponArtSpec.of(WeaponType.arcCaster).mechanism, 7);
    final burst = WeaponArtSpec.of(WeaponType.burstRifle);
    expect(burst.atlas, 'weapons/burst_rifle');
    for (var i = 0; i < 360; i++) {
      final a = i * math.pi / 180;
      final d = Offset(math.cos(a), math.sin(a));
      final p = burst.releaseOffset(d) - const Offset(0, 6);
      expect(p.dx * d.dx + p.dy * d.dy, closeTo(43.34, 1e-7));
      expect(p.distance, closeTo(math.sqrt(43.34 * 43.34 + 4.06 * 4.06), 1e-7));
    }
    expect(
      (burst.releaseOffset(const Offset(1, 0)) - const Offset(43.34, 1.94))
          .distance,
      lessThan(1e-8),
    );
    expect(
      (burst.releaseOffset(const Offset(-1, 0)) - const Offset(-43.34, 1.94))
          .distance,
      lessThan(1e-8),
    );
  });
}
