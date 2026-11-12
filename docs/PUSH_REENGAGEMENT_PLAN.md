# Regun push re-engagement release plan

Release plan revised 12 November 2026.

Covers Regun mobile, the identity service and SpacetimeDB in regun-server,
and Notifications in regun-admin. It builds on the
[push notifications plan](PUSH_NOTIFICATIONS_PLAN.md).

Deliver the leaderboard event, all four lifecycle rules, player controls, admin
controls and measurement as one release. Engineering can implement and test in
dependency order. Public enablement is one release decision for the complete
feature. Each rule can still be paused independently after release.

## 1. Current code and release dependencies

| Area | What exists | Release work |
|---|---|---|
| Activity | Flutter reports foreground presence every 30 seconds through `PlayerRegistry`, including Training. `player_device.last_seen_at` records the server receipt time of accepted device reports. Push registration skips unchanged subscriptions, so its timestamp is unsuitable for dormancy. | Resolve all player-device records for an owner. Use their latest accepted report conservatively for suppression and a foreground report for measuring a return. |
| Consent | Mobile exposes a master toggle. The identity service currently returns category preferences as enabled and ignores category opt-outs in audience selection. | Add an explicit **Return reminders** preference for automated re-engagement, default Off for existing and new owners. Keep existing manual and transactional delivery policies. |
| Leaderboards | Solo boards are split by active ruleset, arena and assisted status. Published best rows reflect participation and moderation. There is no weekly rollover. | Capture a genuine change of first place on the current Breach Standard board. Board reset messages require an actual rollover feature. |
| Delivery | OneSignal delivery, push outbox, atomic message claim and manual campaign quota exist. Campaign TTL is currently 24 hours. A message can be marked sent with zero eligible recipients. | Reuse the outbox and provider client. Give automated traffic its own quota, due time, expiration and outcome handling. |
| Routing | The app maps Leaderboards and Collection to read-only screens. Home is the existing menu and has no separate route push. The router guards active routes. | Keep those destinations. Verify warm and cold taps, including startup and combat. |
| Operations | Admin has campaign composition, history and audit. | Add a System view, runtime controls and experiment results. |

Purchase receipts and new-device sign-in warnings belong in transactional
delivery. An automated receipt would require a confirmed wallet
credit and a dedupe key from the settlement. A new-device warning would require
a verified install identity and a successful sign-in on a previously unseen
install. Neither is a return reminder. Weekly reset, unfinished runs and squad
presence each need their own verified signal before they can generate copy.

## 2. Player identity, activity and permission

- A signed-in owner is an account. Count activity from every linked device,
  including devices that cannot receive push. A guest owner maps to the
  authenticated guest device. If a guest becomes linked, retire its guest
  eligibility and carry forward recent cooldowns, lifetime rule usage and any
  experiment assignment. Recheck the destination's current owner before dispatch.
- Use the newest accepted `player_device.last_seen_at` for inactivity across
  Menu, Training, Solo and Online. Any accepted report can conservatively
  postpone eligibility. Missing, future or unmappable activity makes an owner
  ineligible. OneSignal registration timestamps can help choose a destination
  but cannot establish a session. Server-visible activity is the available
  signal for offline play.
- Require Return reminders On, master On, a currently opted-in subscription,
  OS permission granted and a valid owner. Both guests and accounts can opt in.
  Give the setting a brief description covering leaderboard changes and
  reminders after time away. Persist an explicitly set preference independently
  of the legacy category defaults. An account change must reload the preference
  for the new owner. A guest opt-in does not automatically opt in the account.
  Send-time suppression also checks account deletion,
  subscription retirement and owner changes.
- Use one destination per owner. Prefer the most recently confirmed reachable
  install with a current timezone, then use a stable ID tie-break. Make the
  mobile registration cache include owner and timezone and refresh on resume
  with a bounded interval. Store and validate the device's IANA zone so Return
  and Winback can resolve DST for dormant players. An observed UTC offset can
  serve as a fallback for seven days from its last confirmation. Skip unknown
  or stale offsets. Dry-run results must show how many owners each rule can
  reach with the timezone data available.
- All re-engagement needs at least 48 hours of inactivity. Send only during
  local 18:00–21:00 on the chosen install, subject to configured server quiet
  hours. Evaluate both at dispatch. Set provider TTL to the earlier of the
  local window closing and the rule's expiration. Cap automated sends at one
  provider-accepted notification per owner in any rolling 72 hours and six in
  any rolling 30 days. Use one shared cap across the five automated rules.
  Existing admin and transactional policies remain independent.

