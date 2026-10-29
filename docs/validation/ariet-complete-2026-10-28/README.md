# Ariet — complete native Training candidate

28 October 2026 · build1.0.0+29 installed/launched on the creator's physical network
connected iPhone12. No backend/admin/catalog publication or normal roster admission.

Open **Training → Start → Pause → Boss Practice → Ariet**. The selected weapon,
survivor, arena and build remain. Normal controls work. Take damage defaults Off;
enable it to test actual health loss and the existing Training recovery.

## Included

- Warned mechanical arrival/low hover, articulated pods, deliberate navigation,
  independently aimed side cannon and real muzzle/barrel recoil.
- Strafing run, four-shot broadside and two planted exhaust patches. Each finishes
  into a genuine cooling window. No passive body or hidden ram damage.
- At <=half HP, an eligible strafe can deploy TWO actual smaller Walkers:67.5% scale,
 50HP EACH, one pair total. Both legal landing sites are reserved before selection.
  Short cover stream, quiet staggered socket releases, flight, unfolding and no
  landing damage. Invalid dynamic arrivals resolve harmlessly.
- Escorts use real scaled body/feet/IK/muzzles and a restricted three-round burst
  policy. The encounter shares32 rounds and attack arbitration. Cannon/exhaust and
  guaranteed main recovery exclude escort gunfire. No escort rockets/death bombs.
- Compound machinery hit tests through all24 real weapon paths, empty gaps, one HP
  owner/proc ledger, body-edge blast queries, cover and bounded impacts.
- Non-damaging fatal power loss, controlled descent, dust impact and wreck. Owned
  bullets/escorts/pending drops stop at fatal transition. No Training XP/cores/heals/
  boss progress. Fight again appears after cleanup.
- Pause/background/upgrade/Training recovery freeze the timeline. Restart keeps the
  selected practice boss. Switching targets, rapid replacement and pending loads
  retire the exclusive mechanical owner and release its textures.

The source of truth for live candidate numbers is ARIET_BOSS_WORKSHOP_PLAN section15.
These remain test-candidate tuning, not physically accepted difficulty.

## Verification

`make verify`: clean analyzer;884 passed,5 existing intentional skips.
`test/ariet_combat_test.dart` covers full/moving/blocked volleys, committed routes,
shared capacity, one-hit budgets, two drops/fallback, fixed-clock equivalence,
recovery, shutdown and minimum-reach unfolding through fixed110/130 links.
`test/ariet_native_encounter_test.dart` enters via the real Training selector and
proves all three attacks, both50HP escorts, actual swept health loss, Training
recovery freeze/persistence, harmless destruction, all24 real weapon paths,
empty-gap misses, once-only blast damage and pending replacement/restart cleanup.
It also verifies active decoded art stays below32MiB for every selected weapon.
Full existing arsenal, support, boss, save and hosted-client regressions passed.

Main+pair owned decoded RGBA:4,849,664 bytes (one768px Ariet atlas, ONE1280px Walker
parts atlas). Floors/materials/character/weapon use their existing shared leases.
This is decoded-art accounting, not total GPU/process memory or an FPS result.
The development workshop retains its sharper inspection decode independently.

## Evidence

- [Native game-layer recording](native.mp4), [contact sheet](review-strip.png),
  [actual weapon-path game-layer still](native.png).
- Reproduce the40-second recording with:

```sh
REGUN_ARIET_FIGHT_CAPTURE=1 flutter test --no-pub test/ariet_native_encounter_test.dart
```

Recording uses RegunGame, the real components and materials/controls; it is a
rendered test capture, not physical phone footage. The Flutter HUD is separate
from the recorded game layer. It shows an enraged encounter and death/recovery
inspection; no synthetic replacement painter is used.

## What to try on the phone

1. Observe warnings and sideways escapes, then punish braking/cooling with a short
   weapon. Fly through/under the craft: there must be no invisible contact strike.
2. Keep moving across the side cannon, then linger near pods to provoke exhaust.
   Warning patches must stay planted, with usable front/rear gaps.
3. Bring HP below half, then leave room for a valid pass. Watch the cradles release
   two folded Walkers onto their warned sites. Clear one or keep firing at Ariet.
4. Turn Take damage On. Test each attack, dash/shields, defeat/recovery, pausing
   mid-warning/drop/unfold and resuming after backgrounding.
5. Kill the gunship with both escorts still alive. They must stop/power down and
   all owned shots disappear; its final descent must not cause a surprise blast.
6. Fight again, restart during loading and switch to Walker/another boss/Rush.
   Repeat on Foundry near cover and with different weapons/survivors.

Creator visual, sound, fairness, comfort and sustained device-performance review
remain open. Existing original Walker remains live in normal play; Ariet is only
this complete Training candidate until production admission is separately scoped.
