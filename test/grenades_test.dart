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
  test(
    'fuse is short, flight bounces off walls, contact arms after release',
    () {
      final f = GrenadeFlight(Offset.zero, const Offset(600, 0));
      f.advance(.1, blocked: (_, b) => b.dx >= 40, contact: (_, _) => true);
      expect(f.spent, isFalse);
      expect(f.velocity.dx, lessThan(0));
      expect(f.position.dx, lessThan(40));
      f.advance(.1, blocked: (_, b) => b.dx >= 40, contact: (_, _) => true);
      expect(f.spent, isTrue);
      final fuse = GrenadeFlight(Offset.zero, const Offset(600, 0));
      fuse.advance(1.39, blocked: (_, _) => false, contact: (_, _) => false);
      expect(fuse.spent, isFalse);
      fuse.advance(.01, blocked: (_, _) => false, contact: (_, _) => false);
      expect(fuse.spent, isTrue);
      expect(fuse.position.dx, inInclusiveRange(300, 440));
    },
  );
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
}
