# System-Generated Notifications — Implementation Plan

Status: **Draft for review**
Date: 11 November 2026
Scope: `../regun-server` (identity service, SpacetimeDB), `../regun` (mobile), `../regun-admin`
Depends on: the OneSignal push foundation in `docs/PUSH_NOTIFICATIONS_PLAN.md`

---

## 1. The problem with "manual only"

Today the admin app is the only thing that can create a push. Every message is a
human typing a title and body, choosing an audience, and pressing send.

That is right for announcements. It is wrong for the two things that actually
retain players:

1. **Reactive messages** — something specific happened to *this* player, right
   now. "(name) just took your best." A human cannot send that.
2. **Lifecycle messages** — a player drifted away three days ago and nobody
   noticed. A human should not have to remember to look.

Neither exists. `PushService.tick()` only *sends* rows already in
`push_message`; nothing *creates* them except the composer.

This plan adds a **notification scheduler that writes messages itself**, using
facts the server already knows about each player.

---

## 2. What we already know about a player

Everything below is already collected and available server-side. No new client
instrumentation is needed for any of it.

| Signal | Source | Example use |
|---|---|---|
| `last_seen_at` | `push_subscription`, `player_device` | Dormancy detection |
| Last session time | same | "Played today" suppression |
| Timezone offset | `push_subscription.timezone` (`UTC+60`) | Local-evening delivery |
| `totalBossVictories` | `player_device.payload` | "One boss from a new weapon" |
| `totalKills`, `eliteKills` | same | Milestone framing |
| `bestScore`, `bestSeconds` | same | Personal-best framing |
| `scrap` | same | Wallet framing |
| `recordedRuns` | same | First-run / habit framing |
| `publicUsage` | same | Which weapon and survivor they actually play |
| `bossWins` map | cloud profile | Which bosses remain unbeaten |
| `leaderboard_best` | SpacetimeDB | Rank, who beat them |
| Purchase history | economy tables | Post-purchase follow-up |

**Not available, and therefore out of scope:** "you abandoned a run at wave 7."
Run checkpoints are local-only; the server never learns a run was interrupted.
Adding that requires a client change and is deferred (see §10).

---

## 3. Principles

These are constraints, not suggestions. Every rule below is enforced server-side.

1. **Only send when there is something true to say.** No message may exist
   without a fact behind it — a rank lost, a streak ending, a boss unbeaten for
   30 days. "We exist" is not a fact.
2. **One message per player per three days.** Hard cap, all sources combined.
3. **Never within 12 hours of a session.** If they just played, they do not need
   reminding.
4. **Local evening only, 18:00–21:00** in the player's own offset. No 3am pings.
5. **Dormancy is a precondition, not a trigger.** A player who played yesterday
   is never eligible, regardless of what else is true.
6. **Silence is the default outcome.** The scheduler should decide "no message"
   for most players most days. A scheduler that fires for everyone is broken.
7. **Every message is attributable.** Each send records which rule produced it,
   so we can disable a rule that annoys people.

---

## 4. Two kinds of system message

### 4.1 Reactive (event-triggered)

Fires from an event that just happened, to one player, once.

| Event | Trigger point | Timing |
|---|---|---|
| **Dethroned** — someone beat your best on a board | leaderboard accept | immediate, if not quiet hours |
| **Board reset** — weekly boards wiped, you had a rank | leaderboard rollover | local evening |
| **Personal best beaten by yourself** | leaderboard accept | skip — they were just playing |
| **Purchase settled** | economy release | immediate (transactional) |
| **Account risk** | session created on new device | immediate (transactional) |

Reactive messages are inherently non-spammy: they only fire when the event is
real and rare. "Dethroned" fires at most once per board per player.

### 4.2 Lifecycle (scan-based)

A periodic scan looks for players who satisfy an exact condition. These are the
messages that need the most discipline, because nothing external triggers them.

