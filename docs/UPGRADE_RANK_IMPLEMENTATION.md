# Upgrade ranks — implementation status

24 October 2026. Source changes across regun, regun-server and regun-admin;
not published to production or installed on a phone by this pass.

Eight remains the normal maximum. Double Dash and Grenade Reserve retain their
small capacity-based rank limits and existing rarity. XP costs, fusion gates,
weapon prices and combat difficulty are unchanged.

## Numerical contract

New balance catalogues carry `ranks.meta.policy:1`. I–III retain existing values.
Five late-growth steps are redistributed: IV takes its authored weight, V–VII
share the remainder, VIII takes its authored weight. Each milestone weight is
bounded to0.5–2, so every middle step remains positive and total VIII power stays
unchanged. Count-only upgrades keep their discrete progression.

The first numerical batch is Heavy Load, Quick Trigger, Fast Reload, Scrap Armour
and Ordnance Cycle: IV1.4, VIII1.6, each middle rank two-thirds of a late step.
Other scalar families remain1/1 and can be reviewed through the same controls.
Scattershot retains its existing post-count-cap spread refinement. Extended Tube
retains whole-round gains; fractional milestone weights are intentionally not
exposed for integer magazine ranks.

Mobile effective rank and stored incremental gains consume the pinned curve.
The hosted module applies the same curves to its existing supported weapons and
upgrades; this does not add the mobile expansion roster to hosted combat.
Shotgun fast-reload rounding agrees to the millisecond for the new policy.
Bank Shot's new-policy module formula now matches native; legacy rooms keep the
former module calculation.

## Avoiding empty choices and explaining ranks

Shared per-family component calculations cover all43 offered families. New-policy
offers compare current/next effects, including rounding, range/magazine/speed caps,
weapon cadence floors, survivor reload/recharge bonuses and chain retention.
Exhausted ranks disappear unless they still advance a usable fusion prerequisite.
A secondary benefit is shown only in contexts that actually have it, for example
Coil's additional chain retention. Existing bans, prerequisites, special slots,
rarity and recent-hand suppression still apply.

Cards retain compact pixel frames and expandable Details. Numbers come from the
same component calculations used by eligibility. A prerequisite-only rank is
labelled as such. Collection provides an expandable I–VIII example path; Training
Pause has a read-only III/IV/VIII comparison for the visit's pinned loadout and
balance. Capacity paths show their actual small caps. These comparisons are
components, not a whole-build DPS claim; conditional triggers and prerequisites
still apply.

## Admin and API

The existing balance workspace has a Rank curves group and baseline/draft rank
paths beside power-up controls. Weapon/survivor selectors expose cap interactions.
Invalid draft values cannot be submitted; previews use safe field defaults while
an invalid field is being edited. The authenticated, read-only
`POST /admin/ranks/preview` validates the complete draft and returns rank0–VIII
(or the capacity limit). Admin can check its local projection against the API,
rejecting incomplete, stale or differing results.

The same catalogue, validation bounds, Dart projections and915 shared sample
cases are carried across all three projects. Existing staging, publication
reason/revision checks, durable requests, draft persistence, history and rollback
remain the publication path. No new server ENV variable or database table.

## Saved runs and rollout

Saved native runs pin the complete balance snapshot; Continue/revive cannot adopt
a later rank release. Historical catalogue contracts remain readable. Old saves
without rank policy retain their prior curves, offer filtering and copy.
New hosted rooms pin the numerical snapshot. The module exposes
`rank_curve_support`; compatible apps negotiate combat capability5. An older
client cannot join/start a room that requires the new rank policy. Existing room
snapshots and legacy gun data keep their old behavior.

Deploy the compatible app/module/gateway/admin, then review a current-catalogue
balance draft in staging and publish production through the existing workflow.
An existing production release using an old catalogue intentionally keeps its
old rules until a new release is published. Rollback affects subsequent runs.

## Evidence and limits

`RANK_COMPONENT_AUDIT.json` records208,740 component transitions across43 families,
21 weapons,10 survivors and default/minimum/maximum strength and curve values.
It includes unsupported combinations to expose floors, not an assertion that
those combinations are offered. Regenerate from regun-server/spacetimedb with
`npx tsx tool/audit_ranks.ts`; shared fixtures for all three repositories are also generated there.

Tests cover shared projections, actual grant totals, milestone budgets, cap-based
eligibility, fusion prerequisites, save pinning, invalid bounds, administrator
access and responsive previews. Existing broader combat, profile, progression,
publication and UI suites also run. Physical choice quality, balance, readability
and comfort still need player sessions. The audit is not a full combined-build
DPS/healing simulation or proof of CPU/phone performance. Further family-specific
mechanics or increased VIII power require separate measured review.

Validation completed: mobile full suite648 passed/5 intentionally skipped;
post-hardening targeted progression/UI/save suite132 passed and expanded Training
UI6 passed. Admin full suite41 passed, including shared projections and compact
previews; the invalid-input preview regression also passed. Module141 tests,
TypeScript checks and Spacetime build passed. Gateway19 tests, TypeScript build
and compiled HTTP smoke passed, including protected rank preview. Mobile and
admin analyzers report no issues. These results describe local source checks.
