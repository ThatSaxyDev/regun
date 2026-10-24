# Earned Solo revive — implementation and rollout

24 October 2026. Implemented in app, account gateway, database module and admin.
**The server policy defaults disabled.** This source change does not deploy or
publish a new app. Billing, ads, charge packs and free first-use allowances remain
outside this pass.

## Player rules

- At most one revive per normal Solo run, after **300 active seconds**. No Training,
  co-op or Versus offer. Existing legacy checkpoints acquire no new allowance.
- **500 Scrap**, with at least500 banked before starting and500 still available at
  server debit. Unclaimed current-run earnings cannot fund it. Requires email
  sign-in and a successful online account-server confirmation. Ordinary offline
  play and use of previously owned cosmetics remain available.
- Explicit Revive or End run. No countdown, automatic purchase, personalized price
  or loss/spend-driven combat difficulty.500/300 are creator-chosen trial values,
  not measured average affordability.
- Same build, enemies/boss health/phase and live-balance snapshot. A checked landing
  point, half maximum health rounded up, full current magazine and two active
  seconds of protection. No grenade refill, upgrades, fusion capacity or repeated
  kill rewards. Nearby hostile bullets clear once; arena hazards remain.
- Revived runs retain ordinary Scrap and unlock progress. Their personal best
  score/time are separate from runs without a revive and accessibility-assisted
  records. The death/revive prompt does not explain record categories; final
  results identify the relevant best as “Revived best”. Training stays accessible.

## Durable confirmation

The owner-scoped run checkpoint records starting funds, reset epoch, decision stage
and continued flag. Both primary and backup are replaced before spending and before
resuming. Final settlement waits for the revive decision; an ended checkpoint is
written before applying ordinary rewards with existing settled-run IDs.

POST `/solo-revive` uses authenticated email accounts. `offer` checks policy and
reported eligibility. `buy` atomically debits500 and records one receipt keyed by
account/run. `status` never spends. `close` writes an unpaid cancellation tombstone
or returns an already-paid receipt. `activate` confirms the prepared recovery and
remains allowed after policy disable. Reset invalidates old epochs. Repeated
requests cannot debit again; an activated receipt cannot heal an older death save.

A lost response shows a confirmation state. Retry reads that receipt before cloud
comparison, avoiding a false save conflict from the debit's new revision. Save &
menu preserves the decision for Continue/re-authentication. A prepared recovery
resumes after confirmation; backgrounding keeps combat paused. Ending an uncertain
purchase needs server cancellation or recovery of its committed receipt.

**Trust boundary:** offline Solo time, starting funds and cumulative earnings are
device-reported. Server authentication, wallet debits, epochs and per-run receipts
are authoritative, but this is not anti-cheat proof for local combat. Do not reuse
this earned-currency contract for cash-backed value or ranked competition.

## Admin and deployment

Economy → Solo revives shows fixed500/300/one-run terms and an enable/disable control.
Publication uses existing operator/session checks, reason, expected revision and
durable request ID. Review shows old/new settings. Drafts/pending publication
survive navigation; retry sends the same operation. A stale revision needs a
refreshed draft and new review. Price/combat strength are not editable here.

Players → Scrap wallet shows revive receipts. Economy reports separate paid
revive count/spend from cosmetic purchases. These are operational earned-currency
reports, not cash revenue or financial books.

Deploy module, gateway and nginx route together through the existing deployment
flow, preserving signing/publisher state and stored data. Deploy matching admin
and app before enabling a reviewed pilot. Disable stops new spending while still
allowing paid recovery. No new billing credential or table migration is required.

## Acceptance

Automated checks cover500/300 boundaries, guests/Training/second use, atomic debit,
lost acknowledgement, cancellation, account/reset isolation, journal write failure,
prepared recovery after reopening, paused landing, unchanged ordnance, exactly-once
rewards, wallet reconciliation and admin retry after a lost publication reply.
Rendered ordinary landscape layouts keep actions visible without scrolling.

Phone checks before rollout: death before/after five minutes;499/500 starting Scrap;
connected/offline death; no second revive; pause/background during landing; force
close while confirming then Continue; retained boss health/build/ordnance; End run
earnings; admin disable during offered/paid recovery. Assess readability, comfort,
fairness and cosmetic affordability with users. Automated checks do not establish
native feel or balance. See the existing economy research for original rationale.

Price updated to500 Scrap on24 October2026. Deploy mobile, module, gateway and
admin together. An old unpaid55-Scrap quote cannot debit500; it is rejected.
Already paid receipts remain recoverable without another debit. No new ENV.
