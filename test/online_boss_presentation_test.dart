import 'package:flutter_test/flutter_test.dart';
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/presentation/online_boss_presentation.dart';

OnlineMatch reveal(double left) => OnlineMatch({
  'phase': 'boss_reveal',
  'phaseSeconds': left,
  'bossArrival': {
    'serial': 1,
    'duration': 2.65,
    'actors': [
      {'key': 'b', 'kind': 'shadow', 'x': 600.0, 'y': 300.0, 'size': 300.0},
    ],
  },
});
final live = [
  OnlineEntity('b', 'enemy', {'boss': true, 'health': 100}),
];
void main() {
  test('server hold directs the camera, returns before release, and death never selects a corpse', () {
    final p = OnlineBossPresentation();
    const player = Offset(100, 20);
    p.sync('match1', reveal(2.65), live, .016, reducedMotion: false);
    expect(p.camera(player, reducedMotion: false), player);
    p.sync('match1', reveal(1.5), live, .016, reducedMotion: false);
    expect(p.camera(player, reducedMotion: false), const Offset(600, 300));
    expect(p.opacity, greaterThan(0));
    p.sync('match1', reveal(0), live, .016, reducedMotion: false);
    expect(p.camera(player, reducedMotion: false), player);
    p.sync(
      'match1',
      OnlineMatch({'phase': 'active'}),
      live,
      1,
      reducedMotion: false,
    );
    expect(p.zoom, .88);
    final dead = [
      OnlineEntity('b', 'enemy', {
        'boss': true,
        'health': 0,
        'x': 1500,
        'y': 1000,
      }),
    ];
    p.sync(
      'match1',
      OnlineMatch({'phase': 'active'}),
      dead,
      .1,
      reducedMotion: false,
    );
    expect(p.camera(player, reducedMotion: false), player);
    expect(p.zoom, greaterThan(.88));
  });
  test('late join uses server progress; stale samples freeze and Reduced Motion stays player anchored', () {
    final p = OnlineBossPresentation();
    p.sync('match1', reveal(.3), live, .016, reducedMotion: true);
    expect(p.elapsed, closeTo(2.35, .001));
    expect(
      p.camera(const Offset(30, 40), reducedMotion: true),
      const Offset(30, 40),
    );
    for (var i = 0; i < 100; i++) {
      p.sync('match1', reveal(.3), live, .1, reducedMotion: true);
    }
    expect(p.elapsed, closeTo(2.4, .001));
    expect(p.holding, isTrue);
    p.sync('match1', null, live, 0, reducedMotion: true);
    expect(p.holding, isFalse);
    expect(p.actors, isEmpty);
  });
}
