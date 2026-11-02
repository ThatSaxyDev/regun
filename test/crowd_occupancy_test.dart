import 'package:regun/systems/target_shape.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/data/enemies.dart';
import 'package:regun/systems/crowd_occupancy.dart';
import 'package:regun/systems/enemy_tactics.dart';
import 'package:regun/systems/encounter_director.dart';

class _Compound extends PositionComponent implements CompoundGroundActor {
  _Compound(this.groundShape) : super(position: Vector2(1000, 1000));
  @override
  final List<TargetCapsule> groundShape;
}

void main() {
  void unbounded(Vector2 point) {}
  PositionComponent actor(double x, double y) =>
      PositionComponent(position: Vector2(x, y), size: Vector2.all(85));

  void separated(List<PositionComponent> actors, double gap) {
    for (var a = 0; a < actors.length; a++) {
      for (var b = a + 1; b < actors.length; b++) {
        expect(
          actors[a].position.distanceTo(actors[b].position),
          greaterThanOrEqualTo(gap - .001),
          reason: 'Bodies $a and $b must not overlap',
        );
      }
    }
  }

  test('compound escape uses the local section normal, never its remote root', () {
    final crowd = CrowdOccupancy();
    final compound = _Compound([
      const TargetCapsule(Offset(0, -100), Offset(0, 100), 35),
    ]);
    final mover = actor(-20, 0);
    crowd.rebuild([compound, mover], (_) => 45);
    // A changed mask/old checkpoint can start inside a section. A step toward
    // the opposite side must not be mistaken for an escape from zero distance.
    crowd.move(
      mover,
      Vector2(12, 0),
      radius: 45,
      constrain: unbounded,
      slide: false,
    );
    expect(mover.position, Vector2(-20, 0));
    crowd.move(
      mover,
      Vector2(-120, 0),
      radius: 45,
      constrain: unbounded,
      slide: false,
    );
    expect(mover.position.x, lessThan(-100));
  });
  test('large circular bodies remain indexed across cell boundaries', () {
    final crowd = CrowdOccupancy();
    final mover = actor(-170, 0), large = actor(0, 0);
    crowd.rebuild([large, mover], (a) => a == large ? 130 : 45);
    crowd.move(
      mover,
      Vector2(400, 0),
      radius: 45,
      constrain: unbounded,
      slide: false,
    );
    expect(mover.position.x, lessThanOrEqualTo(-170));
  });
  test('pending arrivals reserve body space before mounting', () {
    final crowd = CrowdOccupancy();
    final actors = [for (var i = 0; i < 40; i++) actor(0, 0)];
    for (final body in actors) {
      expect(crowd.place(body, 38, unbounded), isTrue);
    }
    separated(actors, 80);
    final released = actors.first.position.clone();
    crowd.forget(actors.first);
    final replacement = actor(released.x, released.y);
    expect(crowd.place(replacement, 38, unbounded), isTrue);
    expect(replacement.position.distanceTo(released), 0);
  });

  test(
    'occupied destinations and fast committed moves cannot cross bodies',
    () {
      final crowd = CrowdOccupancy();
      final mover = actor(-200, 0), blocker = actor(0, 0);
      crowd.place(mover, 38, unbounded);
      crowd.place(blocker, 38, unbounded);
      crowd.move(
        mover,
        Vector2(600, 0),
        radius: 38,
        constrain: unbounded,
        slide: false,
      );
      expect(mover.position.x, lessThanOrEqualTo(-80));
      expect(mover.position.x, greaterThan(-100));
      expect(mover.position.y, 0, reason: 'Committed direction must not bend');
      separated([mover, blocker], 80);
    },
  );

  test('mounting a pre-indexed saved crowd resolves existing overlaps', () {
    final crowd = CrowdOccupancy();
    final actors = [for (var i = 0; i < 120; i++) actor(0, 0)];
    crowd.rebuild(actors, (_) => 38);
    for (final body in actors) {
      expect(crowd.place(body, 38, unbounded), isTrue);
    }
    separated(actors, 80);
  });

  test('spawn relocation respects the safe distance from the player', () {
    final crowd = CrowdOccupancy();
    final actors = [for (var i = 0; i < 12; i++) actor(200, 0)];
    for (final body in actors) {
      expect(
        crowd.place(
          body,
          38,
          unbounded,
          allowed: (point) => point.length >= 180,
        ),
        isTrue,
      );
      expect(body.position.length, greaterThanOrEqualTo(180));
    }
    separated(actors, 80);
  });

  test('pursuit yields and slides around a stationary enemy', () {
    final crowd = CrowdOccupancy();
    final mover = actor(-200, 0), blocker = actor(0, 0);
    crowd.place(mover, 38, unbounded);
    crowd.place(blocker, 38, unbounded);
    for (var i = 0; i < 400; i++) {
      final direction = (Vector2(200, 0) - mover.position).normalized();
      crowd.move(mover, direction * 2, radius: 38, constrain: unbounded);
      separated([mover, blocker], 80);
    }
    expect(mover.position.x, greaterThan(100));
    expect(blocker.position, Vector2.zero());
  });

  test('forty converging enemies keep separate bodies and keep pursuing', () {
    final crowd = CrowdOccupancy(), tactics = EnemyTactics();
    final actors = [for (var i = 0; i < 40; i++) actor(500, 0)];
    for (final body in actors) {
      expect(crowd.place(body, 38, unbounded), isTrue);
    }
    final startingMean =
        actors.fold<double>(0, (sum, a) => sum + a.position.x) / actors.length;
    for (var frame = 0; frame < 900; frame++) {
      tactics.rebuild(actors);
      crowd.rebuild(actors, (_) => 38);
      for (final body in actors) {
        final desired = EnemyTactics.intent(
          EnemyKind.scorpion,
          body.position,
          Vector2(-frame * .65, 0),
          Vector2(-39, 0),
          tactics.side(body),
        );
        final before = body.position.clone();
        crowd.move(
          body,
          tactics.spaced(body, desired),
          radius: 38,
          constrain: unbounded,
          side: tactics.side(body),
        );
        expect(body.position.distanceTo(before), lessThanOrEqualTo(1.0001));
      }
      if (frame % 30 == 0) separated(actors, 80);
    }
    separated(actors, 80);
    final endingMean =
        actors.fold<double>(0, (sum, a) => sum + a.position.x) / actors.length;
    expect(endingMean, lessThan(startingMean - 200));
  });

  test('spawn search fails safely when geometry has no spare room', () {
    final crowd = CrowdOccupancy();
    void tinyRoom(Vector2 point) => point.setZero();
    expect(crowd.place(actor(0, 0), 38, tinyRoom), isTrue);
    expect(crowd.place(actor(0, 0), 38, tinyRoom), isFalse);
    crowd.clear();
    expect(crowd.place(actor(0, 0), 38, tinyRoom), isTrue);
  });

  test(
    'director throttles full arena and visible crowds without catch-up waves',
    () {
      final director = EncounterDirector();
      expect(director.canReinforce(arena: 19, visible: 17), isTrue);
      expect(director.canReinforce(arena: 20, visible: 0), isFalse);
      expect(director.canReinforce(arena: 18, visible: 18), isFalse);
      director.advance(3600);
      expect(director.populationLimit, 60);
      expect(director.visibleLimit, 44);
      expect(director.canReinforce(arena: 60, visible: 2), isFalse);
      expect(director.canReinforce(arena: 50, visible: 44), isFalse);
      expect(director.canReinforce(arena: 59, visible: 43), isTrue);
      expect(
        director.advance(.01),
        isFalse,
        reason: 'Waiting at capacity must not bank a spawn burst',
      );
    },
  );
}
