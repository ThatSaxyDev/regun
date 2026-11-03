import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/footstep_cadence.dart';

void main() {
  test('steps follow distance traveled and cycle through three samples', () {
    final cadence = FootstepCadence();
    expect(cadence.advance(45), isNull);
    expect(cadence.advance(1), 0);
    expect(cadence.advance(91), isNull);
    expect(cadence.advance(1), 1);
    expect(cadence.advance(92), 2);
    expect(cadence.advance(92), 0);
  });

  test('blocked movement and dash resets discard partial steps', () {
    final cadence = FootstepCadence();
    expect(cadence.advance(40), isNull);
    expect(cadence.advance(0), isNull);
    expect(cadence.advance(40), isNull);
    cadence.reset();
    expect(cadence.advance(5), isNull);
    expect(cadence.advance(41), 0);
  });

  test('a long frame emits one contact without a backlog', () {
    final cadence = FootstepCadence();
    expect(cadence.advance(46 + 3 * 92), 0);
    expect(cadence.advance(1), isNull);
  });
}
