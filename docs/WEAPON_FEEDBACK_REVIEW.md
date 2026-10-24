# Weapon feedback and menu corrections

24 October 2026. This supersedes the first three-weapon tuning/presentation in
[THREE_WEAPONS_REVIEW.md](THREE_WEAPONS_REVIEW.md). Release identity stays at the
creator's existing 1.0.0+21. No deployment, balance publication or installation is
implied by the local builds.

## Ring Caster

The cutter starts compact at the actual muzzle and slowly travels along its
committed firing heading while opening. Its trailing edge moves outward instead
of growing backward around the survivor. Full launch/expansion takes 1.1s by
default; 65% of authored range is forward travel and 35% is cutting radius. Their
sum preserves the existing forward reach. Releasing recalls the cutter toward
the current gun while retracting it; maximum outer hold/automatic recall remains.

A new generated weathered iron/brass saw annulus replaces the rectangular chain.
The authored chipped teeth rotate through one bounded 96-segment textured mesh.
Radial mapping preserves configurable edge width (new default 28); the initial
band stays narrow while the compact cutter emerges. Interior remains empty,
cover blocks cuts, and each body is hit at most once outward and once returning.
The 256×256 texture is leased only while Ring Caster is equipped, including
Training switch, pending-load cancellation and route disposal handling.

Frontier checkpoints write schema 2, retaining launch origin/heading and the
orb crossing ledger. Schema 1 reads remain supported; an already-paid legacy
player-centered ring finishes with its legacy center rule. Continue never
creates held input or replays a recorded crossing.

Original generated master, exact prompt, hash and rendering metadata are in
`art/source/weapons/frontier/cutter`. Built-in `image_gen` was used with the
existing Ring Caster gun as style reference; no fallback provider. The packaged
PNG is the unmodified master. Admin exports also include the cutter preview.

## Houndrack

Default acquisition half-angle 45° and turn rate 4.5rad/s replace 18°/.9rad/s.
Each rocket still owns one initial target; cover/body interception, finite life,
remaining range and 12-flight cap remain authoritative. The motor eases from 30%
of projectile speed to 100% over .55s, rather than immediately feeling like a
bullet. Exhaust grows with that motor progress. Guidance and motor time remain
editable through the shared catalog.

`WeaponBallistics` explicitly gives Houndrack a constant 1× distance multiplier.
Near and far primary hits deal equal base damage; secondary splash also has no
distance reduction. This does not remove deliberate build bonuses. The shared
admin/API components expose flat distance multiplier plus launch/full speeds.

## Storm Orb

Bodies no longer terminate the orb. Swept crossings add the weapon's primary
base damage once per distinct body, in addition to nearby arc pulses. This base
damage is the editable **Extra damage per crossed body** component (3.8 by
default); arc damage remains 1.2 per tick by default. A 64-owner crossing ledger
prevents repeated body damage and persists through Continue. Walls, remaining
range and lifetime still end flight. Arcs retain cover, tick, target and proc
budgets; secondary arcs do not become primary proc chains.

## Weapon audio

Rockets now have pressure ignition plus a gas-propulsion tail, and a quiet shared
flight hiss. Orb launch/flight use restrained electrical body, with distinct
successful-arc zaps and body-crossing crackles. Audio follows actual accepted
hits, not render frames. Flight events are shared per equipped weapon, limited
to 220ms/320ms intervals; zap/pass cues have 120ms overlap gates. No per-projectile
loop voice is added. Pause freezes new cue scheduling; existing short one-shots
end within .28s. Mute/volume and the SoLoud path remain intact.

See [audio review](art/FRONTIER_AUDIO_REVIEW.md) for regeneration, provenance,
levels and the listening mix. Native speaker listening remains for the creator.

## Admin and mobile power-up presentation

At wide detail widths the item image sits on the right beside the title,
description and introductory copy. Phone and larger-text narrow panes stack.
The same layout serves weapons, survivors, effects and upgrades.

The admin icons were exported from the existing game `UpgradeGlyph` mapping.
Mobile now displays those glyphs at 32px. The power-up picker has a compact
heading/level row, wider offer columns and a persistent 48px reroll footer. Long
or larger-text offers scroll inside the remaining body instead of pushing bottom
actions out of the viewport. Title/category share the icon row; cards retain
ban, detail, funded-choice and stale-offer protections. Default phone landscape
shows all three offers, ban controls and reroll together.

## Revolver identity

The Revolver now owns **one innate enemy ricochet**, independent of all ranks,
special slots and XP. `weapons.revolver.ricochets` is a first-class weapon field
(default 1, integer 0–3), shown beside base damage in admin. It is included in
API/catalog snapshots, mobile firing and authoritative hosted firing. Existing
snapshots lacking the new field use 1. A bought Ricochet rank adds to that base;
rank 0 stays rank 0. Bank Shot can be useful immediately when the base count is
positive. Fusion requirements are unchanged.

The existing bounce path supplies a different enemy within 500 units, solid-cover
checks and 70% base damage retention. It keeps cumulative distance/remaining range,
owner hit ledgers and the twice-original-damage ceiling. No extra round is spent
for a bounce. Admin/API component and rank previews show the intrinsic count and
total after purchased ranks. The authenticated preview endpoint now supports
Revolver as well as the three new primaries; hosted admission for the three new
weapons remains gated.

The synchronized catalog now has 24 weapons and 314 numeric fields. Historical
published/bundled catalogs remain readable. Existing draft backup/rebase,
authentication, publishing and run snapshot rules remain authoritative.

[Validation, actual rendered stages and audio](validation/weapon-feedback-2026-10-24/README.md).
Physical tuning, motion comfort and audio acceptance remain creator playtests.
