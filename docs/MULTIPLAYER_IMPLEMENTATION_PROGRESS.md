# Multiplayer implementation ledger — 21 October 2026

The creator accepted shared movement and authorized completing the approved private multiplayer scope. Client and independent sibling server remain on main. Release identity stays 1.0.0+7. [Play, test and deploy](MULTIPLAYER_TEST_AND_DEPLOY.md) describes the delivered behavior. This ledger distinguishes implemented code from hands-on acceptance.

## Implemented

- Native rooms, readiness, 2–3 total co-op participants and 1v1/2v2/3v3 Versus; default enemies On / optional Off; ten-character invitations, all-player numeric/text/color application RTT, socket replacement/reconnect/generation protection.
- Four authoritative weapons, swept first body/cover contact, cumulative range/falloff, full reload commitment and Carbine-only tactical timing, bounded secondary procs, damage/guard/downed/death and round control. Flutter uses shared actor/weapon/material art and audio.
- Normal Breach/Foundry co-op survival with eight normal roles/eight boss planners, encounter limits, shared funded XP, thirty VIII families/six explicit fusions, cores, revive/bleed-out/defeat, safe boss-break re-entry, authored Foundry vents and timed Breach supplies/personal deduplicated entitlements.
- Competitive first-to-three rounds, overtime/draws, teammate spectator camera, forfeit/expired grace, equal four-weapon/Rook access and a bounded neutral AI preset. No survival drops/build offers in PvP.
- Ossuary Cross and Ironworks Relay each have independent 1v1/2v2/3v3 Tiled variants, spawns, AI sockets, route markers and hashes. Ashen Cloister has three candidate blockouts and remains unselectable. Navigation, movement/dash/projectiles and secondary attacks share hard cover. Generated stone/iron kit source/prompt/hash/frame bounds are under `art/source/multiplayer`; regular-arena perimeter art preserves collision.
- Lobby loadouts/maps, aim/fire/reload/dash, personal picker/reroll/ban/fusion, hold revive, objective locator/capture HUD, menu/background/reconnect, result/rematch and a separate online account ledger. Native guest tokens use pinned Keychain/Keystore-backed storage. Web guests use memory. Base art loads before combat capability/readiness; optional boss/supply/high-resolution wall atlases are leased.
- Private, once-only terminal records/result receipts/account totals, bounded history/evidence and no uploaded solo balances. Private PvP is unrated. A callback gap over five seconds ends a live game as interrupted with no reward; no lethal fast-forward or saved online-run promise.

## Verification

- Server: **67 tests**, typecheck and SpacetimeDB module build pass. Includes weapon/reload/falloff, actor bodies, VIII progression/real recipes, supply timeline/receipts, all eight bosses in both phases, nine format-specific map variants/navigation, shared language fixtures, settlement/retry/forfeit/interruption and safe checkpoint return.
- Client: analyzer clean; **180 tests pass**, four opt-in skips. New contracts and small-phone/large-text picker/result/combat/controls tests pass; rendered `build/test-previews/online-combat.png` inspected. Existing art/Boss Rush 32MiB gates pass. Online leases a 512px wall decode separately; regular-arena trim uses a 192px decode to keep solo's existing budget intact.
- Real non-owner module clients: scoped combat firing/reload/three wins/rematch, wrong-room/generation rejection; two-player Breach through earned choices/resume/first supply; three-player Foundry through earned choices/resume; both PvP maps × all three formats with default paired arrivals, no survival rewards and once-only forfeit receipts. Two simultaneous six-player rooms exercised locally.
- Standalone Dart: all party formats plus scoped movement, ping and reconnect pass against complete schema. Shared weapon/survivor/boss/XP JSON fixtures pass independently in Dart and TypeScript. Canonical string identity keys need byte-order normalization at the Dart boundary; typed BSATN identities remain unchanged.
- Native iPhone17 simulator: secure storage write/read/delete passes; two-client combat/loadouts/server shots/enemy-scene/reconnect passes. iOS signed release builds. Docker image builds; disposable gateway room/combat/route protection and persistent container-replacement checks pass. Android release APK builds (152.5MB); native builds were rerun sequentially after a generated integration-test registrant conflicted with concurrent builds.
- Local ordered TCP proxy combat smoke passes nominal 100ms and 200ms RTT with jitter. The harness preserves stream order and independently delays arrivals; it does not simulate real WAN packet loss. Early harness failures exposed sequential request/backlog assumptions in tests; corrected smoke mirrors the client's independent movement/combat streams and waits for remote snapshots before asserting.

## Important implementation choices and limits

Movement retains the creator-approved server-authoritative control with display interpolation. This build does not implement local input prediction/replay, speculative hit confirmation or server rewind. The plan's prediction/30Hz/lag-compensation experiments remain possible follow-up work if real WAN play calls for them; do not claim they were verified. The fixed 1500×700 viewport prevents aspect-ratio advantage. There is no stealth fog by design: room actors are replicated while walls block attacks, chains, drones and splash under the declared rules.

Public matchmaking, ranked ratings, OIDC/account linking/cross-device recovery and production IP abuse throttling are outside the private-room release. Online scrap is a separate authoritative tally, not an upload/merge into locally editable solo progression. A lost device/reinstall has no recoverable linked account yet. A 128-room cap is a safety ceiling, not measured capacity.

Hands-on acceptance remains: actual two/three-person co-op and every map/format on real devices and networks, weapon/map balance, warning readability, sound, touch comfort, thermal/frame pacing, interruption/Wi-Fi/cellular transitions and restoration rehearsal. Headless, simulator and build evidence do not approve these. The third map remains a stated candidate rather than a third finished release map.

## Delivery state

Code changes are coordinated across both main branches. Production needs the creator's Dokploy redeploy after the final commits; no VPS settings/data were changed in this pass. Root Dockerfile, port3000, HTTPS and persistent `/var/lib/regun` remain; no new required environment variables. Back up the full stopped volume with its keys/CLI identity before updating, and follow the guide's compatible rollback/restore procedure. The public endpoint remains the earlier movement deployment until that update.

The final simulator game build has been restored and launched against local `regun-dev` (loopback3100); the native integration-test harness is no longer the installed app. Both GitHub repositories report main as their default branch.

Final server commit: `edd2bde` on main. Both main branches are also the verified GitHub defaults. Docker gateway combat and persistent replacement smoke both pass. The normal simulator app is installed/launched against the laptop local server.
