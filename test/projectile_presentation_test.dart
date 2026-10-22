import 'package:flutter_test/flutter_test.dart';
import 'package:regun/multiplayer/combat_state.dart';
import 'package:regun/multiplayer/projectile_presentation.dart';
import 'package:regun/multiplayer/identity_key.dart';

final open = ProjectileMap({
  'bounds': [-2000, -1000, 2000, 1000],
  'obstacles': [],
});
OnlineGun gun({
  String weapon = 'carbine',
  int ammo = 24,
  double cooldown = 0,
  bool reload = false,
  int shots = 0,
  String? burst,
  int burstShot = 0,
  Map<String, int> ranks = const {},
}) => OnlineGun('me', {
  'weapon': weapon,
  'ammo': ammo,
  'fireCooldown': cooldown,
  'reloadRemaining': reload ? 1 : 0,
  'shots': shots,
  'ranks': ranks,
  if (burst != null) 'fireBurst': burst,
  'burstShot': burstShot,
});
OnlineRound round({
  String id = 'server:1',
  String owner = 'other',
  double x = 100,
  double y = 6,
  double dx = 1,
  double dy = 0,
  double speed = 950,
  double distance = 50,
  double range = 650,
  String? burst,
  int burstShot = 1,
  int pellet = 0,
}) => OnlineRound(id, {
  'x': x,
  'y': y,
  'dx': dx,
  'dy': dy,
  'speed': speed,
  'distance': distance,
  'range': range,
  'owner': owner,
  'weapon': 'carbine',
  'primary': true,
  if (burst != null) 'burst': burst,
  'burstShot': burstShot,
  'pellet': pellet,
});
void capture(
  ProjectilePresentation p,
  double now,
  OnlineGun g,
  List<OnlineRound> rounds, {
  String epoch = 'room:1',
  ProjectileMap? map,
}) => p.capture(
  epoch: epoch,
  tick: (now * 1000).round(),
  now: now,
  serverTime: now - .1,
  rounds: rounds,
  identity: 'me',
  gun: g,
  map: map ?? open,
);
void predict(
  ProjectilePresentation p,
  double now,
  OnlineGun g, {
  bool held = true,
  bool enabled = true,
  int burst = 1,
  Offset origin = Offset.zero,
}) => p.predict(
  now: now,
  enabled: enabled,
  held: held,
  gun: g,
  origin: origin,
  aim: const Offset(1, 0),
  identity: 'me',
  team: 0,
  burst: burst,
);

