import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/components/weapons/bullet_component.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/systems/weapon_ballistics.dart';

void main() {
  for (final weapon in WeaponType.values) {
    test('${weapon.name} has bounded smooth falloff and a useful far floor', () {
      final curve = WeaponBallistics.of(weapon);
      expect(curve.multiplier(0), curve.closeMultiplier);
      expect(curve.multiplier(curve.closeDistance), curve.closeMultiplier);
      expect(curve.multiplier(100000), closeTo(curve.farMultiplier, 1e-12));
      var previous = curve.closeMultiplier;
      for (var distance = 0; distance <= 2000; distance++) {
        final current = curve.multiplier(distance.toDouble());
        expect(current, inInclusiveRange(.90 - 1e-12, 1.20 + 1e-12));
        expect(current, lessThanOrEqualTo(previous + 1e-12));
        previous = current;
      }
      expect(curve.multiplier(curve.closeDistance + .001),
          closeTo(curve.closeMultiplier, 1e-8));
      expect(curve.multiplier(curve.farDistance - .001),
          closeTo(curve.farMultiplier, 1e-8));
    });
  }

  test('swept impact uses first body contact rather than frame endpoint', () {
    expect(BulletComponent.contactDistance(Vector2(200, 0), Vector2.zero(),
        Vector2(800, 0), 40), closeTo(160, .001));
    expect(BulletComponent.contactDistance(Vector2(200, 0), Vector2(150, 0),
        Vector2(220, 0), 40), closeTo(10, .001));
    expect(BulletComponent.contactDistance(Vector2(200, 0), Vector2(180, 0),
        Vector2(220, 0), 40), 0);
    expect(BulletComponent.contactDistance(Vector2.zero(), Vector2.zero(),
        Vector2.zero(), 40), 0);
  });
}
