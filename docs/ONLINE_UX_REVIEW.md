# Online play UX review — 21 October 2026

Review requested by the creator before deeper multiplayer work. This is a proposed UI direction, not an implemented redesign or multiplayer acceptance claim.

## Evidence and limits

Reviewed `OnlineView`, `OnlineSession`, the shared menu shell, player labels, current design context and multiplayer delivery notes. Reran the two existing small-phone lobby widget tests at 1.0× and 1.8× text: both passed. Inspected their regenerated `build/test-previews/online-lobby.png`. These tests establish layout survival, not good hierarchy or native keyboard comfort. No physical keyboard reproduction or end-to-end production WebSocket test was performed.

The configured public schema URL returned HTTP 200 in approximately .77s during this review and advertised combat views. This is a point-in-time reachability check from the laptop, not proof of the phone's connectivity, authentication, subscriptions or successful asset preparation. Current source also gates public Online navigation behind `ReleaseFeatures.onlinePlay = false`; preserve that gate and release identity during a later UI pass unless explicitly changed.

## Verdict

The screen feels like a test harness wearing Regun buttons. It already uses the correct charcoal/brass palette, pixel headings and established actions, but does not organize the experience around joining friends and preparing to play. Its strongest opportunity is a compact staging room with a visible squad and a persistent next action.

Generic-template verdict: **fail for cohesion**, specifically default rounded Material input outlines, a long settings-form composition, literal `[x]` selection markers and equally weighted buttons. This is not a failure of the existing game art direction. Keep its tactile stepped surfaces rather than introducing glow, glass, decorative gradients or a new palette.

## Priority findings

### P1 — Connection feedback starts with an apparent failure

`OnlineView.initState` really does call `connect()`. However, the retry button depends only on `!connected`, so it appears during the initial attempt, asset preparation and automatic reconnection. `_connecting` is private and is not represented by the action's presentation. The command `busy` flag does not represent connection work. Initial capability detection also temporarily presents the legacy “connection test” title and unfinished-feature copy.

`connect()` catches every exception under the same “Cannot reach the server. Check your connection and retry” message. HTTP/schema rejection, malformed data, asset-loading failure, token/authentication and subscription failures can therefore all look like a phone network failure. Automatic retries occur every two seconds within a roughly 25-second window, but the screen does not make that process understandable.

**Direction:** expose explicit connecting/preparing/connected/reconnecting/failed states. Start with “Connecting…” and a modest activity cue; show “Retry” only after a failed attempt, with no competing retry action during an active attempt. Keep the title “Online” stable. Preserve form edits while reconnecting. Distinguish actionable failure categories in brief copy and retain structured diagnostics for investigation. Do not imply a successful connection until subscriptions are ready. Suggested passes: `/harden`, `/clarify`.

### P1 — Text entry has a visual treatment but no complete interaction design

The fields use `OutlineInputBorder` and floating Material labels. They lack explicit focus traversal, tailored submission, outside-tap dismissal and scroll-drag dismissal. The shared scroll view has no explicit keyboard dismissal behavior. The code field sits after every host setting, so recovering it requires navigating a long landscape form. Native details still need device reproduction; the missing interaction policies are visible in source.

**Direction:** one reusable stepped inset input plate, persistent label above, readable Orbitron value and clear brass focus treatment. Keep native editing/selection/paste/accessibility behavior inside that frame. Use restrained PressStart2P for labels/headings rather than tiny pixel text for everything.

Use one room-code editor, visually grouped 5+5 if helpful, rather than ten separate focus targets. Keep all ten existing characters; this is not a proposal to shorten the server contract. Normalize case and pasted separators; validate against the server alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. Provide an explicit Paste action with user-initiated clipboard access, clear invalid/short-code feedback and Join enabled only when the required name/code are valid. Reflect edits immediately in enabled states; the current controllers have no local change listener or field `onChanged` rebuilding the actions.

