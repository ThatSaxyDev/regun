# Regun: twelve more weapons, 21 → 33

24 October 2026 · **Three selected weapons implemented; remaining slots open.**

The creator selected **Houndrack, Storm Orb and Ring Caster** after the research
reset. This first tranche brings Solo/Training from 21 to **24** weapons. The other
nine additions have not been selected. The rejected original roster remains withdrawn.

See [the implementation and review packet](THREE_WEAPONS_REVIEW.md) for mobile,
admin, API, art, audio, verification and access details. The comparison below
records the original 21-weapon baseline; it is historical design context.
[Research and sources](WEAPON_EXPANSION_RESEARCH.md) remain available.

## 1. The earlier guides and what carries forward

The main production guide is [FIFTEEN_WEAPON_EXPANSION_PLAN.md](FIFTEEN_WEAPON_EXPANSION_PLAN.md),
particularly its source-packet, socket, event-timeline and acceptance requirements.
The next expansion is [SIX_WEAPONS_AND_WEIGHT_PLAN.md](SIX_WEAPONS_AND_WEIGHT_PLAN.md).
The ten-weapon plan is explicitly superseded. Read the implementation evidence
alongside the proposals:

- [ARSENAL_IMPLEMENTATION_PROGRESS.md](ARSENAL_IMPLEMENTATION_PROGRESS.md) and
  [WEAPON_DEVICE_REVIEW.md](WEAPON_DEVICE_REVIEW.md): Hammer was replaced by
  Longwatch; fire needed actual moving tongues; lobbers needed independent distance
  control; capacity and cadence changed after device feedback.
- [ENDGAME_WEAPONS_REVIEW.md](ENDGAME_WEAPONS_REVIEW.md) and
  [HEAVY_WEAPON_FEEL_REVIEW.md](HEAVY_WEAPON_FEEL_REVIEW.md): the first six needed
  stronger visible payoff, tangible mechanisms and distinct audio. Twin's brand
  and shatter and Bell's bright pressure front supersede their original seeds.
- [WEAPON_ENEMY_REACTIONS.md](WEAPON_ENEMY_REACTIONS.md): force is a gameplay
  contract, independent of drawing and damage. Heavy art alone cannot supply punch.
- [WEAPON_POWER_IMPLEMENTATION_REVIEW.md](WEAPON_POWER_IMPLEMENTATION_REVIEW.md),
  [WEAPON_DEVICE_REVIEW.md](WEAPON_DEVICE_REVIEW.md) and the latest
  [progress entries](REGUN_PROGRESS.md): current power, live balance and today's
  Rail changes supersede old damage/charge tables.
- [ARMORY_IMPLEMENTATION.md](ARMORY_IMPLEMENTATION.md) and
  [WEAPON_SCRAP_UNLOCK_PLAN.md](WEAPON_SCRAP_UNLOCK_PLAN.md): six existing weapons
  now require earned-Scrap purchase; boss thresholds alone do not grant them.

The successful production pattern is a complete vertical slice: behavior →
authored sprite parts and measured sockets → reload and sound → real hit/reaction
feedback → upgrades/passives → saves/catalogues/access → verification and review.
Do not create twelve enum entries and call the expansion finished. Do not revive
the rejected Hammer or a complicated harpoon replacement.

## 2. Current baseline, checked against source

`lib/data/loadout.dart` has 21 weapon IDs. Existing roles already cover:

| Existing weapons | Role to preserve |
|---|---|
| Pump / Frost / Cyclone | Immediate spread, freeze control, rapid heavy close volleys |
| Carbine / Burst / Belt-fed | Responsive automatic fire, three-shot windows, sustained spool |
| Revolver / Longwatch / Rail | Immediate precision, deliberate release, charged penetration |
| Arc / Prism / Cinder | Electrical chains, intercepted heat beam, sweeping fire |
| Rivet / Spore / Mortar | Reload-triggered payloads, persistent slowing patches, aimed ground blasts |
| Reaper / Twin / Flak | Return-path cuts, alternating brand/shatter, forward fragmentation |
| Anchor / Faultline / Bell | Gather/crush, sequential ground lane, cone/conditional echo |

Important differences from the old plans:

- Ten survivors, two arenas and eight bosses now need compatibility. Upgrade
  counts should come from the current enum/catalogue, including later dash and
  grenade reserve additions, rather than a historical 33/41-family constant.
- Universal tactical reload is implemented: manual reload with ammo takes 70%
  duration and omits the empty-only closing action. Full completion grants ammo;
  held aim cannot interrupt. Preserve current shotgun-specific shell timing and
  pickup refill behavior when extending these contracts.
- Rail now supports early release, automatic full discharge at .65s, a persisted
  anti-flick cooldown and revision-3 power/geometry. Its current base is 11.25,
  with another 25% at full charge. Do not compare new guns only to old 7-damage Rail.
- `WeaponPowerBalance` pins numerical behavior and `LiveBalance` validates a
  complete catalogue with historical catalogue IDs. New fields need an explicit
  catalogue migration; adding enum defaults alone is insufficient.
- `WeaponType.availableOnline` admits the original four. The sibling server also
  defines Burst, but this does not mean the client admits all five, much less 21.
  Preserve the actual negotiated boundary.
- Six shop weapons are Belt, Longwatch, Flak, Anchor, Cyclone and Bell. Existing
  receipt ownership and purchase-only policy must survive the expansion.
- At investigation, the only pre-existing working-tree edit was `pubspec.yaml`
  changing 1.0.0+20 to 1.0.0+21. Leave it intact; old +7/+11/+15 notes are historical.

## 3. Revised concept direction

The [research report](WEAPON_EXPANSION_RESEARCH.md) replaces the rejected roster
and numerical seeds. Its strongest starting briefs are:

| Direction | Distinct interaction | Status |
|---|---|---|
| Houndrack micro-rocket machine gun | Rapid tiny propelled rockets with mild single-target correction | Creator direction retained; mechanics/numbers still to specify |
| Traveling lightning orb | Damage while passing beside a pack, before direct contact ends the flight | Research-backed candidate; not approved |
| Directly guided blade cluster | Continuously steer a finite active formation with primary aim | Research-backed candidate; touch control proof needed |
| Expanding/retracting cutting ring | Manage an edge radius with hold/release and move through formations | Research-backed candidate; clarity/control proof needed |

Counterfire, disposable sentry reload and enemy-fed pressure weapons remain
conditional directions with substantial balance/overlap concerns. They are not
accepted additions. Five slots remain unfilled even if all three survive; more
remain if any fails. The target is still twelve additions and33 total.

## 4. Next gates

1. Review plain behavior briefs against their nearest existing weapon before
   themed names, damage tables, unlock prices or large art batches.
2. After implementation is authorized, prove rocket identity, orb near-miss value,
   touch-guided blades and ring edge crossing with small real-renderer slices.
3. Advance only accepted concepts through the prior production guide's complete
   art/audio/upgrade/passive/save/access and budget packet.
4. Continue selecting genuinely useful concepts until all twelve slots are earned.
   A researched precedent alone is not acceptance or a reason to fill a slot.

Preserve current21 behavior, balance snapshots, receipt ownership, independent
controls and online content admission. No8/4 unlock split, prices, gates, code
changes, new art, installation or deployment is selected by this planning pass.