void main() {
  test('server bullets move each render frame between 20Hz snapshots', () {
    final p = ProjectilePresentation();
    final g = gun();
    capture(p, 0, g, [round()]);
    final xs = [for (var i = 0; i < 4; i++) p.render(i / 60, open).single.x];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i] - xs[i - 1], closeTo(950 / 60, 1e-8));
    }
    final before = p.render(.05, open).single.x;
    capture(p, .05, g, [round(x: 147.5, distance: 97.5)]);
    expect(p.render(.05, open).single.x, closeTo(before, 1e-8));
    expect(p.render(.066, open).single.x, greaterThan(before));
  });
  test(
    'missing snapshots stop after80ms and authoritative deletion is immediate',
    () {
      final p = ProjectilePresentation(), g = gun();
      capture(p, 0, g, [round()]);
      expect(p.render(.08, open).single.x, closeTo(176, 1e-8));
      expect(p.render(1, open).single.x, closeTo(176, 1e-8));
      capture(p, 1, g, []);
      expect(p.render(1, open), isEmpty);
    },
  );
  test(
    'local volley appears before confirmation without changing gun ammo',
    () {
      final p = ProjectilePresentation(), g = gun();
      capture(p, 0, g, []);
      predict(p, .016, g);
      final r = p.render(.016, open).single;
      expect(r.id, startsWith('local:1:1:'));
      expect(r.x, closeTo(39.35, 1e-8));
      expect(g.ammo, 24);
      expect(g.shots, 0);
      expect(p.takeCue(), true);
      expect(p.takeCue(), false);
      expect(p.render(.032, open).single.x, greaterThan(r.x));
    },
  );
  test(
    'server burst/pellet confirmation replaces one ghost without backward jump',
    () {
      final p = ProjectilePresentation(), g = gun();
      capture(p, 0, g, []);
      predict(p, 0, g);
      final before = p.render(.2, open).single;
      final confirmed = gun(shots: 1, ammo: 23, burst: '1', burstShot: 1);
      capture(p, .2, confirmed, [
        round(owner: 'me', x: 86.85, distance: 47.5, burst: '1'),
      ]);
      final after = p.render(.2, open);
      expect(after.length, 1);
      expect(after.single.id, 'server:1');
      expect(after.single.x, closeTo(before.x, 1e-8));
      expect(p.matched, 1);
      expect(p.wasPredicted(confirmed), true);
      capture(p, .25, confirmed, [
        round(owner: 'me', x: 134.35, distance: 95, burst: '1'),
      ]);
      expect(p.render(.25, open).single.x, closeTo(before.x + 47.5, 1e-8));
    },
  );
  test(
    'random server heading is adopted without drawing two carbine rounds',
    () {
      final p = ProjectilePresentation(), g = gun();
      capture(p, 0, g, []);
      predict(p, 0, g);
      capture(p, .15, gun(shots: 1, ammo: 23, burst: '1', burstShot: 1), [
        round(owner: 'me', x: 86.8, dx: .9994, dy: .0349, burst: '1'),
      ]);
      final r = p.render(.16, open).single;
      expect(r.id, 'server:1');
      expect(r.dy, .0349);
      expect(r.dx, .9994);
    },
  );
  test('rapid release/repress never joins a delayed previous burst', () {
    final p = ProjectilePresentation(), g = gun();
    capture(p, 0, g, []);
    predict(p, 0, g, burst: 1);
    predict(p, .05, g, held: false);
    capture(p, .12, g, []);
    predict(p, .12, g, burst: 2);
    expect(p.render(.12, open).length, 2);
    capture(p, .15, gun(shots: 1, ammo: 23, burst: '1', burstShot: 1), [
      round(owner: 'me', burst: '1'),
    ]);
    final r = p.render(.15, open);
    expect(r.length, 2);
    expect(r.where((r) => r.id.startsWith('local:2:')).length, 1);
    expect(p.matched, 1);
  });
  test(
    'all pellets have separate identities and confirmed missing pellets retire',
    () {
      final p = ProjectilePresentation(), g = gun(weapon: 'shotgun', ammo: 5);
      capture(p, 0, g, []);
      predict(p, 0, g);
      final volley = p.render(.02, open);
      expect(volley.length, 3);
      expect(volley.map((r) => r.id).toSet().length, 3);
      expect(volley[1].dy, 0);
      capture(
        p,
        .1,
        gun(weapon: 'shotgun', ammo: 4, shots: 1, burst: '1', burstShot: 1),
        [round(owner: 'me', burst: '1', pellet: 1)],
      );
      expect(p.render(.1, open).length, 1);
    },
  );
  test(
    'last cartridge, reload, cooldown and snapshot freshness bound speculation',
    () {
      final p = ProjectilePresentation(), g = gun(ammo: 1);
      capture(p, 0, g, []);
      predict(p, 0, g);
      capture(p, .15, g, []);
      predict(p, .15, g);
      expect(p.speculativeCount, 1);
      final reloading = gun(reload: true);
      capture(p, .2, reloading, []);
      predict(p, .2, reloading, burst: 2);
      expect(p.render(.2, open).length, 1);
      predict(p, .6, g);
      expect(p.speculativeCount, 0); // stale snapshot cancels.
      final q = ProjectilePresentation(), cooling = gun(cooldown: .2);
      capture(q, 0, cooling, []);
      predict(q, .01, cooling);
      expect(q.speculativeCount, 0);
    },
  );
  test('denied speculation expires and cannot continue guessing the same held burst', () {
    final p = ProjectilePresentation(), g = gun(ammo: 24);
    capture(p, 0, g, []);
    predict(p, 0, g);
    for (var i = 1; i <= 50; i++) {
      final t = i * .05;
      capture(p, t, g, []);
      predict(p, t, g);
      p.render(t, open);
    }
    expect(p.speculativeCount, 0);
    expect(p.trackedCount, 0);
    predict(p, 2.8, g, burst: 2); // stale snapshot -> no new speculation
    expect(p.speculativeCount, 0);
    capture(p, 2.8, g, []);
    predict(p, 2.8, g, burst: 2);
    expect(p.speculativeCount, 1);
  });
  test(
    'near-muzzle hit, walls and range cannot resurrect a finished ghost',
    () {
      final wall = ProjectileMap({
        'bounds': [-2000, -1000, 2000, 1000],
        'obstacles': [
          [70, -100, 90, 100],
        ],
      });
      final p = ProjectilePresentation(), g = gun();
      capture(p, 0, g, [], map: wall);
      predict(p, 0, g);
      expect(p.render(.1, wall), isEmpty);
      capture(p, .15, gun(shots: 1, ammo: 23, burst: '1', burstShot: 1), [
        round(owner: 'me', x: 60, distance: 20, burst: '1'),
      ], map: wall);
      expect(p.render(.15, wall), isEmpty);
      final q = ProjectilePresentation();
      capture(q, 0, g, [round(range: 70, distance: 65)]);
      expect(q.render(.01, open), isEmpty);
    },
  );
  test(
    'body hints stop visual guesses without producing damage or fake impacts',
    () {
      final p = ProjectilePresentation(), g = gun();
      capture(p, 0, g, []);
      predict(p, 0, g);
      expect(p.render(.05, open, bodies: [(const Offset(90, 6), 30)]), isEmpty);
      expect(g.ammo, 24);
      expect(g.data.containsKey('damageTotal'), false);
    },
  );
  test(
    'ricochet direction resets old forward prediction and phases/epochs clear',
    () {
      final p = ProjectilePresentation(), g = gun();
      capture(p, 0, g, [round()]);
      p.render(.05, open);
      capture(p, .05, g, [round(x: 130, dx: 0, dy: 1)]);
      expect(p.render(.05, open).single.x, 130);
      expect(p.render(.07, open).single.y, greaterThan(6));
      expect(p.render(.1, open, active: false).single.y, 6);
      capture(p, .2, g, [], epoch: 'room:2');
      expect(p.render(.2, open), isEmpty);
      predict(p, .2, g);
      predict(p, .21, g, enabled: false);
      expect(p.speculativeCount, 0);
    },
  );
  test('canonical ownership joins only the same shooter burst and pellet', () {
    final native = '01${'00' * 31}',
        canonical = identityKeyFromCanonical('01${'00' * 31}');
    final p = ProjectilePresentation(), g = gun();
    capture(p, 0, g, []);
    p.predict(
      now: 0,
      enabled: true,
      held: true,
      gun: g,
      origin: Offset.zero,
      aim: const Offset(1, 0),
      identity: native,
      team: 0,
      burst: 1,
    );
    final ghost = p.render(.01, open).single;
    expect(ghost.owner, native);
    expect(ghost.data['owner'], canonical);
    capture(p, .1, gun(shots: 1, ammo: 23, burst: '1', burstShot: 1), [
      round(owner: canonical, burst: '1'),
    ]);
    expect(p.matched, 1);
  });
  test('confirmed piercing resumes beyond a speculative body contact', () {
    final p = ProjectilePresentation(), g = gun();
    capture(p, 0, g, []);
    predict(p, 0, g);
    expect(p.render(.1, open, bodies: [(const Offset(120, 6), 30)]), isEmpty);
    final confirmed = gun(shots: 1, ammo: 23, burst: '1', burstShot: 1);
    capture(p, .15, confirmed, [
      round(owner: 'me', x: 70, distance: 30, burst: '1'),
    ]);
    expect(p.render(.15, open), isEmpty);
    capture(p, .2, confirmed, [
      round(owner: 'me', x: 160, distance: 120, burst: '1'),
    ]);
    expect(p.render(.2, open).single.x, 160);
  });
}