Give name entry a meaningful Done/Next action and code entry Join. Provide an obvious Done control when the keyboard is visible, outside-tap and drag dismissal, and keep the active field/action reachable above the keyboard. Tapping the full field plate should reliably reopen editing without losing the text or scroll position. Persist the preferred guest name locally. Suggested passes: `/normalize`, `/harden`, `/adapt`.

### P1 — The waiting room does not make the group visible enough

Member insert/update/delete subscriptions already refresh the lobby. Player joining is not entirely unimplemented: a text row and count update. What is missing is clear arrival feedback, spatial continuity, empty-slot presentation and a readable distinction between identity, loadout, team, readiness and connection health.

The inspected 667×320 render spends nearly the entire body on the room heading and six pipe-separated text rows. Loadout and Ready/Start sit below the fold. Versus members alternate teams in slot order instead of visually forming two teams. Host identity and remote loadouts are not presented in the roster.

**Direction:** co-op squad slots, or two explicit team columns for Versus. Each occupied slot shows a bounded existing survivor portrait, name, You/Host marker, chosen weapon and persistent Ready/Choosing/Reconnecting text. Empty slots say “Waiting for player”. Treat connection quality as secondary. A brief “Ada joined” event plus a restrained slot entrance makes arrivals noticeable; a departure frees the slot, while a temporary disconnect stays visibly reserved according to authoritative server state. Suppress fabricated join events when a reconnect resynchronizes the whole roster. Respect Reduced Motion and announce important changes accessibly.

Do not invent a host-migration promise. If the host leaves or the server closes the room, explain the actual outcome and provide a route back. Suggested passes: `/arrange`, `/onboard`, `/animate`.

### P1 — There is no persistent answer to “what happens next?”

Ready, host Start, generic requirements and Leave all live at the bottom of the scrolling body. A disabled Start requires the host to inspect every row and infer the blocker. Most selection/actions share the same visual weight.

**Direction:** pin an action rail. Guests get Ready/Not ready and “Waiting for host” when appropriate. Hosts get Start with the specific blocking reason: “Waiting for one more player”, “Ada is choosing”, or “Balance the teams”. Reflect the real server rules: co-op can start at two players even though there are three slots; Versus requires its selected full teams. Changing loadout/options must visibly clear readiness as the server requires. Keep Leave secondary and preserve the current authoritative start checks. Suggested passes: `/clarify`, `/arrange`.

### P2 — Joining a friend is buried inside room creation

Both paths share one long form; a joining player passes mode, arena, team-size and account metadata before reaching the code. Literal enum/map IDs and legacy capability explanations also leak into player copy.

**Direction:** start with Create room / Join room, a compact editable name and a quiet connection status. Create reveals host settings; Join reveals code/Paste/Join. Reuse the established Survivor/Weapon catalog language inside the lobby, showing the assembled kit persistently and moving detailed selection into a bounded preparation panel. Online wins/scrap belong in a secondary profile area. Suggested passes: `/distill`, `/arrange`.

## Proposed composition

1. Online entry: stable heading, compact name, Create/Join choice, connection status.
2. Create: Co-op/Versus, applicable arena/format, Create room.
3. Join: one ten-character code field, Paste, Join; room errors beside this action.
4. Lobby: room code + Copy with inline “Copied”; arena/mode summary; squad/team slots; compact assembled kit; pinned Ready/Start and specific status. Use shared stepped framing and restrained brass, without boxing every label separately.

Keep the header and primary action visible on ordinary landscape phones. Scroll only the preparation content when needed; deliberately support enlarged text and keyboard insets rather than forcing everything to shrink. Layout should remain useful while connecting, disconnected, partially full, full, unready and transitioning to the match.

## Provisional usability score

Scores are based on source and the widget render, not a completed native usability study. Scale: 0 absent, 4 excellent.

