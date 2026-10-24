# External playtest: first priorities

24 October 2026. The creator confirms that many reported problems remain. The
tester's exact binary and pinned balance are still to be confirmed; that does
not invalidate the feedback. This is a proposed sequence, not shipped gameplay.

## 1. Make admin editing reliable

The screenshot shows local workspace recovery failing, rather than an invalid
shotgun value. The editor falls back to baseline values and blocks autosave to
protect the original. Fix persistence before tuning production. The local admin
correction recovers intermediate catalogue IDs with exact retained field shapes,
keeps valid drafts/candidates when history contains damaged entries, archives the
exact original before migration, and provides contextual errors/backup copying.
Live user-workspace verification remains pending: OS storage access and native
UI capture were unavailable. No storage reset or balance publication occurred.

## 2. Boss HUD obstruction

Current `lib/views/base_view.dart` places an opaque name/enraged/health plate
below the main HUD, up to 380 logical pixels wide per boss. This costs combat
space on short landscape screens. Replace that treatment with a compact health
strip in the top HUD region, short name and restrained enrage indicator. Reveal
the full name at arrival rather than retaining a large title plate in combat.
Keep both identities/health readable in paired Training. Verify actual fights at
568×320, 844×390 and larger text, not only an empty menu.

## 3. Damage certainty and hitbox fairness

Source already emits a .32s survivor hurt cue, .5s warm edge cue, lost-HP readout,
hurt sound and optional light haptic (`damagePlayer`, `DamageFeedback`). The
feedback says that combination is not communicating reliably. Review it in busy
combat; strengthen the survivor-local silhouette cue and let the actual health
change remain visible longer. Distinguish accepted damage from guard absorption
and invulnerability. Keep movement responsive, camera steady and Reduced Motion
comfortable; another full-screen flash is not the first solution.

The main collision radius is 30 around a 100-unit survivor sprite. Manual leap,
projectile and floor-attack distances also exist, so reducing only the Flame
circle would create inconsistent damage. Audit those paths against a shared
native/server hurt radius, separate from wall/navigation/feet clearance. A radius
of 26 is a candidate for comparison, not an applied change. Draw it over every
survivor facing and test near misses, body contact and swept fast shots.

## 4. Shotgun balance through the repaired admin

Current source and the screenshot show 1.7 damage per pellet, three pellets and
a 3.2s full base reload. That is 5.1 base damage when all pellets connect, before
distance/build/survivor modifiers. This does not prove it feels good: spread,
partial hits, ammunition and reload vulnerability affect effective output.

Compare stronger per-pellet settings in fresh matched encounters. Measure rounds
to kill, close-range burst, boss time and reload exposure. Preserve the three
pellets/normal reload contract unless the creator chooses a separate change.
Check actual production values and start a fresh run: Continue intentionally
retains its pinned balance. No shotgun stats are changed by this triage.

## 5. Upgrade impact

Separate numerical benefit from visible consequence. Record which ordinary
choices appear; compare first-rank before/after in real combat. Emphasise clear
projectile/chain/build changes and meaningful card values rather than globally
buffing every family or copying ricochet everywhere. Preserve caps and proc rules.

Unique animation for every upgrade across ten survivors is a large art scope.
Begin with a few deliberate reactions for weapon, defensive, electrical and
ordnance families. The tester's freeze-frame suggestion is feedback, not an
instruction to replace the creator's accepted 0.1× picker. Avoid an extra forced
interruption or obscuring enemy warnings as play resumes.

## 6. Opening difficulty and boss personality

The current first bag prioritises less-beaten bosses with random ties. A new
profile can meet any of eight bosses first. That creates variety, not a designed
difficulty ramp; base boss health ranges from 140 to 340. Define an explicit
opening encounter tier and later escalation, including warning/attack mix rather
than health alone. Reconcile it with the approved all-eight/less-familiar-first
selection before changing ordering; do not silently force one boss every run.

Existing bosses already have arrival states and sound/music. Extend these with
a short authored introduction/pose and full-name reveal, then collapse the HUD.
Avoid long repeated compulsory cinematics. Cosmetic movement must not relocate
authoritative attack geometry; retain pause/Continue and Reduced Motion handling.

## 7. Make the current purpose clear

Current play is endless survival, boss fights, build combinations, unlocks and
challenges. It is not implemented as story floors. Make the next milestone and
run purpose readable in home/loadout/HUD/results copy before inventing a campaign.
Do not promise a floor transition or chapter that does not exist. Larger story
structure requires its own design decision.

Recommended first gameplay pass after admin recovery: compact boss HUD and
clearer accepted-damage feedback, then shared hurt-geometry review and measured
shotgun tuning. Upgrade impact and opening difficulty follow. Full unique
upgrade animations and campaign work should not delay those clearer problems.


## Delivery map

| Pass | Deliverable | Phone acceptance |
|---|---|---|
| 1 — See the fight | Compact boss HUD and stronger accepted-health-loss presentation | Fight remains visible on small landscape screens; damage, guard and protection are immediately distinguishable. |
| 2 — Fairness and shotgun | One consistent hurt-volume contract; compare stronger shotgun damage through admin | Near misses match the visible body; fast shots/leaps and online damage agree; shotgun rewards close accurate hits without erasing tougher roles. |
| 3 — Meaningful progression | Review first-rank upgrade impact and explicit opening-boss difficulty | A fresh player can identify the benefit of their pick and learn the first boss; later encounters retain pressure and variety. |
| 4 — Personality | Brief boss introductions and family-appropriate upgrade reactions | Bosses are recognisable; celebrations add character without covering warnings or imposing repeated long pauses. |
| 5 — Purpose | Clear next milestone and run/progression copy | A new player can explain what they are trying to do and what persists after a run; no unimplemented campaign is promised. |

Treat passes 1 and 2 as the first device-review candidate, rather than bundling
all feedback into one large update. Render the HUD/hurt presentation before
finalising it; verify authoritative geometry and admin/API/mobile balance parity;
then review a real phone build. Tune from that review before proceeding to passes
3–5. Keep separate comparisons for presentation and actual difficulty changes.
Gameplay parameters that affect online outcomes must match the server; purely
visual HUD/hurt presentation does not need arbitrary new admin controls. New-run
balance pinning, Continue compatibility, control placement and Reduced Motion
remain acceptance requirements for every pass.


## First implementation pass — 25 October 2026

Combat visibility and the shared smaller hurt footprint are implemented locally;
see [COMBAT_VISIBILITY_AND_HURTBOX.md](COMBAT_VISIBILITY_AND_HURTBOX.md) for actual
behavior, evidence and rollout limits. This supersedes the proposed 26-unit
comparison above. The creator tuned shotgun values in admin independently;
this implementation deliberately makes no shotgun/catalogue/publication changes.
Other feedback items remain planned.
