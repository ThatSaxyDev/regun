# Boss arrivals —29 October2026

Release identity remains1.0.0+28. Work covers all native boss entry sites, Walker/
Ariet deployment camera and startup online policy prefetch. Final verification and
phone installation are recorded below once complete. Automated checks do not prove
physical motion comfort, encounter balance or device performance.

- `make verify`: analyzer clean; **934 passed / 5 intentional skips**.
- Additional offline-startup regression: startup suite **6 passed**; native arrival
  visual capture **1 passed**, for both mechanical bosses in both arenas. Final
  analyzer clean. The added test runs genuine local I/O outside the fake ticker.
- Spawn tests cover wall/corner clamping, multiple footprints, blocked/undersized
  arenas and companion separation. Existing portal checks cover every legacy boss
  in both arenas; mechanical native checks include distant entry/cover clearance,
  paused camera/deployment, return with wider zoom and no death focus.
- Native full-encounter/save/reward tests passed. The cannon integration assertion
  now allows lock plus full shell flight rather than a fragile two-second cutoff.
- Captures here are rendered native game-layer tests, **not physical-device footage**.
- Sibling server `npm run verify`: typecheck, **210 tests passed**, module build
  successful. Commit `5fa8353300e2b6a3378814a79a7b7cd8aebd5e9c` pushed to main.
  Co-op checks all active kinds, both players, both arenas and edge positions with
  full 220-unit stance clearance. Ordinary enemy distance rules are retained.
- `api-check.json` records public live health/features and unauthenticated account
  protection. Public checks cannot establish the deployed source revision.

Final device result: release build signed successfully (Xcode 38.8 seconds),
installed on the connected iPhone (Apple sequence 8376), and launched successfully.
A fresh device app query confirms version **1.0.0 / build 28**. No version increment
or distribution upload. Live API recheck: health 200, features 200 with
`onlinePlay:true` and `no-store`, account 401 without credentials. Server main is
5fa8353; these public API results do not expose its deployed revision.