| Heuristic | Score | Main evidence |
|---|---:|---|
| System status | 1 | Retry during connecting; arrivals have little emphasis |
| Familiar language | 2 | Familiar room/ready terms mixed with test copy and raw IDs |
| Control and freedom | 2 | Back/Leave exist; keyboard exit policy incomplete |
| Consistency | 2 | Shared buttons, default Material field structure |
| Error prevention | 1 | Join lacks required-field gating; code format incompletely constrained |
| Recognition over recall | 2 | Copy/code visible, but teams/loadouts/next action weak |
| Efficiency | 1 | Long join path; no explicit Paste or tailored submit |
| Minimal focused design | 1 | Preparation, diagnostics and joining mixed in one scroll |
| Error recovery | 1 | Catch-all connection message; broad request errors |
| Contextual guidance | 2 | Starting requirements exist, but are generic and buried |
| **Total** | **15/40** | **Poor: structural UX pass needed** |

Cognitive-load checklist: five failures—single focus, grouping, hierarchy, one decision at a time and progressive disclosure. Chunk sizes are generally bounded; visible choices and Copy give partial recognition support. This is a heuristic assessment, not a measured cognitive test.

Persona walkthroughs:

- First-time guest: sees a retry before knowing whether an attempt failed; must pass host settings to find Join; cannot quickly tell whose action is blocking the match.
- Returning friend: cannot directly paste/join through a compact path; has to enter the preferred name again and hunt the field/action after keyboard changes.
- Player with enlarged text or assistive input: existing tests show no overflow at 1.8×, but the action remains far down the scroll; join/ready changes lack dedicated announcements. Custom framing must retain native text semantics.

Minor points: replace default SnackBar copy feedback with nearby confirmation; show friendly arena titles; use a persistent selected marker instead of `[x]`; keep errors near the relevant action; preserve names/codes during transient failure. No need to add chat, public matchmaking, elaborate lobby animation or new gameplay systems for this first pass.

## Research and application

- [Unity Multiplayer: Lobby events](https://docs.unity.com/en-US/mps-sdk/lobby-events) documents membership and player/lobby-data updates, and warns that events can be unreliable or unordered. Application here: visible persistent slots plus brief transition feedback, derived from reconciled authoritative state. This is a UI/state lesson, not a recommendation to replace SpacetimeDB with Unity.
- [Apple HIG: Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields) recommends clear field purpose, persistent labels where useful, appropriate input sizing, logical focus order and context-sensitive validation. Application here: labeled code/name plates that retain native text-editing behavior.
- [Apple HIG: Virtual keyboards](https://developer.apple.com/design/human-interface-guidelines/virtual-keyboards) recommends an appropriate keyboard and meaningful Return-key action. Application here: Done/Next/Join and intentional handling of the landscape keyboard.

The proposed pixel lobby composition is a design recommendation for Regun, not a layout prescribed by those sources.

## Recommended next pass and acceptance

Order: `/harden` connection/input states; `/normalize` field and selector treatments; `/arrange` entry/lobby/action rail; `/clarify` status and blockers; `/animate` bounded membership feedback; `/polish` final consistency.

Verify initial connection without a false Retry, distinct failure paths, duplicate-action prevention and preserved drafts; native iOS/Android keyboard open/dismiss/refocus/paste; 2–3-player co-op and 1v1/2v2/3v3 slot/readiness transitions; changing loadouts clearing Ready; reconnect without duplicate arrival announcements; host leave and failed joins; small landscape, large text, screen reader and Reduced Motion. Exercise these with delayed and failed fake sessions before a real two-device review. Keep the public release gate, version and server authority intact.

No runtime files, hosting configuration or installations changed in this review.

## Implementation follow-up

The creator authorized the UI pass after this review. The resulting implementation and device acceptance checklist are recorded in `REGUN_PROGRESS.md` and `PLAYTEST_GUIDE.md` under Online preparation UI. The evidence, score and “no runtime files changed” statement above describe the original review stage. The subsequent implementation changes native UI/session presentation and lifecycle guards; it does not claim to resolve the reported end-to-end phone connection failure. The public release gate and build identity remain intact.