## 3. Rules and copy

Lifecycle uses non-overlapping inactivity windows measured from the owner's
latest activity. One window is current at a time. If a player is already in a
later window when first evaluated, earlier windows are skipped. A confirmed
return starts a new absence when activity next stops. A missed window expires
at its upper bound. An unmatched condition leaves the player eligible for
evaluation in the next window.

| Rule | Condition and limit | Title / body | Tap |
|---|---|---|---|
| Nudge | 2 to under 3 days away, 0–4 reported settled runs, once per owner | **The shelter is quiet.** The arena is ready when you are. | Home |
| Progress | 3 to under 7 days away, a usable profile snapshot with at least one recorded boss victory, once per absence and at least seven days since this rule last sent | **{count} boss victories** There is another fight waiting in the arena. | Collection |
| Return | 7 to under 30 days away, once per absence and at least 14 days since this rule last sent | **Back to the shelter?** It has been at least a week since your last visit. | Home |
| Winback | 30 to under 37 days away, once per owner | **Still holding the line?** It has been 30 days or more since your last visit. | Home |

Use the latest matching profile report for Progress, respecting the current
progress epoch when available. The registry's settled-run count describes
recorded results, so Nudge never claims the player has yet to play. Progress
uses the actual victory count, with a singular title for one win. The latest
reported count, an eligible interval or a confirmed rank change must support
each message. Copy stays under 60 title characters and 180 body characters.

**Dethroned.** On the current Breach Standard board, a different participating
account's newly accepted score strictly beats the previous leader's score and
becomes first place under the published comparator. Atomically capture the
previous leader, board, displaced best and winning run as part of the accepted
leaderboard mutation. Moderation, ties, self-improvements and ruleset changes
do not create this event. Deduplicate event processing by recipient, board
and winning run. Allow one provider-accepted alert per recipient and board.
Recheck the board is current and both records remain eligible, with
the original winning score still above the recipient and the recipient still
below first. Expire after 72 hours or when that evidence is invalid. The title
is **You lost first place** and the body is **A new score leads Breach
Standard. Your run is still on the board.** Tap opens Leaderboards.

When Dethroned and a lifecycle rule are both eligible, Dethroned takes
precedence. The shared cap still applies. Leave the lifecycle rule eligible
only for the remainder of its own window. If a fresh activity report arrives,
expire any pending lifecycle message for the old absence. Dethroned must still
meet its own expiry and the inactivity check after the report.

## 4. Server implementation and recovery

1. **Record the decision.** Add private `push_rule_run` and
   `push_engagement` tables. A rule run stores rule, owner, stable event or
   absence key, evidence reference, experiment arm, decision time, due time,
   expiry, outbox ID and outcome. Engagement stores or indexes owner-level
   reservations, provider acceptance timestamps and lifetime rule history.
   Rolling caps use actual timestamps. Apply owner cleanup to pending rows,
   preferences and personalized experiment data on account deletion. Retain
   owner-level experiment detail for 90 days, then keep aggregate metrics and
   the minimal history needed for caps and deduplication.
2. **Enqueue atomically.** Run evaluation alongside the 60-second sender.
   Use an indexed, resumable scan that advances beyond the first page and
   processes up to 20 candidates per pass. Advance the cursor even when a
   candidate fails. A reducer atomically verifies the decision key, checks
   for outstanding owner reservations, reserves the cap and creates the
   scheduled outbox row. Use the recorded last-activity timestamp in a
   lifecycle absence key. Enforce lifetime limits for Nudge and Winback and
   the recipient/board limit for Dethroned from the acceptance ledger.
3. **Dispatch against current evidence.** Resolve and recheck the owner,
   destination, preference, recent activity, cap, timezone, rule enablement
   and evidence before each dispatch or retry. A disabled rule suppresses
   queued sends. A closed delivery window can reschedule before expiry.
   Ineligible or expired decisions close with a reason and release their
   reservation. Zero recipients is a suppression outcome.
