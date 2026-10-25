# Rocket impact, orb wind-up and capture ring — 25 October 2026

This supersedes the hold/recall Ring Caster behavior in THREE_WEAPONS_REVIEW.md
and WEAPON_FEEDBACK_REVIEW.md. Release identity stays 1.0.0+23. These three weapons
retain their existing solo/Training admission; this pass does not introduce a
second hosted combat implementation.

## Implemented behavior

Houndrack uses 2.2 direct damage, .13s cadence, 900 maximum speed, .25s motor
acceleration, .8 secondary splash and 65 splash radius in the bundled profile.
Direct victims do not also receive splash. Three direct base rockets kill a
normal 6HP mummy; a guarding 8HP Shield Warden retains its 70% frontal reduction.
Guidance, cover, live-flight capacity, ammo/reload and primary proc policy remain
intact. A .28s material ember blast reuses the existing combat atlas; a recorded
cannon/debris micro-explosion replaces the generic impact sound at .42 SFX gain.
Hit response is 28 units/.14s with .04s stagger before mass resistance, subject
to the existing per-target response cooldown. The audio generator and manifest
include the new mix; the preview stress reel verifies headroom, not speaker feel.

Storm Orb begins a .18s visible muzzle charge. Ammo/release provenance are spent
only at actual release. Sustained release spacing remains the configured firing
interval (1.1s bundled); charge runs inside that interval. Releasing aim,
reloading, pause/lifecycle cancellation and clearing the field discard unpaid
charge. Continue never restores held input or an unpaid queued shot. Setting
Pre-fire delay to zero disables the wind-up. Reduced Motion keeps the compact
charge core steady.

A new Ring Caster shot grows from radius28 to160 while traveling 65% of the
configured delivery reach (340 × .65 =221 base units). On reaching full size it
captures every exposed intersecting enemy, holds .2s and contracts over .55s at
that fixed center. Releasing aim or moving the player never recalls it. Range
upgrades scale delivery and capture radius; the base capture radius is now an
independent effect control. There is no old eight-body capture cap: the arena's
120-body emergency ceiling bounds the membership ledger. Solid cover prevents
capture and finishing damage. The ring deals one finishing hit, 4.5 ×1.5 =6.75,
to each still-living captured target. Expansion/interior do not tick damage.
This is damage, not unconditional deletion of elites, heavy enemies or bosses.

Walking, committed lunges and forced displacement share containment through
moveActor/moveTo. Contraction pulls ordinary mobile bodies inward through the
existing occupancy and wall solver. A packed group stops compressing when body
space is exhausted; no teleporting/overlapping bodies to fit a tiny visual ring.
Bosses and planted nests/sentinels receive finishing damage but are not pulled
or immobilized. Survivors are released immediately when the ring clears; no
capture flags are stored on enemies. Pause freezes paid flight and phase time.
A final-charge ring completes before the automatic reload starts.

Frontier checkpoint schema3 stores trap geometry, phase and captured IDs. Schemas
1/2 remain readable; an already-paid legacy ring finishes its former flight,
while subsequent casts use capture/collapse. Clears, Training weapon switches,
restart and disposal release the membership with the ring. Legacy edge target
limit remains in the catalogue only for old saved rings; it does not cap new
capture membership. Stable field IDs and exact previous catalogues are retained
for stored release hashes, drafts, candidate history, toggles and rollback.

## Admin settings

Open **Balance**, then the indicated tab and weapon. These are numeric settings,
not weapon-enable switches. Existing published settings are not overwritten by
source changes. Rebase an existing draft against its intended production release,
review these values, verify API components and publish through Review/Releases.
Start a new run to use published tuning; Continue retains its pinned balance.

| Tab → item | Field | Recommended value |
|---|---|---:|
| Weapons → Houndrack | Base damage | 2.2 |
| Weapons → Houndrack | Firing interval | .13s |
| Weapons → Houndrack | Projectile speed | 900 |
| Effects → Houndrack | Motor acceleration time | .25s |
| Effects → Houndrack | Secondary splash damage | .8 |
| Effects → Houndrack | Splash radius | 65 |
| Effects → Storm Orb | Pre-fire delay | .18s (0 disables) |
| Effects → Ring Caster | Starting radius | 28 |
| Effects → Ring Caster | Capture radius | 160 |
| Effects → Ring Caster | Expansion duration | .7s |
| Effects → Ring Caster | Capture hold | .2s |
| Effects → Ring Caster | Contraction duration | .55s |
| Effects → Ring Caster | Collapse damage multiplier | 1.5 |

Keep Ring Caster base damage4.5 and delivery reach340, Storm Orb firing
interval1.1, and the existing magazines/reloads unless deliberately tuning them.
The legacy ring edge limit is not an escape/capture setting for new rings.
Dart game/admin and TypeScript API projections share the same formulas and the
368-field catalogue. No production publication was performed by this code pass.

## Verification and hands-on check

Regression coverage exercises actual mummy and Shield Warden rocket hits,
direct/splash separation, guidance/range/cover, wind-up cancellation and cadence,
zero-delay configuration, 12-body containment through normal/forced movement,
fixed-center collapse, pause, save/restore, exactly-once finishing hits, cover,
cleanup and legacy checkpoint admission. The wider game/admin/backend suites and
web/unsigned iOS builds are recorded in REGUN_PROGRESS.md.

On the phone, compare rocket impact clarity against grenade blasts; fire the orb
while holding and briefly releasing aim; launch a ring into a crowd and move away.
Watch the capture hold and collapse at the launch location, survivors resuming
movement, cover, last-charge reload and Reduced Motion. Automated builds/tests
are not physical listening, balance, comfort or device performance acceptance.
