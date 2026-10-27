# Leaderboard foundation validation

26 October 2026. See [implementation scope](../../LEADERBOARD_IMPLEMENTATION.md).

- Game analyzer clean; full suite **792 passed / five intentional skips**.
- Admin analyzer clean; **68 tests passed**.
- Server module: **195 tests**, typecheck and build passed.
- Identity/API: **29 tests**, typecheck/build and one plain-Node compiled gateway smoke passed.
- Disposable real SpacetimeDB smoke: replay/changed-body rejection, exclude/fallback/restore, withdrawal/rejoin and operator isolation passed. A withdrawn review-pending record also cannot be restored.
- Flutter renders at844×390 logical pixels include simulated notch/bottom insets. Test API data is invented. Captures: [Home](home-844x390.png), [list](list-844x390.png), [profile](profile-844x390.png). Normal,1.5× and2× text navigation is covered. The verbose profile annotations were removed before these captures.

No production deployment, public enrollment, phone installation, measured public-scale capacity or physical-device acceptance is claimed. Exact beta limits and remaining rollout work are in the implementation document. Logs are local test outputs, not live user data.

Deployment-default follow-up: leaderboard reads and submissions now default on with no new environment setup. Explicit false kill switches and invalid-value rejection are covered. API31 tests, typecheck/build and compiled HTTP smoke passed; see `deployment-defaults-api-verify.txt`. Container routing assertions were extended but not rerun as a Docker deployment in this follow-up.


## Automatic accounts and guests — current acceptance

The creator superseded enrollment with automatic inclusion of all existing accounts and guests. Current verification: game analyzer clean; full suite **795 passed / five intentional skips**, followed by12 focused UI/outbox/registry tests after separating list publication from the receipt queue, and a scene regression for career usage continuing when100 receipt slots are full. The first full run had a nondeterministic training-nearby-enemy threshold failure; that test passed unchanged in isolation and in the clean full repeat. Admin analyzer clean/68 tests; module195 tests/typecheck/build; identity36 tests/typecheck/build plus compiled HTTP smoke all pass. The HTTP smoke now posts guest usage/presence, reads the resulting public profile, verifies private own-row credentials and rejects malformed presence.

Current Flutter fixture captures: [Home](automatic-home-844x390.png), [accounts and guests](automatic-list-844x390.png), [profile](automatic-profile-844x390.png). These are test renders, not real player data or phone screenshots.

Release1.0.0+26 built, installed over the network and launched on the connected iPhone; `automatic-ios-build.txt`, `automatic-phone-install.json` and `automatic-phone-launch.json` record those actions. Existing app data was retained. This does not prove physical performance/comfort. **No backend deployment was performed**; the updated module/gateway/nginx must deploy for the all-player endpoints to work on the phone.
