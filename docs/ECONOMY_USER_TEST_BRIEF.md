# Economy status and user test brief

23 October 2026. Current app source: 1.0.0+20. Confirm the version/build on the
actual distributed package before testing. Matching app/API/admin releases are
required; source completion alone does not identify what is installed or deployed.

Read-only live check today: the public production catalogue returned HTTP 200,
version scrap-cosmetics-1, with all six finishes available: Copper100, Moss100,
Ivory150, Rust175, Slate175, Dusk225 Scrap. This confirms catalogue delivery, not
signed-in purchase, receipt recovery, installed admin or billing acceptance.

## What is implemented

- Earned Solo Scrap, visible wallet, results earnings breakdown, no Training
  rewards and duplicate-settlement protection.
- Email sign-in and server confirmation before spending. Offline ordinary play
  and earning continue; buying requires a connection.
- Six appearance-only survivor colour finishes with previews, prices and explicit
  confirmation. These are recolours, not six new character outfits.
- Atomic server spend/ownership/receipt, exact displayed-price checks, durable
  purchase IDs, status recovery and safe cancellation of an uncommitted intent.
  Reconnect/Sync does not submit a new spend automatically.
- Account-scoped owned styles remain usable offline after ownership has synced.
  Another device first needs an online account sync. Hiding an offer does not
  remove existing ownership.
- Field Record/unlock progress, pinning a next goal, results goal feedback and
  newly observed unlock timing samples. Combat tools remain earned.
- Admin catalogue prices/visibility, saved drafts, staging/production, reviewed
  publication, conflicts, history and operational economy reports.

Credits are a placeholder, displayed as —. Online-earned Scrap is a separate
balance; it is not automatically part of spendable Solo Scrap. Paid billing,
Credits packs, ads, live revive spending and supporter packs are not enabled.
Revive rules are documented; the transactional recovery flow is still future work.
No complete new career-rank tree or validated progression rebalance is claimed.

## Message to send to players

Please test the latest Regun build for about 30–45 minutes. This test uses earned
Scrap; there is no real-money payment to make.

1. Play two or three normal Solo runs. Check your Scrap before and after each
   run, including a loss. Look at the results breakdown. Try Training briefly:
   Training should not increase your real Scrap.
2. Open Collection → Challenges. Find something you want to unlock and pin it.
   Tell us whether you understand the requirement and whether the results show
   useful progress after a run.
3. Open Collection → Style. Preview the finishes. Check the price and your
   balance. If you have enough Scrap, buy one while signed in with email and
   connected. Confirm the exact price is deducted once and the finish equips.
   If you do not have enough, report your balance after the runs; you do not
   need to grind until you can buy one.
4. Once ownership is confirmed, turn on airplane mode and fully close/reopen the
   game. Your owned finish should still be available to equip and use. Trying
   to buy an unowned finish offline should not spend Scrap or grant it.
5. Reconnect and sync. Your balance and owned finish should remain correct, and
   reconnecting should not buy anything automatically.
6. If you are playing as a guest, try the purchase entry before signing in.
   The game should ask for email sign-in and should not deduct anything. After
   signing in, check that your existing progress and earned Scrap are retained.

Tell us:

- Phone model, app version/build, and whether you were signed in/online.
- Number of normal runs and approximate play time.
- Scrap before/after, finish name and displayed price for any purchase issue.
- Any 403, unexplained failure, repeated deduction, missing finish, or purchase
  still awaiting confirmation after reconnecting and using Sync/Retry.
- A screenshot or short recording and the steps immediately before the problem.
- Which finish you wanted most, which you actually used, and what appearance
  you would prefer instead.
- Whether earning felt rewarding, too slow, too fast, or confusing—and why.
- Whether your next weapon/survivor unlock felt understandable and worth pursuing.

Do not send sign-in codes or passwords in a bug report.

## Split the small test group

Give newer players the progression/earning questions. Give returning players
with enough legitimately earned Scrap the purchase/offline-ownership checks.
Do not require every tester to complete every failure scenario or accumulate
225 Scrap. Record who did which path; an unattempted purchase is not a pass.

## Owner/internal end-to-end checks

Use test accounts and a test deployment for deliberate faults/catalogue changes.

1. Guest earn → email attachment → sync → quoted purchase → server receipt →
   ownership/equip → offline restart → reconnect → admin player ledger/report.
   Confirm one deduction/grant and the matching confirmed receipt.
2. Disconnect during purchase; restart; reconnect and recover the same operation.
   A committed operation restores ownership without charging twice. An
   uncommitted operation can be cancelled; its late original cannot spend.
   Sync/status checks must never create a new purchase.
3. While a quote is open, change/hide that offer on the test environment's
   production catalogue channel. Buying the stale quote must stop and refresh,
   then require a new choice. An already owned hidden finish stays usable.
4. Switch between two accounts, restore the owning account on another device,
   and test a progress reset. Ownership must not leak to the other account;
   the owning account retains its purchased finishes through progress reset.
5. Admin: save a staging draft, leave/restart, review the change/reason, publish,
   test stale-revision conflict and lost-response retry, then restore history
   as a new draft/release. Staging itself must not change the public game shop.
6. Check reports against the test receipts: earnings/imports/spending/current
   balances remain distinct. Requests/retries are attempts, not unique buyers
   or revenue. New-unlock timing needs actual observed samples.
7. Check wallet/title placement, shop previews/confirmation and results actions
   on compact/notched landscape and larger text. Normal screens should fit;
   unusually small screens can use the intended fallback.

## What we do after this test

First fix any lost ownership, wrong balance, repeated spend, sign-in loop, 403 or
stuck confirmation. Then review actual earning/unlock times and interview answers
before changing prices, reward rates or unlock gates. The six prices are starting
hypotheses, not validated affordability or evidence of willingness to pay.

Next product work is better cosmetic value and progression where the evidence
shows a need. A future earned Solo continue should exercise the same one-per-run
recovery rules before introducing paid sources. It needs durable pre-settlement
recovery, a run-bound spend receipt, crash recovery, continued-run records and
once-only final rewards. See REVIVE_POLICY.md; no live revive price is set.

Real outfits/supporter bundles and eventually Apple/Google billing are later
work. Do not infer that Scrap purchases prove cash revenue, or turn Credits into
a purchased wallet before its separate ledger/restoration/refund work exists.
