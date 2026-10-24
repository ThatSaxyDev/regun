import 'package:flutter_test/flutter_test.dart';
import 'package:regun/systems/rail_lance_timing.dart';
import 'package:regun/systems/rank_effect_values.dart';

void main() {
  test('Rail previews separate charge and recovery without weakening its firing cycle', () {
    expect(RailLanceTiming.chargeSeconds, .65);
    expect(RailLanceTiming.fullChargeMultiplier, 1.25);
    expect(RailLanceTiming.recovery(1.1, 1), closeTo(.45, 1e-10));
    expect(RailLanceTiming.cycle(1.1, 1), closeTo(1.1, 1e-10));
    expect(RailLanceTiming.recovery(.8, .4), closeTo(.15, 1e-10));
    final base = RankEffects.values('quickTrigger', 0, {
      'weapons.railLance.cadence': 1.1,
    }, weapon: 'railLance');
    final max = RankEffects.values('quickTrigger', 8, {
      'weapons.railLance.cadence': 1.1,
    }, weapon: 'railLance');
    expect(base['Aim charge (s)'], .65);
    expect(base['Release interval (s)'], closeTo(1.1, 1e-10));
    expect(max['Aim charge (s)'], .65);
    expect(max['Release interval (s)'], closeTo(.8, 1e-10));
    final damage = RankEffects.values('heavyLoad', 0, {
      'weapons.railLance.damage': 11.25,
    }, weapon: 'railLance');
    expect(damage['Quick shot damage'], 11.25);
    expect(damage['Full charge damage'], 14.0625);
  });
}
