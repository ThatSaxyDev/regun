import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/support_aim.dart';

void main() {
  test('mounted lead meets a lateral target at the physical intercept', () {
    const pivot = Offset(0, -42),
        target = Offset(350, -42),
        velocity = Offset(0, 180);
    for (final speed in [950.0, 1100.0]) {
      final aim = supportAim(pivot, target, velocity, speed);
      final flight = ((aim - pivot).distance - 56) / speed;
      expect((aim - (target + velocity * flight)).distance, lessThan(.001));
      expect(aim.dy, greaterThan(target.dy));
    }
  });
  test('stationary, close, escaping and extreme velocities stay finite and bounded', () {
    const p = Offset.zero, t = Offset(500, 0);
    expect(supportAim(p, t, Offset.zero, 950), t);
    expect(
      supportAim(p, const Offset(20, 0), const Offset(0, 100), 950),
      const Offset(20, 0),
    );
    for (final v in [
      const Offset(2000, 0),
      const Offset(0, 1000000),
      const Offset(-950, 0),
    ]) {
      final aim = supportAim(p, t, v, 950);
      expect(aim.dx.isFinite && aim.dy.isFinite, true);
      expect((aim - t).distance, lessThanOrEqualTo(140.0001));
    }
  });
}
