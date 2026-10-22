# Online latency pass — 21 October 2026

Authorized after creator's build9 review. Preserve server authority, gameplay timing,
control layout, current release identity and guest identity. No hosting migration or
higher tick rate without measurements.

1. Keep at most two useful movement commands before a simulation step, dropping
   obsolete movement but retaining the first unconsumed dash edge and its direction.
   Acknowledge dropped sequences; never grant extra time/speed or accept client time.
   Record server-assigned input age, dropped count and actual callback interval in
   the private acknowledgement. Expire individual delayed inputs as well as mailbox.
2. Replace remote ease-to-latest positions with a bounded timestamped snapshot
   track. Adapt a small interpolation delay to arrival jitter; extrapolate briefly
   using measured movement with wall clipping, then stop. Reset on epoch, reconnect,
   death/phase/large relocation. No remote presentation position affects combat.
3. Send combat state changes promptly with bounded concurrent requests and periodic
   keepalive, preserving sequence/epoch guards and authoritative ammunition/reload.
   Allow cosmetic first-trigger muzzle/recoil/audio when last-known ammo/reload/cooldown permit; suppress the matching confirmed cue. Bullets, ammo, hits and health stay authoritative.
4. Test backlog bursts, original dash heading, no speed-up, stale input, turns/stops,
   jitter, missing snapshots, collision, epoch/death reset and high RTT combat edges.
   Then analyzer/client suite/backend verify + isolated local protocol/native tests.
5. Deploy through the creator-authorized main auto-deploy route and run bounded
   fresh-guest private hosted checks; retain reports and compare input age, visual
   error and RTT. Report simulator limits. Measure route/server cadence separately;
   lack of VPS telemetry is not evidence of CPU or regional placement being at fault.

References: https://gafferongames.com/post/snapshot_interpolation/ and
https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking .
Adaptive buffer/extrapolation bounds are Regun hypotheses tested below, not values
copied wholesale from a different game's networking model.

Local gate: analyzer clean, client237 tests/five skips, server80 plus typecheck/build and prediction smoke passed. Six-player native local impairment test passed at200ms nominal RTT +/-20ms/direction; retained report: docs/validation/online-latency-local-2026-10-21.json. Hosted regression follows.

## Outcome

Backend1379097 was pushed to main and timing fields confirmed against the deployed
server. Client analyzer clean;237 tests pass/five skips. Backend80 tests/typecheck/build
and local protocol smoke pass. The shared 20Hz/jitter model requires remote tracking
error below65% of the previous ease-to-latest filter on the same controlled trace.
This is model evidence, not a measured percentage improvement on a phone.

Hosted co-op3/Breach and2/Foundry (4 active seconds each) and2v2/Ironworks (10s)
passed. Input-age p95 observations82–89ms; callback p95 about51ms. Initial3v3
had6 stalled samples/240 during a481ms acknowledgement gap, despite input-age
max91ms. Instrumented3v3 rerun (10s) passed: no stalls/240, input age p50
54.597ms/p95 88.664ms, callback p95 52.24ms, pending max11, stopped error
<0.000001. Event-loop timer gaps stayed <23ms while refresh gaps approached239ms.
That supports delivery jitter rather than a main-isolate render stall in this rerun;
it does not identify ISP vs SDK vs server subscription processing as the cause.
Both results are retained. No claim that long internet gaps have been eliminated.

Hosted1v1 actual-touch/combat/reconnect test passed: local movement24ms versus
371ms server echo, server-confirmed release218ms,12-second reversals without sampled
stalls, dash/reload/grenade/menu/reconnect and private-room cleanup passed. The server
remains authoritative over primary rounds/ammo/hits; first-trigger prediction only
shows muzzle/recoil/sound once and suppresses its matching confirmed cue. Actual
native listening and feel remain for creator review.

Five read-only fresh HTTPS checks measured TCP handshakes157–180ms after DNS from
the laptop. These are rough network-route round trips, not one-way game delay.
DNS/TLS startup costs are not charged to every established WebSocket input. Existing
NGINX WebSocket proxy buffering is already disabled. No region change, transport
rewrite or tick-rate increase was made. Next infrastructure work needs alternate
region p50/p95 comparisons from actual players, and VPS CPU/subscription telemetry;
current SSH key access is unavailable. Preserve state/keys if migrating later.

Reports: docs/validation/online-latency-*-2026-10-21.json . Tests use fresh guests and
private rooms; six SDK clients in one simulator process do not prove independent
physical-device, WAN, sustained frame-time or server-capacity acceptance.

Delivery: rebuilt the normal release app with the existing private define file and
Online enabled; in-place installation and launch confirmed on the creator's iPhone12.
Normal debug simulator apps installed/launched on iPhone17 and iPhone18 Pro. Identity
remains1.0.0+9. Existing IPA export predates this pass and was not rebuilt/uploaded.
Local impairment proxy/server stopped. No saved guest or solo profile was reset.
