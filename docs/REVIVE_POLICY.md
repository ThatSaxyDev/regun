# Continue policy — implementation contract

23 October 2026. Defined for the non-billing economy pass. **Not enabled**:
there is no continue purchase, charge pack, ad SDK or death-screen sales prompt.
This separates the agreed product rules from functionality that has not shipped.

## Eligibility and fairness

- One economy-funded continue per ordinary Solo run, shared across every future
  source: earned allowance, Scrap or purchased charge. Restart/reconnect never
  resets the cap. No offer in Training, online co-op, PvP, ranked, seeded daily
  challenges or an explicitly uncontinued mastery trial.
- The player chooses Continue or ends the run. No countdown, repeated prompts,
  automatic purchase, losing-streak targeting or price based on account/spending.
- All sources give exactly the same recovery: the same build and boss phase,
  half normal maximum health rounded up, full existing weapon magazine, and the
  existing two-second deployment protection. No extra upgrades, core capacity,
  grenade charges or better offers. Final values need device playtesting before
  enabling; they must be pinned in the run's continue offer.
- Re-entry uses a validated safe location and the existing deployment timeline;
  pause/background freeze it. A one-time local bullet clear may protect landing,
  but never cancels bosses, resets boss health, pays repeated kill rewards or
  erases the arena's persistent hazards.
- Record `continued` independently of aim assistance/accessibility preferences.
  Continued runs retain ordinary Scrap and horizontal unlocks, but cannot award
  an explicitly uncontinued prestige feat or enter an uncontinued leaderboard.
  Explain this before confirmation; do not retroactively punish purchases.

## Earned access and pricing

A future first-use allowance should be earned once per account through ordinary
play, not depend on payment or reset on reinstall. Reserve its exact milestone
until we can assess first-session pacing. Do not make basic learning require a
paid recovery. Controls and Training remain free.

Do not activate a Scrap price from a hypothetical average. The current unchanged
formula pays salvage + floor(kills/10) + 15*bosses + floor(seconds/60). A synthetic
300-kill, one-boss, ten-minute attempt pays55 plus salvage. A provisional50-Scrap
continue would therefore consume nearly that entire example reward; it could be
a loss tax for struggling players. Measure the actual distribution first. A
candidate price and starter allowance must be reviewed together, with a retained
no-continue comparison and cosmetic affordability. There is no live price today.

## Server and persistence requirements before enabling

1. Introduce a durable pending-recovery phase *before* final settlement. Capture
   the exact run/account/reset epoch, death checkpoint, used flag and offer terms.
   Current final-death settlement must not be followed by an unjournaled revive.
2. Every new economy spend requires email sign-in and an online server response.
   Preserve offline ordinary play and offline use of owned permanent styles.
   Do not promise offline consumption of a cash-backed charge without a separate
   reservation/reconciliation design.
3. Atomically reserve/debit once and bind a recovery receipt to that run. A lost
   response checks the same receipt; reopening does not create a second spend.
   Account switches, reset, expired runs and already-settled runs reject the offer.
4. Persist the confirmed receipt and consumed flag before resuming combat.
   Recovery after crash resumes that same decision. An unusable run must retain
   or release the reserved charge through an auditable operation.
5. Settle normal rewards exactly once at final death/end. Add a durable settlement
   journal and crash fault tests before enabling. Existing settled-run IDs and
   best-effort checkpoint recovery are insufficient for paid recovery.
6. Admin may inspect receipts and reports; it cannot change the one-continue cap,
   competitive exclusions, combat difficulty or source parity through catalogue
   fields. Billing verification, charge restoration/refunds and cash prices are
   a separate later project.

Acceptance must include offline death, timeout before/after debit, kill during
receipt persistence, repeated callbacks, account switch/reset, background during
re-entry and one-continue enforcement after restart. Physical fairness, comfort
and progression impact remain creator playtest gates. Research rationale:
[Economy recommendation](research/ECONOMY_RECOMMENDATION_2026-10-23.md).
