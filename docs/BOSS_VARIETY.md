# Early boss variety

24 October2026. Implemented in source; deployment and device review pending.

Normal Solo starts with all eight bosses in a bag. The first bag is shuffled,
then ordered by that player's recorded victories, lowest first; ties retain the
shuffled order. More familiar bosses move later in the opening rotation. Each
boss still appears once before the bag refills. Later bags use the existing
shuffle with no immediate repeat across bag boundaries. Combat parameters,
timing, rewards, revives and spending do not participate in selection.

`PlayerProfile.bossWins` is an additive schema3 map of known boss IDs to observed
normal-run victory counts. Each run checkpoints its per-boss counts, including
repeated defeats in later cycles, and adds them during existing idempotent
settlement. Training/Practice/Rush never contribute. Old aggregate boss totals
cannot identify their original bosses, so old profiles start with unknown/empty
per-boss history. A continued legacy run can contribute one observed win per
known defeated kind; extra historical repetitions cannot be reconstructed.

New runs pin their opening history. Saved bags and the pending opening history
survive Continue/revive; profile synchronization cannot reorder an active run.
Old saves lacking opening history keep their original bag rules. Boss victory
counts remain recoverable device-reported progression, not competitive authority.

Cloud saves validate the bounded eight-ID map. Wallet reconciliation retains it,
including when an older client omits the field. An explicit progress reset clears
it. The protected admin player record shows recorded counts separately from
aggregate totals, or says that no per-boss history has been recorded. Guest
history remains local under the existing profile rules. No new server ENV/table.

Hosted co-op retains its existing shared shuffle; an individual player's history
cannot choose encounters for the other participants. Training's explicit boss
selection and randomized Rush remain unchanged.

Validation: seeded first-bag ordering/tie randomization, all-eight coverage,
no boundary repeat, pinned/saved ordering, repeated-win settlement deduplication,
Training exclusion, serialization/legacy/malformed data, wallet preservation and
private administrator lookup. Phone review: complete several normal runs with
uneven wins and check less familiar bosses arrive earlier, Save/Continue before
and during the opening rotation, and confirm Training wins do not influence it.

Local verification: mobile full suite651 passed/5 intentionally skipped, plus the
real-kill/checkpoint/settlement integration test passed after final validation
hardening. Mobile analyzer clean. Module144 tests/typecheck/build passed;
gateway20 tests/build and compiled HTTP smoke passed; admin41 tests/analyzer and
five targeted player-record responsive tests passed. No production deployment or
phone balance acceptance is claimed.
