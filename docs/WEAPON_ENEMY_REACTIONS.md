# Weapon-proportionate enemy reactions — 22 October 2026

All 21 solo/Training weapons now have explicit physical responses in
`WeaponReaction`, separate from damage, hitbox, projectile drawing and proc flags.
This supersedes the older eight-unit fallback for most expansion weapons. Damage,
magazines, cadence, range, reloads, weight and existing abilities are unchanged by
this reaction pass.

Distances below are world units for an ordinary unarmoured body in free space.
Stagger briefly holds pursuit/ordinary attack clocks and the sprite pose; the
impulse eases out while movement intent recovers. It is deliberately distinct from
Frost's longer freeze. Actual displacement depends on enemy mass and free space.

| Weapon | Shove | Decay (s) | Brief stagger (s) | Purpose |
|---|---:|---:|---:|---|
| Pump Shotgun | 58 | .18 | .09 | One broad close-range stop, not three stacked pushes |
| Carbine | 6 | .07 | — | Small sustained bullet nudges |
| Revolver | 36 | .16 | .055 | A distinct heavy-round kick |
| Arc Caster | 24 | .14 | .045 | Electrical jolt; weaker chained response |
| Burst Rifle | 10 | .09 | — | Short burst taps without stun-lock |
| Rail Lance | 76 | .22 | .13 | A forceful piercing stake |
| Rivet Driver | 14 | .11 | .025 | Small planted-hit bite, then stronger reload blast |
| Cinder Hose | 4 | .07 | — | Light contact flinch; lingering burn never shoves |
| Reaper Disc | 34 | .16 | .045 | Outbound cut; returning cut has 45% force and no stagger |
| Scrap Mortar | 90 | .25 | .15 | Strong radial blast |
| Belt-fed Repeater | 12 | .09 | — | Repeated heavier taps, with pursuit gaps |
| Frost Shotgun | 32 | .17 | .06 | Moderate shove retained when ice freezes the body |
| Prism Cutter | 4 | .07 | — | Light beam contact, not an impact cannon |
| Spore Lobber | 12 | .11 | — | Soft direct rupture; floor spores remain damage-over-time |
| Longwatch Sniper | 68 | .21 | .11 | Heavy piercing shot |
| Twin Verdict | 30 / 45 | .15 | .06 | Opening / paired shatter force |
| Flak Regent | 48 | .19 | .085 | Casing impact; weaker secondary fragments |
| Anchor Engine | 96 | .26 | .16 | Crush pushes outward after the existing pull |
| Faultline Driver | 82 | .25 | .15 | Heavy ground fracture |
| Cyclone Breacher | 64 | .21 | .10 | One strong volley response per victim |
| Mourning Bell | 112 | .29 | .20 | Broad powerful pressure stop; softer echo |

Secondary physical reactions remain secondary damage: they never gain primary
weapon procs. Grenades push 86/.25s with .14s stagger; mines 66/.22s/.10s;
Rivet detonation 54/.20s/.08s. Bell echo pushes 34/.16s, Flak fragments 10/.09s,
Arc jumps 10/.10s, upgrade shrapnel 7/.08s and Twin forks 26/.15s, all without
another hard stagger. Blasts point away from their explosion; cover and body-edge
blast eligibility still apply. Disc return force follows actual return travel.

## Bounds and resistance

- Existing resistance multiplies shove and stagger: normal 1, mummy .70, elite
  .65, shield .35. Bosses, nests and sentinels remain planted. Shields are braked
  and displaced lightly, without a full pursuit/attack hold.
- One .24s per-target force gate prevents pellet/beam/proc accumulation. A hit
  over 125% of the previous force can replace that impulse; it cannot add forces.
- Hard stagger has a separate .65s recovery from its start. Follow-up damage and
  displacement can occur, but cannot continually renew the hold.
- All displacement passes through existing actor occupancy/wall movement. Nearby
  bodies and walls absorb travel; there is no teleport or crowd penetration.
- Pause freezes clocks/force. Death clears pending force/freeze/stagger and permits
  the death animation. Freeze stops intent but no longer erases the ice hit shove.
- No new sprite atlas, screen shake, haptic or full-screen effect is introduced.
  Existing hit flashes/material impacts and Reduced Motion remain in use.

## Verification and review

`test/weapon_reaction_test.dart` checks every primary profile through accepted
combat hits, exact free-space displacement, mass, pellet suppression, recovery,
freeze, pause, death, secondary routing, radial cover and body/wall blocking.
Actual arsenal firing tests also assert delivery of the weapon's intended force;
Bell's committed echo specifically delivers its weaker response. Existing weapon
presentation and complete game regressions remain part of `make verify`.

The sibling server implements matching responses for its admitted weapons plus
ordnance/Arc/shrapnel; both repositories check the same reaction fixture. This
adds no online weapon admission and has not been deployed to a running server.

Hands-on review: compare all weapons in Training at base and VIII; test both
arenas, shields/mummies/elites, close crowds, wall corners, freeze and repeated
volleys. Heavy hits should visibly win space without removing the danger of a
pack. Check that aiming/reloading and enemy warnings remain readable. Automated
checks and installation do not establish physical balance or performance.

Final automated result: analyzer clean,453 Flutter tests passed (5 optional
skipped);93 backend tests, typecheck and module build passed. Signed143.2MB
1.0.0+11 installed in place on the creator's iPhone12. Evidence is saved under
`docs/validation/enemy-reactions-2026-10-22/`.
