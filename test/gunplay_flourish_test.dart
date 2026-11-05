import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/systems/gunplay_flourish.dart';

void main() {
  test('reload pose survives ordinary dash landing and clears on a shot', () {
    final flourish = GunplayFlourish()..reload(WeaponType.revolver);
    flourish.advance(.115);
    final spin = flourish.pose;
    expect(spin.angle, closeTo(-3.14159, .001));
    expect(spin.lift, 5);
    flourish.landDash(WeaponType.revolver, escaped: false);
    expect(flourish.pose, spin);
    flourish.clear();
    expect(flourish.pose, (angle: 0, lift: 0));
  });

  test('shotgun catch settles and unsupported weapons have no flourish', () {
    final flourish = GunplayFlourish()..reload(WeaponType.shotgun);
    flourish.advance(.085);
    expect(flourish.pose.angle, closeTo(.57, .001));
    flourish.advance(.085);
    flourish.reload(WeaponType.carbine);
    flourish.landDash(WeaponType.carbine, escaped: true);
    expect(flourish.pose, (angle: 0, lift: 0));
  });

  test('dash near miss requires a close swept pass and a displaced hit', () {
    bool passes({
      Offset start = Offset.zero,
      Offset before = const Offset(0, 24),
      Offset after = const Offset(0, 26),
      Offset shotEnd = const Offset(20, 0),
    }) => isDashNearMiss(
      dashStart: start,
      playerBefore: before,
      playerAfter: after,
      shotBefore: const Offset(-20, 0),
      shotAfter: shotEnd,
      contact: 10,
    );

    expect(passes(), isTrue);
    expect(passes(start: const Offset(0, -20)), isFalse);
    expect(passes(before: Offset.zero, after: Offset.zero), isFalse);
    expect(
      passes(before: const Offset(0, 60), after: const Offset(0, 62)),
      isFalse,
    );
    expect(passes(shotEnd: const Offset(-5, 0)), isFalse);
  });
}
