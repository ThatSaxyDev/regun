import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:regun/systems/repeating_action.dart';

void main() {
  test('ten minutes of idle firing retain one timer and no per-tick components',
      () async {
    final game = FlameGame();
    game.onGameResize(Vector2(1500, 700));
    // Headless engine lifecycle; GameWidget normally calls these internal hooks.
    // ignore: invalid_use_of_internal_member
    await game.load();
    // ignore: invalid_use_of_internal_member
    game.mount();
    await game.ready();
    var ticks = 0;
    await game.world.add(RepeatingAction(period: 0.35, onTick: () => ticks++));
    await game.ready();
    final watch = Stopwatch()..start();
    for (var frame = 0; frame < 60 * 600; frame++) {
      game.update(1 / 60);
    }
    watch.stop();
    debugPrint(
        'AFTER: simulatedSeconds=600 timerTicks=$ticks retainedTimerComponents=${game.world.children.length} updateMicros=${watch.elapsedMicroseconds}');
    expect(ticks, greaterThan(1700));
    expect(game.world.children.length, 1);
    game.onRemove();
  });
}