4. **Recover interrupted sends.** Use an atomic claim with a bounded lease for
   automated messages. Persist the destination and request identity before
   dispatch. On an ambiguous provider response, retry with the same message
   and provider idempotency key while the lease, eligibility and expiry allow.
   A retry must never retarget to another install. If an ambiguous attempt
   expires or eligibility changes, stop sending and keep the reservation for
   the applicable cooldown while recording delivery as unknown. Count provider
   acceptance separately from confirmed delivery. A definite rejection releases
   the reservation, subject to bounded retry policy. Keep manual worker
   processing independent and reserve throughput for both queues.
5. **Protect manual delivery.** Store system origin explicitly and prevent
   composer endpoints from editing or resending system rows. Reuse OneSignal
   credentials, validation and audit. Keep an independent, configurable
   automated daily budget, default 20 per UTC day during rollout, with atomic
   owner and global budget checks. When the budget is full, defer only while
   the candidate is still eligible. Turning off OneSignal or the feature
   stops automated delivery and prevents new outbox entries.

## 5. Admin and measurement

- Add a System section in Notifications with each rule's current state,
  last dispatch, eligible and suppressed counts by reason, provider outcomes,
  confirmed deliveries where available and experiment results. Keep test
  messages isolated to configured test destinations. Show provider acceptance
  and device delivery separately. Keep owner, device and provider identifiers
  out of aggregate UI and logs.
- Persist authenticated per-rule controls with an audit entry for each
  change. The deployment-level switch is the emergency override. Support
  **Off**, **Dry run** and **Live**. Dry run records bounded decisions and
  suppression reasons without creating delivery jobs or consuming send caps.
  Dry-run decisions cannot block live decisions.
- Use a stable, randomly allocated 20% owner holdout for the experiment.
  Log a comparable eligible decision time for both groups. Keep holdouts out
  of automated delivery for the full experiment and use the first eligible
  decision per owner for the primary per-rule analysis. Measure a foreground
  session within 24 hours of the eligible decision, with treatment measured
  as assigned even when delivery fails. This measures incremental returns.
  Report opens and device-confirmed delivery as secondary metrics where
  available. Store message/provider IDs server-side for joins.
- Measure Return reminders or master turned off, and observed OS opt-out,
  within seven days of assignment. Report these separately with eligible
  denominators and platform coverage. Review after at least two weeks and
  after the seven-day outcome window has closed for the last included
  cohort. Report sample sizes and uncertainty. Pause any rule with verified
  wrong-recipient, duplicate or out-of-window delivery. Make keep/adjust/pause
  decisions on incremental returns and opt-outs when the sample can support
  them. Leave inconclusive rules at the current exposure.

## 6. One release, end-to-end acceptance

1. **Build and migrate.** Ship additive private schema, reducers, worker,
   rule logic, admin operations and the mobile preference/registration
   changes. Verify old clients, manual campaigns and unrelated identity flows.
   Run regun-server `npm run verify` and `cd identity && npm run verify`,
   plus the game's and admin's verification suites.
2. **Exercise every rule before activation.** Seed signed-in and guest test
   owners across all windows, a two-device owner with current Training
   activity, and a real accepted leaderboard displacement. Check exact
   thresholds and stage precedence, caps, offsets/DST, rollover of activity
   windows, duplicate passes, restart after provider acceptance, stale rank,
   owner switches, expired windows, holdout and opt-out between enqueue and
   dispatch. Verify admin controls, audit, dry-run behavior and unchanged
   manual quota. Test enough seeded owners to traverse more than one scan page.
3. **Verify native delivery.** On physical iOS and Android test devices,
   exercise an account and a guest, foreground suppression, permission
   changes, sign-out and deletion, cold/warm taps, and provider expiry.
   Confirm the notification reaches only the intended install, within the
   allowed local window. Confirm no tap starts or interrupts a run.
4. **Deploy Off, then dry run.** Check migration on a non-production database
   before deploying. Deploy production with automated delivery Off. Run all
   five rules in Dry run through a full local evening window across the
   supported zones. Inspect decisions and suppression reasons, manual
   delivery, scan throughput and the size of the timezone-eligible audience.
   Resolve discrepancies before activation.
5. **Enable the full release together.** Move all five rules to Live for an
   initial 10% eligible owner cohort, with the holdout inside that cohort.
   First complete the production smoke test in §7 with public delivery off.
   Use stable cohort assignment. Verify the first real delivery evening and
   pause a misbehaving rule immediately. Advance exposure only after the
   cohort review in §5. Roll back by switching the feature Off and suppressing
   unexpired queued jobs. Keep the audit and preserve the manual path.

