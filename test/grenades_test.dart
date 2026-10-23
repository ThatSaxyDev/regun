import 'package:flutter/material.dart';
import 'package:regun/presentation/grenade_art.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/grenades.dart';

void main() {
  test(
    'two charges recharge sequentially; second throw does not restart first',
    () {
      final g = GrenadeInventory();
      expect(g.spend(18), isTrue);
      expect(g.spend(18), isFalse);
      g.advance(.3, 18);
      expect(g.spend(18), isTrue);
      expect(g.charges, 0);
      expect(g.remaining, closeTo(17.7, .001));
      g.advance(17.7, 18);
      expect(g.charges, 1);
      expect(g.remaining, closeTo(18, .001));
      g.advance(18, 18);
      expect(g.charges, 2);
      expect(g.remaining, 0);
    },
  );
  test('saved flight and charge clocks resume exactly without replay', () {
    final inventory = GrenadeInventory()..spend(18);
    inventory.advance(3, 18);
    final copy = GrenadeInventory()..restore(inventory.toJson());
    expect(copy.toJson(), inventory.toJson());
    final f = GrenadeFlight(Offset.zero, const Offset(600, 0));
    f.advance(.4, blocked: (_, _) => false, contact: (_, _) => false);
    final saved = GrenadeFlight.restore(f.toJson());
    f.advance(.4, blocked: (_, _) => false, contact: (_, _) => false);
    saved.advance(.4, blocked: (_, _) => false, contact: (_, _) => false);
    expect(saved.toJson(), f.toJson());
    expect(
      () => copy.restore({...copy.toJson(), 'charges': 3}),
      throwsFormatException,
    );
    expect(
      () => GrenadeFlight.restore({...f.toJson(), 'age': double.nan}),
      throwsFormatException,
    );
  });
  test('fuse follows a ground bounce; walls bounce and enemy contact never detonates', () {
    final f = GrenadeFlight(Offset.zero, const Offset(600, 0));
    f.advance(.1, blocked: (_, b) => b.dx >= 40, contact: (_, _) => true);
    expect(f.spent, isFalse);
    expect(f.velocity.dx, lessThan(0));
    expect(f.position.dx, lessThan(40));
    f.advance(.1, blocked: (_, b) => b.dx >= 40, contact: (_, _) => true);
    expect(f.spent, isFalse);
    final fuse = GrenadeFlight(Offset.zero, const Offset(600, 0));
    fuse.advance(1.0, blocked: (_, _) => false, contact: (_, _) => true);
    expect(
      fuse.lift,
      greaterThan(0),
      reason: 'First ground impact has bounced before fuse expiry',
    );
    fuse.advance(.39, blocked: (_, _) => false, contact: (_, _) => false);
    expect(fuse.spent, isFalse);
    fuse.advance(.01, blocked: (_, _) => false, contact: (_, _) => false);
    expect(fuse.spent, isTrue);
    expect(fuse.position.dx, inInclusiveRange(300, 440));
  });
  test(
    'grenade ranks are bounded without extra charges or primary ammo changes',
    () {
      expect(GrenadeSpec.damage(0), 8);
      expect(GrenadeSpec.radius(0), 205);
      expect(GrenadeSpec.damage(4.5), closeTo(15.2, .001));
      expect(GrenadeSpec.radius(4.5), lessThan(280));
      expect(GrenadeSpec.recharge(4.5), 11.25);
    },
  );
  test(
    'grenade aiming captures one pointer, bounds range and cancels at center',
    () {
      final aim = GrenadeAim();
      expect(aim.begin(1, Offset.zero), isTrue);
      expect(aim.begin(2, Offset.zero), isFalse);
      aim.move(2, const Offset(90, 0));
      expect(aim.direction, isNull);
      aim.move(1, const Offset(-32, 0));
      expect(aim.direction, const Offset(-1, 0));
      expect(aim.power(48), closeTo(.7, .001));
      aim.move(1, const Offset(-500, 0));
      expect(aim.power(48), 1);
      aim.move(1, Offset.zero);
      expect(aim.cancelled, isTrue);
      aim.cancel();
      expect(aim.active, isFalse);
    },
  );
  test(
    'preview matches actual fuse/bounce path and variable throw distance',
    () {
      for (final power in [.4, .7, 1.0]) {
        final preview = grenadePreview(
          GrenadeFlight(Offset.zero, Offset(600 * power, 0)),
          blocked: (_, b) => b.dx > 200,
          contact: (a, b) =>
              grenadeSegmentContact(a, b, const Offset(-30, 0), 12),
        );
        final flight = GrenadeFlight(Offset.zero, Offset(600 * power, 0));
        for (var i = 0; i < 168 && !flight.spent; i++) {
          flight.advance(
            1 / 120,
            blocked: (_, b) => b.dx > 200,
            contact: (a, b) =>
                grenadeSegmentContact(a, b, const Offset(-30, 0), 12),
          );
        }
        expect((preview.last.ground - flight.position).distance, lessThan(.01));
      }
    },
  );
  testWidgets(
    'online grenade control holds outside bounds, rejects second pointer and cancels',
    (tester) async {
      final aim = GrenadeAim();
      final released = <(Offset?, double)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: GrenadeAimButton(
              size: 56,
              charges: 2,
              progress: 1,
              remaining: 0,
              opacity: .8,
              input: aim,
              onChanged: () {},
              onThrow: (d, p) => released.add((d, p)),
            ),
          ),
        ),
      );
      final at = tester.getCenter(find.byType(GrenadeAimButton));
      final first = await tester.startGesture(at, pointer: 71);
      expect(released, isEmpty);
      await first.moveBy(const Offset(0, -75));
      expect(aim.direction, const Offset(0, -1));
      final second = await tester.startGesture(at, pointer: 72);
      await second.up();
      expect(aim.active, isTrue);
      await first.up();
      expect(released.length, 1);
      expect(released.single, (const Offset(0, -1), 1.0));
      final cancel = await tester.startGesture(at, pointer: 73);
      await cancel.moveBy(const Offset(-20, 0));
      await cancel.cancel();
      expect(aim.active, isFalse);
      expect(released.length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
