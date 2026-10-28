# Walker workshop — first procedural rig study

Access: Menu → Training → Walker workshop, before starting a run. No normal
combat roster, save, reward or backend changes. Not installed on the iPhone in
this implementation step.

Breach/Foundry clips render the actual shared workshop painter at844×390,
15fps,24 active seconds:4s each walk, strafe, turn, stand, brace, stand/recover.
They are simulation captures, not phone gameplay/performance proof. The
heading sheet compares quarter-turn chassis directions and brace on both floors.

Source atlas remains1774×887. Workshop owns6294152 decoded RGBA bytes; shared
cache in this setup owns21983744 bytes. Floors are borrowed, not counted twice.
This is approximately26.97MiB decoded art, not process/GPU allocation or device
performance. The workshop lives before an active run to avoid retaining a fully
developed paused encounter beside its new atlas.

Final make verify: analyzer clean;816 tests passed,5 intentional skips.
Focused rig, workshop, menu and loadout regressions:19 passed. These include
actual planted feet/fixed limb lengths through direction changes and brace,
30/60/120Hz equivalence, stationary blocked root, independent360-degree gun
tracking, art ownership including pending disposal, close-view touch alignment
and background freeze. Menu/loadout regressions cover the new narrow footer.

Open: final proportions, directional art/depth/lighting, real occupancy/cover
and foot-placement integration, physical gait weight/comfort/performance.
No firing, recoil, charge, homing rockets, sky descent or death explosion yet.
This first slice is a rig review, not the completed mechanical boss.
