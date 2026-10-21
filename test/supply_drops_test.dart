import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/supply_drops.dart';

void main() {
  late SupplyDrops drops;
  var lands = 0, rewards = 0, breaks = 0;
  var rewardAllowed = true;
  final charges = <int>[];
  const center = Offset(500, 0);
  void advance(double dt, {Offset player = center}) => drops.advance(
    dt,
    player: player,
    pickPosition: () => center,
    onLand: (_) => lands++,
    onWarning: () {},
    onBreak: () => breaks++,
    onCharge: charges.add,
    onReward: () {
      if (!rewardAllowed) return false;
      rewards++;
      return true;
    },
  );
  void landed() {
    advance(drops.nextIn);
    expect(drops.drop!.phase, SupplyPhase.warning);
    advance(1.8);
    expect(drops.drop!.phase, SupplyPhase.falling);
    advance(.65);
    expect(lands, 1);
  }

  setUp(() {
    drops = SupplyDrops()..reset(14);
    lands = rewards = breaks = 0;
    rewardAllowed = true;
    charges.clear();
  });

  test('timed landing, hold capture, one reward, then claimed breakdown', () {
    expect(drops.drop, isNull);
    expect(drops.nextIn, inInclusiveRange(22, 32));
    landed();
    for (var i = 0; i < 4; i++) {
      advance(1);
    }
    expect(drops.drop!.capture, 4);
    advance(4, player: const Offset(-400, 0));
    expect(drops.drop!.capture, 4); // Leaving pauses progress, not expiry.
    expect(charges, isNotEmpty);
    advance(4);
    expect(rewards, 1);
    expect(drops.drop!.phase, SupplyPhase.opened);
    expect(drops.drop!.claimed, isTrue);
    advance(3);
    expect(breaks, 1);
    expect(drops.drop!.phase, SupplyPhase.breaking);
    advance(1.3);
    expect(drops.drop, isNull);
    expect(drops.nextIn, inInclusiveRange(55, 80));
    expect(lands, 1);
    expect(rewards, 1);
  });

  test('unclaimed pod expires and disappears without awarding anything', () {
    landed();
    advance(50, player: Offset.zero);
    expect(drops.drop!.phase, SupplyPhase.breaking);
    expect(rewards, 0);
    expect(breaks, 1);
    advance(1.3, player: Offset.zero);
    expect(drops.drop, isNull);
  });

  test('save/restore never repeats impact or captured rewards', () {
    landed();
    advance(3);
    final saved = drops.toJson();
    drops = SupplyDrops()..restore(saved);
    expect(drops.drop!.capture, 3);
    advance(5);
    expect(lands, 1);
    expect(rewards, 1);
    drops = SupplyDrops()..restore(drops.toJson());
    advance(4.3);
    expect(drops.drop, isNull);
    expect(rewards, 1);
    expect(lands, 1);
  });

  test('busy upgrade grace cannot lose or duplicate an earned capture', () {
    landed();
    rewardAllowed = false;
    advance(8);
    expect(rewards, 0);
    expect(drops.drop!.phase, SupplyPhase.active);
    rewardAllowed = true;
    advance(.01);
    expect(rewards, 1);
    advance(.01);
    expect(rewards, 1);
  });

  test('slow frames show warning and malformed phases are rejected', () {
    advance(100);
    expect(drops.drop!.phase, SupplyPhase.warning);
    expect(lands, 0);
    final json = drops.toJson();
    (json['drop'] as Map)['elapsed'] = 40;
    expect(() => SupplyDrops().restore(json), throwsFormatException);
  });
}
