# Stored dash and grenade upgrades

23 October 2026. Two new utility families join normal XP/supply offers and Collection.

- Double Dash I adds one loaded dash; II is presented as Triple Dash. Start with one, default upgraded maximum three.
- Grenade Reserve I/II each adds one loaded grenade. Start with two, default upgraded maximum four.
- Both recharge sequentially using existing Quickstep / Ordnance Cycle timing. Buying a slot loads only that slot, preserving the first pending recharge. Dashes cannot retrigger inside an active dash. No changes to damage, speed, protection duration, grenade fuse or primary ammunition.

Admin → Balance → Power-ups → Double Dash / Grenade Reserve exposes **Maximum upgraded capacity**. Integer values are dash 2–3 and grenade 3–4. These are upgraded totals, not starting supplies. Lower caps reduce eligible ranks so there is no redundant offer. The API rejects fractional/out-of-range totals. These fields are `powerups.dashCapacity.capacity` and `powerups.grenadeCapacity.capacity` in the shared 211-field catalogue. Hard limits remain three/four as requested.

Game controls retain their original touch geometry, mirrored layout and opacity. Dash shows up to three charge markers; grenade shows up to four. The first empty marker fills with recharge progress. Upgrade cards use the actual rank limit, Collection describes two maximum ranks, training shows exact capacity deltas, and online Double Dash II is labelled Triple Dash.

Balance updates stay silent and best effort. A fresh run pins capacities with its existing snapshot. Continue restores that snapshot plus exact inventory/recharge state; legacy single-dash/two-grenade saves and 168/209-field balance documents remain valid. Explicit capacity/build disagreement rejects a corrupted save in favor of the existing recovery path. No cloud check gates offline entry.

Online authority owns the purchased ranks, charge spending, replenishment, timers and movement. No member-table migration is needed: inventory stays in the existing fighter JSON and motion acknowledgments. Protocol 4 clients discover `charge_upgrades` before attaching; older clients continue using protocol 3 and cannot receive the new families. Prediction replays the same reserve logic, without authorizing damage or purchases.

Ship updated server, game and admin together. The existing 1.0.0+16 IPA/APK predates these changes; this task does not replace those already distributed artifacts. No new secrets/environment variables are required. Updated admin release build is in the sibling workspace. Physical thumb/readability and balance review remains outstanding.

Validation: game analyzer clean;547 tests pass with5 pre-existing skips. Admin analyzer
clean;27 tests pass, including both capacity fields on390px/1200px screens and
invalid totals. Server107 tests plus module build pass; gateway9 unit tests and
compiled HTTP smoke pass, including the actual balance endpoint defaults. Rendered
evidence: build/test-previews/charge-controls.png and sibling admin
build/previews/dash-capacity-390.png. macOS admin release builds successfully.
Server source pushed to main as0478d3f; live schema now advertises charge_upgrades after automatic deployment.
