# Online boss portals — 26 October 2026

## Delivered source and phone candidate

Online co-op now consumes a server-owned `boss_reveal` phase. All eight bosses
use the existing authored portal grammars. Each client's camera pans from its
own survivor/spectator anchor to the committed spawn, then returns before the
hold ends. The fight view widens to .88 and restores after the last living boss.
Reduced Motion keeps the camera anchored and settles zoom without a sweep.
Peripheral charcoal focus fades in and out. No client acknowledges or extends
the hold based on art loading, network reconnects or motion preferences.

Boss corpses remain in authoritative scene data for 1.55 active seconds. Shared
portal geometry, leased death art and body fade/sink render in world space below
living actors. They never select a camera target. Existing +2 HP rewards, attack
cleanup and compact victory wording remain once-only. Combat continues during
departures; this is not a second entrance hold.

The `boss_presentation` schema marker selects combat capability9. A room must
have unanimous capability9 for held entrances; older servers and mixed-version
rooms retain their existing behavior and admission. No new public table, client
position/outcome authority, balance field, weapon/upgrade admission or admin
catalogue is introduced. Identity API/admin consume neither the new optional
match-phase payload nor the combat capability ceiling; their auth, publication,
pinning and catalogue contracts are unchanged.

## Authority and interruption

A due boss is staged before gun/world/projectile clocks advance. The hold returns
before damage, hazards, enemies, reload, protection, progression, supply, revive,
support or active match clocks update. Entry and release bump the existing input
epoch, retiring queued movement/fire/dash/reload intentions. All accepted combat
reducers retain their active-phase checks. Boss choices and recovery pulses are
not emitted or consumed by this phase. The original boss arrival/attack clocks
and all numerical tuning remain intact after resume.

The server holds for a fixed bounded interval, never waits for a client, and
publishes remaining time and immutable committed actor locations. Late arrivals
render current progress; stale local interpolation is capped to one server step.
Background/disconnection cancels local controls; returning to an active match
does not replay the entrance. Online interruption uses existing server/session
recovery, not Solo checkpoints. Existing long scheduler-stall termination stays.

## Evidence and checks

- Game analyzer clean; full game suite780 passed, five intentional skips.
- Backend full verification192 passed, typecheck and module build passed.
- Three-player real local SpacetimeDB transport test passed all eight bosses:
  shared phase, exact frozen scene/HP/ammo/projectile/combat-clock snapshots,
  rejected held combat input, bounded release, reconnect without hold replay,
  corpse retention/cleanup and one victory event. See server-transport.json.
- That transport harness uses a disposable loopback module with test-only boss
  stage/kill controls and a sign-in bypass. Shipped auth is untouched; this test
  does not validate email authentication, WAN performance or production rollout.
  Reproduce in the sibling backend with `npm run smoke:boss`.
- Client tests cover camera return, no corpse target, zoom recovery, late joins,
  bounded stale samples, Reduced Motion and HUD suppression of round-result copy.
- shadow.mp4, saint.mp4 and marshal-reduced.mp4 are six-second844×390 captures of
  the actual online widget using scripted authoritative snapshots. They are not
  physical-phone footage, live network recordings or performance/visual approval.
  Reproduce with `REGUN_ONLINE_BOSS_CLIPS=1 flutter test test/online_boss_render_test.dart`.

Normal signed lib/main.dart1.0.0+25 built, installed on the paired iPhone and
launched. Existing staged work/version and app data were preserved. No new IPA,
TestFlight upload or public backend deployment is claimed. The updated client
alone cannot activate online entrances on a server without the new capability.
Creator phone/WAN comfort, crowded performance and visual acceptance remain open.

## Rollout

Deploy the matching sibling backend revision through the existing Dokploy main
workflow, after finishing/draining matches and preserving the persistent state
volume. No schema deletion, balance publication or new runtime secret is needed.
Verify the public schema advertises boss_presentation, then use updated clients
for all participants. A mixed room deliberately retains its old entrance flow.

A read-only public schema check on26 October confirmed that the currently hosted
server does not advertise boss_presentation; see public-capability.json. The new
phone client therefore retains fallback behavior there until backend rollout.
