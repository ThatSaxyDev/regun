# Weapon damage by distance — release 1.0.0+7

Direct weapon projectiles now reward approaching an enemy, with small close bonuses and conservative far floors. Damage is multiplied once at impact; damage/cadence/reload upgrades continue working normally. Weapon range, speed, spread, pellet counts and knockback are unchanged.

| Weapon | Close damage / distance from muzzle | Far damage / distance from muzzle |
| --- | --- | --- |
| Pump Shotgun | 120% through 120 units | 90% at 380+ units |
| Carbine | 110% through 100 units | 95% at 600+ units |
| Revolver | 112% through 110 units | 98% at 750+ units |
| Arc Caster | 108% through 100 units | 98% at 520+ units |

A smooth monotonic curve connects each pair. The shotgun has the strongest incentive to close; its damage drop stays modest because spread already reduces distant pellet connections. Revolver retains almost all of its distant damage, and Arc retains its ranged/chain role. These are relative to the previous projectile damage before the usual enemy defense/weak-point/execution effects, not guaranteed changes to kills-to-defeat every target.

`lib/systems/weapon_ballistics.dart` owns the tuning. Bands are fixed world distances, not fractions of upgraded range: range upgrades extend useful reach without extending the full close bonus. Longer shots settle at the listed floor rather than continuing toward zero.

`BulletComponent` measures cumulative projectile travel. Swept collision samples the first contact with the existing enemy-body circle, not the endpoint of a large simulation frame. Piercing samples the original unattenuated projectile damage separately at each target; it does not multiply prior falloff repeatedly. Bounces keep cumulative travel, apply the existing bounce retention/gain, and retain the twice-original-damage ceiling after the range adjustment. Moving the player or turning a ricochet cannot reset the close band. The final update step is clipped to remaining projectile range so a long frame cannot hit beyond it.

Only primary weapon projectiles apply this multiplier. Chains inherit the adjusted primary hit and apply their existing retention once; secondary bullets, drones, mines, burn and explosions do not receive another proximity multiplier. No proc budgets or upgrade caps are increased.

Regression checks cover all four curves, bounded monotonic damage, band continuity, first-contact distance, actual target health at near/mid/far distances under small and large simulation steps, piercing, ricochets, unchanged secondary damage and maximum range. Native close-range risk/reward, enemy kill breakpoints and long-run power-up combinations remain for playtest review. Automated simulations establish correctness/bounds, not a guarantee of subjective balance.

## Shotgun base assistance — 21 October 2026

The creator requested a stronger base shotgun alongside a shorter base reload. Each pellet is now 1.2 damage (20% higher); the distance curve above is unchanged. Three connected close pellets therefore deal 4.32 before defenses/upgrades, versus 3.6 previously. One through five missing shells reload in .8/1.4/2.0/2.6/3.2 seconds. Full-reload commitment, three pellets, cadence, range, speed, spread and knockback remain. `ShotgunReload` centralizes the revised shell timing for the clock and weapon mechanism; the original HUD Lottie is retained. Shared TypeScript fixtures use the same damage and timing. Treat physical risk/reward and late-build balance as pending creator review.