| Stage | Condition | Cap |
|---|---|---|
| **Nudge** | inactive ≥ 2 days, ≤ 4 recorded runs | once per player |
| **Progress** | inactive ≥ 3 days, ≥ 1 boss victory, a boss unbeaten | once per 7 days |
| **Return** | inactive ≥ 7 days | once per 14 days |
| **Winback** | inactive ≥ 30 days | once ever |

A player passes through one stage at a time. The scheduler picks the *lowest*
stage that matches; it never sends two.

---

## 5. Copy

Writing is the product here. One line of false enthusiasm undoes a month of
restraint.

### Voice

- Understated. The game's own tone — dry, slightly grim, never chirpy.
- Second person, present tense.
- No exclamation marks. No emoji. No "Hey there!".
- Max 60 characters title, 180 body. Both stay well under.
- Refer to concrete things: a boss name, a weapon, a score, a number.

### Approved copy

**Reactive**

| Rule | Title | Body |
|---|---|---|
| Dethroned | `Your best was beaten` | `Someone took your spot on the board. It is still your score to reclaim.` |
| Board reset | `New boards, old grudges` | `The week reset. Your best from last week is gone with it.` |
| Purchase settled | `Scrap received` | `Your purchase cleared. It is in your wallet.` |
| New device sign-in | `New sign-in to Regun` | `If this was not you, secure your account from Settings.` |

**Lifecycle**

| Stage | Title | Body |
|---|---|---|
| Nudge (new player) | `Your first run is waiting` | `You have not dropped in yet. The arena does not get easier.` |
| Nudge | `The shelter is quiet` | `Rook is rested. One run to shake the rust off.` |
| Progress (unbeaten boss) | `Still unbeaten` | `The Bellkeeper is still standing. You are one victory from new firepower.` |
| Progress (close to best) | `A few points short` | `Your last run came within reach of your best. It is still there.` |
| Return | `The Foundry has not changed` | `It has been a week. The same corridors, the same things waiting in them.` |
| Winback | `Still holding the line?` | `It has been a month. The arena is quiet without you.` |

Templates with slots must resolve to real values or be suppressed. `{boss}` uses
the player's actual next-unbeaten boss. If no value resolves, the message is not
sent.

### Copy we will not write

Banned by policy, encoded in tests:

- Any message that asserts a fact we cannot verify.
- Any message sent to a player who played in the last 12 hours.
- Imperatives that pressure ("Don't lose your streak!").
- Anything referencing money the player has not spent.
- False urgency of any kind.

---