The implementation is ready for production activation when all five rules pass
their positive and negative acceptance cases, both mobile platforms pass real
delivery and routing, the creator can run and verify the production smoke
test, operators can stop queued sends, and treatment/holdout assignment is
visible in the admin report. Retention impact is a post-launch result.

Local verification exercised all five rules against SpacetimeDB with a mock
provider, including the additive schema migration, dry run, holdout, quota,
opt-out and duplicate prevention. The admin verification panel and notification
router also have focused tests. Physical delivery through OneSignal remains
the release gate below.

## 7. Hands-on verification for the creator

The release includes a **Verify delivery** panel under **Regun Admin →
Notifications → System**. From there, the creator can select a registered QA
install, run a supported scenario and open its result. The panel and scenarios
below are deliverables of this release. The existing composer test send can
check basic provider setup. Use **Verify delivery** to exercise the automated
rule, queue, sender and tap path.

### Set up the devices

Install the candidate on a physical iPhone and Android phone. From the game
repository, `make runRelease DEVICE=<device-id> RELEASE_CONFIG=<environment-config>`
uses the same configuration as the release build. Check that the config points
at the matching identity service and public OneSignal app ID. Use dedicated QA
owners and register their subscriptions in the environment's server-managed QA
allowlist. In the game, enable system notifications, the in-app master switch
and **Return reminders**. In Admin, confirm the intended environment, device
label, platform, owner type and local time before starting. At least one
account and one guest must pass on real hardware.

### Run all five scenarios in staging

Set the scenario's rule to Live with public exposure at zero. Background the
QA app before you queue the verification. Select an allowlisted device and
scenario. Use the panel's test activity
fixtures to represent the elapsed days and prepare the needed progress. These
fixtures apply only to QA decisions, so there is no waiting days or changing
phone clocks. Capture the real activity baseline when each scenario starts.
Any subsequent real activity on any linked device supersedes the simulated
absence and is checked again before delivery. Use a staging leaderboard with
two QA accounts for Dethroned.
The panel shows the next eligible send time. Run device delivery during the
real 18:00–21:00 window, subject to server quiet hours.

| Scenario | Setup | What you should see |
|---|---|---|
| Nudge | Guest, 2 days away, 0–4 settled runs | One **The shelter is quiet.** push. Tap lands at Home. |
| Progress | 4 days away and one recorded boss victory | The title reflects one victory. Tap opens Collection. |
| Return | 8 days away | One **Back to the shelter?** push. Tap lands at Home. |
| Winback | 31 days away | One **Still holding the line?** push. No earlier lifecycle rule fires. Tap lands at Home. |
| Dethroned | QA account A leads Breach Standard and is eligible by activity. QA account B submits a higher accepted score. | Only A receives **You lost first place**. Tap opens Leaderboards and B is first. |

Start with clean QA fixtures per scenario so that rules and cooldowns from
earlier test cases do not interfere. Run one case twice against the same
fixture to prove deduplication. Use a separately queued case to turn off
**Return reminders** before dispatch. Confirm Admin reports suppression and
the device receives nothing. Repeat with active Training on the account's
second device and with the rule paused. Check a second install for stray
notifications. Exercise a cold tap with the app closed and a warm tap from
Home. Confirm an incoming notification does not interrupt active combat.

### Verify the deployed production path

Keep public exposure at zero and set the Return rule to Live. Background the
QA app before you queue the verification. In **Verify delivery**, select
**Return** for each allowlisted production QA subscription in turn. The panel supplies isolated
eight-day activity evidence for the QA decision. That evidence cannot change
player presence, profile data or public leaderboards. The QA run still uses
the deployed eligibility, outbox, idempotency, worker, OneSignal credentials
and tap router. It respects the
global emergency override, actual permission, local delivery window and
send-time checks. Revalidate the allowlist and exact subscription at dispatch.
Audit each QA run and exclude QA results from public send budgets and
experiment reporting. Provide an explicit cancel action and expire the QA
authorization at the end of its selected evening.

For each backgrounded phone, verify one tray notification
with the expected title and body. Tap it and confirm Home opens. Open the
result in Admin and check the rule, intended device label, scheduled and
dispatch times in UTC and local time, provider acceptance, notification open, and the
app foreground report. Record the device receipt time and tap destination in the
release checklist. If provider acceptance appears but the tray is empty,
delivery remains unverified. After both phones pass, remove the QA allowlist
before enabling the initial public cohort.
