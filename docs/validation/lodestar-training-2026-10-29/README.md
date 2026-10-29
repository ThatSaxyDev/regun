# Complete Lodestar Training candidate —29 October2026

Release **1.0.0+28**. Creator explicitly wanted a fight inside normal Training and
asked to test it before normal-run admission. The earlier construction inspector
is optional developer tooling; it is not the delivered player workflow.

## Play it

Home → **Training → Start → Pause → Boss Practice → Lodestar**.
Use normal movement, aim/fire, dash, reload and grenade controls. Enable Take damage
under Survival practice when ready; Off remains protected practice. Boss Practice
also exposes All attacks and the six attack-family selectors during this trial.
Fight again replays it. Pause → Restart preserves the trial/visit settings.

## Delivered

- One connected six-section war serpent, local200 integrity and permanent disabling
  of each ruined section's equipment/contact. The structural spine remains.
- Boring jaws, shard accelerator, rotating twin siege mortars, physical feeder,
  strategic launched proximity mines and anatomically constrained tail sweep.
- Feeder loss trims unreleased/future mortar volleys to one; mortar loss cancels
  unreleased shells. Emitted shells/mines retain finite lifetimes. Whole defeat
  disarms all owned threats and completes without grinding the auxiliary feeder.
- Fixed120Hz arc-length following, constrained couplings, full-body ground
  occupancy and cover/self rejection. Reverse follows validated history and can
  branch into a new legal forward bend. No enclosing damage/occupancy circle over
  the empty space inside a bend.
- Offscreen equipment cannot start targeted attacks. Forward interception and
 1.6-second body lookahead keep moving-player pressure without increasing speed.
- One major sequence, finite capacities, walking-escape checks, committed shell
  targets/exit warnings and moving quiet recovery. Mines fly, arm, trigger once,
  can be shot harmlessly and expire. Mortar tube recoil is independent per barrel.
- Sequential head-led entry/emergence with the same ground-mask half-plane used by
  target/contact queries; exposed head destruction withdraws safely. Buried defeat
  collapses harmlessly rather than releasing a final surprise eruption.
- One projectile/proc owner, swept first living section and cumulative contact
  distance. Blasts distribute one damage budget across exposed intersected parts.
- Arrival, Training health loss/redeployment, pause/background/upgrade holds,
  Reduced Motion, restart/replay, boss replacement and pending-load retirement.
- Separate section depth layers, material floor effects and visible airborne
  impact cores; original modular source art, two small combat decodes, shared
  floors and existing SoLoud gains/mute/lifecycle.

## Evidence and limits

`arsenal-*`, `mortar-flight-*`, `burrow-mask-*`, `local-wrecks-*` are actual Flutter
renderer captures on both floors. `native-fight.png` comes from RegunGame, not the
concept sheet. `art-budget.json` measures decoded art with the selected native kit.
`foundry-pressure.json` records the actual native30-second continuous-movement
scenario, eligible moving frames, phases and real releases. It is not a frame-time
benchmark or a physical difficulty result.

Tests include local damage/one-budget blasts/ruined gaps,30/60/120Hz following,
reverse branching, self/cover/player sweeps, local release cancellation, mine
capacity/arming/trigger/disarm/expiry, committed exit/mask, safe interrupted entry,
buried defeat, phase-two movement, real Training selector/contact/recovery/replay,
all24 actual weapon releases, restart during pending load, and real Foundry cover
pursuit. Presentation checks assert actual visible impact pixels and both floors.
Final automated verification: `make verify` passed with a clean analyzer,
**968 passed /5 intentional skips**. The earlier startup test assumed image I/O
would finish in100ms under concurrent rendering; the helper now waits for its
actual ready logo while keeping the stalled-policy assertions. The final full
suite passes. `validation.json` records source hashes and commands.

The native kit uses3MiB of new boss textures and27.26MiB combined decoded art,
within32MiB. The30-second Foundry case had523/523 eligible navigation/recovery
frames above40 units/s, three real mortar releases and three jaw sequences.
This is scenario evidence, not universal balance or hardware performance proof.
## iPhone installation

`make buildIOS` built/signed the normal main entry point successfully (Xcode30.9s).
Apple installation succeeded, sequence**8392**. A fresh device app query confirms
**Regun1.0.0 / build28**. Logs: `device-install.json`, `device-app.json`.

Automatic launch first lost the wireless device connection; the retry was denied
because the iPhone is locked (`device-launch-retry.json`). Installation is complete.
Unlock the phone and open Regun, then Training → Start → Pause → Boss Practice →
Lodestar. No distribution upload or version increment was performed.


Lodestar remains outside BossKind, normal Solo, random Rush and online/server
admission. Training awards no profile victory/core/XP. The creator still needs to
review physical articulation, warnings, fairness, audio, comfort and sustained
performance on the phone. Automated success/installation do not establish those.


## Superseded after creator review

The later approved armored80HP core, connected shutdown and Solo/Rush/co-op
admission supersede this historical candidate. See
[the admitted candidate](../lodestar-admission-2026-10-29/README.md).