## 6. Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│ PushScheduler (identity service, 60s loop)                       │
│                                                                  │
│  1. eligibility scan                                             │
│     ├─ inactive ≥ stage threshold                                │
│     ├─ last session > 12h ago                                    │
│     ├─ interval cap satisfied (1 per 3 days)                     │
│     ├─ stage cap satisfied (per-stage cooldown)                  │
│     ├─ within local 18:00–21:00                                  │
│     └─ consented (OS granted + master on)                        │
│                                                                  │
│  2. pick ONE stage (lowest matching)                             │
│  3. resolve copy template against player facts                   │
│  4. write push_message row (kind=campaign, category=reengagement)│
│  5. existing sender delivers it                                  │
└──────────────────────────────────────────────────────────────────┘
```

Deliberately reusing the existing `push_message` table and `send()` path: one
delivery implementation, one audit trail, one place where idempotency lives.

### 6.1 Scheduler loop

Runs on the existing 60-second worker in `main.ts`, alongside `push.tick()`.

- Per pass, process at most **20** candidates (bounded work).
- Each candidate resolves independently; one failure never blocks the batch.
- A per-player advisory claim prevents a duplicate if a pass overlaps.

### 6.2 Idempotency

A lifecycle message is keyed by `rule + owner + stage + cycle`, hashed into the
existing `idempotencyKey`. A crashed or restarted pass cannot double-send.

### 6.3 Local evening

`push_subscription.timezone` stores a fixed offset (`UTC+60`). Evening eligibility
is computed from that offset, not the server's UTC clock. Subscriptions without a
parsed offset are **skipped**, never defaulted to a guess.

---

## 7. Data model changes

### 7.1 `push_rule_run` (new)

One row per system-generated message, for auditing and per-rule kill switches.

| Column | Type | Notes |
|---|---|---|
| `key` | `t.string().primaryKey()` | `owner:rule:cycle` |
| `owner` | `t.string().index("btree")` | |
| `rule` | `t.string().index("btree")` | `dethroned`, `nudge`, `progress`, `return`, `winback`, … |
| `stage` | `t.string()` | Lifecycle stage, empty for reactive |
| `messageId` | `t.string().index("btree")` | The `push_message` produced |
| `createdAt` | `t.u64()` | |

### 7.2 `push_engagement` (new)

One row per owner: the caps that cannot be derived from history cheaply.

| Column | Type | Notes |
|---|---|---|
| `owner` | `t.string().primaryKey()` | |
| `lastSentAt` | `t.u64()` | Any system message |
| `lastStage` | `t.string()` | Highest stage sent |
| `lastStageAt` | `t.u64()` | Cooldown anchor |
| `sentCount30d` | `t.u32()` | Rolling volume guard |
| `mutedUntil` | `t.u64()` | Set if the player disables notifications |

### 7.3 Admin control

`push_rule` config is server env, not a table, for v1:

```dotenv
ONESIGNAL_REENGAGEMENT_ENABLED=true
ONESIGNAL_RULE_DETHRONED=true
ONESIGNAL_RULE_NUDGE=true
ONESIGNAL_RULE_PROGRESS=true
ONESIGNAL_RULE_RETURN=true
ONESIGNAL_RULE_WINBACK=true
ONESIGNAL_MAX_SYSTEM_PER_30D=6
```

Every rule can be killed independently without a deploy of logic.

---

## 8. Eligibility (exact)

A player is eligible for a lifecycle message only if **all** hold:

```
master switch on
AND OS permission granted
AND subscription not disabled
AND not deleted
AND last_seen_at is a real timestamp (not 0)
AND now - last_seen_at  >  12 hours          // not just-played
AND now - last_seen_at  >= stage threshold    // dormant enough
AND now - last_sent_at  >  3 days             // global interval
AND now - last_stage_at >= stage cooldown     // per-stage
AND sent_count_30d      <  6                  // volume guard
AND local hour in [18, 21)                    // evening
AND stage != last_stage OR stage upgraded     // never repeat a stage
```

If any condition fails, **no message**. The scheduler returns `0 sent` for most
passes, and that is the correct behaviour.

---

## 9. Where the scheduler must not run

- **After a purchase** — purchases already trigger a transactional receipt.
- **During a live session** — enforced by the 12-hour rule.
- **To a player mid-run** — a push never interrupts a run; the client already
  suppresses foreground banners during combat (`suppressForeground`).
- **To an opted-out player** — consent is re-checked at send time, not just at
  schedule time, because they may have changed it between the two.
- **In Training** — practice sessions still count as activity.
- **If OneSignal is disabled** — the whole scheduler is a no-op, not a queue
  builder.

---

## 10. Deferred — needs client work

Worth naming so the gap is explicit:

| Idea | Why deferred |
|---|---|
| "You left a run unfinished" | Checkpoints are device-local; server has no signal |
| "Your squad is online" | Requires presence aggregation across rooms |
| "New personal best" | Wrong direction: they were just playing |
| Per-weapon mastery nudges | `publicUsage` exists but is coarse |

The interrupted-run message is the strongest candidate for a v2, and needs one
client change: on checkpoint save, report `{runId, mode, wave, startedAt}` to the
server. Roughly a day of work, but it must come after this ships and is measured.

---

## 11. Measurement

Without numbers, this becomes a machine for sending unwanted notifications.
Track from day one, per rule:

- sent, delivered (OneSignal)
- opened (OneSignal click)
- **session within 24h of delivery** — the only metric that matters
- **notifications disabled within 7 days of receiving** — the failure metric

Kill rule: if a rule's disable-rate exceeds its re-engagement-rate, it is removed.
That decision should be automatic, not a judgement call later.

---

## 12. Phases

### Phase 0 — Instrument (0.5 day)
- Add `push_rule_run` and `push_engagement` tables + reducers.
- Record `last_stage`, caps, and rule attribution on every system send.
- No behaviour change; nothing sends yet.

**Exit:** tables exist, migrations applied, existing sends unaffected.

### Phase 1 — One reactive rule (1 day)
- Implement **Dethroned** only.
- Requires reading `leaderboard_best` before and after an accept.
- Wire into the leaderboard accept path, after commit.

**Exit:** beat a test account's score, the other account receives exactly one
message. No other player receives anything.

### Phase 2 — One lifecycle rule (1 day)
- Implement **Return** (7 days) only, behind `ONESIGNAL_REENGAGEMENT_ENABLED`.
- Full eligibility chain, local-evening gate, all caps.

**Exit:** a synthetic player with `last_seen_at` 8 days ago receives exactly one
message at their local evening. A player seen 6 hours ago receives nothing.

### Phase 3 — Full ladder (2 days)
- Add Nudge, Progress, Return, Winback with stage precedence.
- Template resolution against real facts; suppress on unresolved slots.

**Exit:** one sweep across a seeded population produces exactly the expected
messages, verified against a fixture table.

### Phase 4 — Admin visibility (1 day)
- Read-only **System** section in the admin Notifications tab: per-rule counts,
  last fire times, disable-rate.
- Per-rule kill switch surfaced in the UI.

**Exit:** you can see what fired and turn a rule off without a deploy.

### Phase 5 — Measure and prune (ongoing)
- Two weeks of real data.
- Remove any rule that costs more opt-outs than it earns sessions.

---

## 13. Testing

**Unit**
- Eligibility matrix: every condition individually blocks a send.
- Stage precedence: a player matching Nudge and Return gets only Nudge.
- Caps: 3-day interval, per-stage cooldown, 30-day volume.
- Evening gate across offsets: `UTC-300`, `UTC+0`, `UTC+60`, `UTC+330`.
- Missing/zero `last_seen_at` and unparseable timezone → skipped.
- Template slot resolution; unresolved slot → suppressed.

**Integration**
- Leaderboard accept produces one `dethroned` row, with correct recipient.
- Two scheduler passes over the same fixture produce one message, not two.
- Restart mid-pass does not duplicate.
- Opt-out between schedule and send suppresses delivery.

**Regression**
- Manual admin sends are unaffected.
- Transactional sends still bypass caps and quiet hours.
- Existing `push_message` ordering and audits unchanged.

**Acceptance (physical)**
- A real tester who has been away 8 days receives one message at their local
  evening, and tapping it opens the menu (never a match).
- A tester who played an hour ago receives nothing for 12 hours.

---

## 14. Open decisions

1. **Stage thresholds.** Proposed 2 / 3 / 7 / 30 days.
   *Recommendation:* ship as proposed, tune after two weeks of data.
2. **Evening window.** Proposed 18:00–21:00 local.
   *Recommendation:* yes; widen only if open rates justify it.
3. **Dethroned on every board, or best board only?**
   *Recommendation:* best board only — otherwise one bad day sends five.
4. **Guest eligibility.** Guests have `last_seen_at` and consent but no account.
   *Recommendation:* include them for lifecycle; they are the majority of players.
5. **Should the scheduler respect `ONESIGNAL_QUIET_HOURS`?**
   *Recommendation:* no — the local-evening gate supersedes it and is stricter.
6. **Do Training sessions count as activity?**
   *Recommendation:* yes; someone playing Training is engaged, not lapsed.
7. **Kill-switch default.** All rules on at launch, or staged?
   *Recommendation:* Dethroned + Return on; the rest off until measured.

---

## 15. Definition of done

The first shippable slice is Phase 1 + Phase 2:

- A player who loses a rank receives one message about it, immediately.
- A player dormant seven days receives one message in their local evening.
- A player who played an hour ago receives nothing.
- Every send is attributable to a named rule in `push_rule_run`.
- Any rule can be disabled via env with no code change.
- No message is ever sent without a fact behind it.
