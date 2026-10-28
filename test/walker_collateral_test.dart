import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/walker_combat.dart';
import 'package:regun/systems/walker_rig.dart';

void main() {
  ({WalkerCombat fight, Set<String> alive, Map<String, Offset> bodies}) make() {
    final bodies = <String, Offset>{}, alive = <String>{};
    final f =
        WalkerCombat(
            rig: WalkerRig(
              bodyBounds: const Rect.fromLTRB(-3000, -3000, 3000, 3000),
              footBounds: const Rect.fromLTRB(-3200, -3200, 3200, 3200),
            ),
            clear: (_, _, _) => true,
            hurt: (_, _) {},
            signal: (_) {},
            minions: () => [
              for (final id in alive) WalkerMinion(id, bodies[id]!, 30),
            ],
            crushMinion: alive.remove,
          )
          ..phase = WalkerPhase.recovery
          ..recoveryDuration = 10
          ..player = const Offset(600, 0);
    return (fight: f, alive: alive, bodies: bodies);
  }

  test('missiles fly over minions and only their actual impact clears the blast crowd', () {
    final f = make();
    f.bodies.addAll({
      'near': const Offset(590, 40),
      'safe': const Offset(590, 300),
    });
    f.alive.addAll(f.bodies.keys);
    f.fight.rounds.add(
      WalkerRound(
        WalkerRoundKind.rocket,
        Offset.zero,
        0,
        aim: const Offset(600, 0),
      ),
    );
    f.fight.advance(1.1);
    expect(f.alive, contains('near'));
    f.fight.advance(.8);
    expect(f.alive, isNot(contains('near')));
    expect(f.alive, contains('safe'));
  });
  test('heavy cannon impact detonates against minions and clears only its blast area', () {
    final f = make();
    f.bodies.addAll({
      'hit': const Offset(200, 0),
      'near': const Offset(230, 0),
      'safe': const Offset(230, 300),
    });
    f.alive.addAll(f.bodies.keys);
    f.fight.rounds.add(
      WalkerRound(
        WalkerRoundKind.cannon,
        Offset.zero,
        0,
        aim: const Offset(600, 0),
      ),
    );
    f.fight.advance(.4);
    expect(f.alive, {'safe'});
    expect(f.fight.blasts.length, 1);
  });
  test('airborne rush preserves path minions and kills at landing only', () {
    final f = make();
    f.bodies.addAll({
      'path': const Offset(250, 0),
      'land': const Offset(750, 0),
      'safe': const Offset(750, 400),
    });
    f.alive.addAll(f.bodies.keys);
    f.fight.phase = WalkerPhase.charge;
    f.fight.advance(.5);
    expect(f.alive, containsAll(['path', 'land']));
    f.fight.advance(.7);
    expect(f.alive, {'path', 'safe'});
  });
}
