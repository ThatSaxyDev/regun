# Boss arrival, portal departure and freeze focus

26 October 2026 — normal-game candidate. Creator visual/comfort acceptance remains
open; tests, captures and installation do not grant it.

## Player behavior

A boss entrance holds the entire native fight, eases the camera to the committed
spawn point, draws its geometric portal, materializes the boss, then returns to the
player and releases combat with a slightly wider view (zoom .88). Boss pairs share
one held reveal with both committed spawn locations framed. Pause/background stop
the reveal; combat does not run while the player is away from view. Inputs, damage,
projectiles, enemies, hazards, reload/grenade/director/supply clocks do not advance.
Pending actors can finish loading without zero-dt collision/attack updates.

On defeat the **camera never pans to the corpse**. A world-space portal opens at
the actual death location and draws the body away. The component has no camera
access, runs whether on/off screen, and disappears without blocking combat. The
view eases toward normal only after the last living boss is defeated; a surviving
partner retains the wider view. Boss rewards/cleanup remain once-only.

Eight seals share chipped concentric etchings and induction strokes inspired by
Aura Salad, but have different grammar: Shadow's broken pentad, Demon's horns,
Queen's hooked limbs, Bellkeeper's bell/clapper marks, Magistrate's linked clasps,
Saint's glass diamonds, Sovereign's kiln vents, Marshal's cartridge/iron sigils.
No new bitmap, particle components, damage geometry or texture-budget increase.
Floor priority keeps the seal/corpse beneath living actors; body/root attack
coordinate systems and boss sizes/hitboxes are unchanged.

The large victory card is now a compact HUD strip, with the boss title, rotating
Vanquished/Defeated/Slain/Overthrown/Conquered/Broken/Felled/Crushed wording and the
actual existing +2 HP reward. It ignores pointers, queues paired defeats and fits
enlarged text. Defeat wording cycles without consuming gameplay RNG.

## Soft focus on held scenes

Both boss reveals and player upgrade infusions use a shared charcoal radial
focus. The action stays clear; peripheral arena shading follows a smooth
simulation-clock fade in and out. It is not a sudden global dim, white spotlight,
flash, camera shake or input layer. Its fade reaches zero at both endpoints.

Reduced Motion keeps the camera player-anchored, uses settled materialization and
ward geometry, omits the corpse sink/squeeze, and lowers focus contrast while
retaining fades. Zoom changes settle without a sweep. Normal upgrade timing and
the exactly-once recovery pushback are preserved.

## Safety and review evidence

The reveal clock is cosmetic and is not replayed on Continue. Pending/unloaded
bosses are still included in the real checkpoint with their initial maximum HP,
so a save during loading cannot lose the boss. Existing actor schema remains2.
Training replacement/restart/disposal retire reveal/departure ownership. Corpse
art acquires its own atlas lease, releases late/failed/retired loads safely, and
never blocks Flame's lifecycle queue while waiting for cosmetic I/O. It reuses
the actual boss's death pose and existing ambient grade.

The dedicated test covers all eight bosses on both floors, held incoming damage
and grenade input, pause, unchanged simulation time, pair/wide-view lifetime,
Continue, Reduced Motion, off-screen defeat and no-corpse-pan assertions. Existing
active-combat fixtures explicitly finish the held reveal first and allow the
longer portal departure to finish before expecting corpse textures to retire.

`mirror-saint.mp4` and `upgrade-focus.mp4` are normal-speed 844×390 game-render
captures, not physical-phone footage/FPS proof. All sixteen boss/floor sequences
are reproducible with:

```
REGUN_BOSS_PORTAL_CLIPS=1 flutter test test/boss_portal_test.dart
```

Physical phone comfort/readability, crowded combat and portal art acceptance are
still open. Review the materialization, gentle darkness, return before release,
non-obstructive victory notice and absence of a corpse camera cut.

## Online and release scope

Online clients share the compact notice and authoritative upgrade-confirmation
focus fade. The new boss cinematic hold/pan/portal lifecycle currently applies to
native Solo/Training. **Hosted co-op boss arrival requires a coordinated server
hold/capability path and is not represented as implemented or deployed here.**
No client-only camera pan is added while an authoritative online fight continues.
This pass does not change server admission, balance, attacks, rewards, historical
catalogues or deployment state. Earlier IPA exports do not contain this revision.

## Verification and phone delivery

Analyzer clean. All sixteen boss/floor reveal/departure captures and dedicated
pause/pair/Continue/Reduced Motion checks passed. The final portal/upgrade/victory
focused run passed nine tests, including complete checkpoint equality while held.
The mixed lifecycle/history/Rush sequence passed three tests. Full suite reached
773 passes/five intentional skips with four older attack fixtures attempting
combat during the newly required hold; those fixtures now finish the reveal
before testing attacks, and all six targeted laser/retreat/dodge cases pass.
The earlier broad four-file regression reached81 passes with one input fixture;
that fixture was likewise corrected and all five boss-revision tests passed.
No attack strength, damage, immunity or timing assertions were weakened.

Normal signed `lib/main.dart` **1.0.0+25** built with the existing local release
configuration, installed on the paired iPhone and launched. The pre-existing
version change was preserved. No TestFlight upload, hosted deployment or matching
new IPA export is claimed. Native speaker/motion comfort, full physical crowd
review and visual acceptance remain with the creator.
