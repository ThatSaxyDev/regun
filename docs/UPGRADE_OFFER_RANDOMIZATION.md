# Upgrade offer policy — 24 October 2026

Fresh runs use offer policy1 in both Flutter and the authoritative co-op server.
This tunes offer selection, not XP costs, upgrade strength, damage, recharge,
rank limits, inventory limits, bans, reroll allowances or fusion requirements.
Training direct practice remains available. No purchasing or player spending
history enters the selector.

## Weights

| Candidate | Base draw weight |
|---|---:|
| Ordinary unowned upgrade | 1.00 |
| Ordinary upgrade already in the build | 1.50 |
| Double Dash / Grenade Reserve, first rank | 0.35 |
| Double Dash / Grenade Reserve, second rank | 0.20 |

Capacity upgrades do not receive the ordinary1.5 existing-build multiplier. They
also cannot qualify for the first slot's guaranteed build-follow-up pool. A
normal upgrade already in the build can still qualify for that slot. If no normal
owned candidate is eligible, the first slot draws from the full eligible pool;
it never forces another capacity upgrade simply because that is the only owned
family. Lucky Find retains its existing special-group multiplier.

Each candidate shown in the previous generated hand receives a0.35 multiplier
on its next draw weight. This includes the selected card and applies to the next
XP, supply, reroll or ban-generated hand. It is a soft penalty: recently shown
cards remain possible, including when the pool is small. Fusion recipe screens
neither use nor replace ordinary offer history. Choices stay unique within a
hand. Existing eligibility filters, bans, rank caps and Salvage fallback remain.

These are relative weights, not fixed probabilities per screen. Eligibility,
owned upgrades, Lucky Find, recent cards and sampling without replacement change
the actual chance. Do not describe0.35 as a35% drop chance or promise an exact
number of upgrades per run. Capacity additions remain valuable discoveries rather
than required build steps.

## Save and server compatibility

GameNotifier checkpoints write offerPolicy and recentOffers alongside the
existing RNG state. Continue preserves the next random choices and recent-hand
penalty, including while an upgrade screen is open. Reset/new run starts policy1
with empty history. Optional history is validated before restoring; unsupported
policies, unknown IDs, duplicate history and more than three entries are rejected.

Old checkpoints without an offerPolicy retain selector0, including their old
weights and existing-build behavior. Their current/future hands are not silently
rebalanced by loading this app. The server pins policy1 in initialProgress and
stores history in serialized fighter progress. Existing persisted server progress
without the marker keeps its original selector. A new run/round adopts policy1.
No active run's live-balance snapshot is replaced.

Rarity is a versioned source policy in this pass. Existing admin strength/cap
controls are unchanged; no new remotely editable probability fields are exposed.
Deploy the matching app/module for consistent new-run behavior. Deployment and
physical player approval are separate from this source verification.

## Verification

The duplicated shared upgrade-offers-v1 fixture checks the same exact hands in
Dart and TypeScript given identical eligible candidates, ranks, recent history,
Lucky Find and random inputs. Fixture cases cover fresh hands, build follow-up,
capacity-only ownership and exhausted pools. Existing app/server eligibility rules
remain their respective contracts; sharing the selector does not claim their
entire catalogues or available online weapons are identical.

A deterministic40,000-opening-draw app test checks that capacity first-pick
frequency remains around0.35 of a normal candidate and that recent-hand suppression
reduces repeats without eliminating them. Dedicated tests also cover the second
rank's weight, normal upgrade/Lucky Find weights, saved RNG/history recovery,
legacy selector retention, bans and capacity caps. Full suite results are recorded
in the progress log after verification. Actual player pacing needs playtesting.

Acceptance: analyzer clean; full app suite644 passed with5 opt-in skips; final
policy/restore checks4 passed; server137 tests, typecheck and SpacetimeDB build
passed. No physical-device playtest, installation or live deployment occurred.
