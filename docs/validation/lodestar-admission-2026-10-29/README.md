# Lodestar core and full admission —29 October2026

Release **1.0.0+28**, installed on the iPhone (Apple sequence8400). Open Regun
manually; subsequent wireless query/launch attempts timed out. Built Info.plist
confirms1.0.0/build28. Physical play acceptance remains open.

## Play

Training → Start → Pause → Boss Practice → Lodestar. Normal Solo's ten-boss bag,
Training Rush's nine-boss bag and compatible online co-op's nine-boss bag can also
draw it. Lodestar remains a solo mechanical encounter, outside random pairs.
Every co-op client must use the updated capability11 build. Existing Versus rules
stay unchanged; no boss scheduler is introduced into a mode that has none.

Shoot the head first: armor absorbs hits and briefly shows ARMORED. Break any
two of accelerator/mortars/projector/tail; feeder is auxiliary. The plating opens
to an80HP warm core. Head death disarms shots/mines/contact immediately, brakes
the machine and collapses the remaining sections head-to-tail. A connected wreck
holds then fades through4.4 active seconds. Check pause/background, Reduced Motion
and partially buried death. Action descriptions beneath all boss health bars are
removed. Save/Continue preserves local damage and terminal progress; normal rewards
wait for completion and happen once. Training practice grants none.

## Verification

- Clean Flutter analyzer; full suite **973 passed /5 intentional skips**.
- Server typecheck, **216 tests**, module build successful.
- Three generated clients against a disposable local server passed authoritative
  armor/core opening, replicated fatal disarm, retained shutdown and one victory.
- Native tests cover Solo admission, damaged and dying checkpoint recovery,
  complete Rush roster, all24 actual weapon releases, Training recovery, both-floor
  core/wreck pixels, online snapshot-only rendering and pending-load disposal.
- New textures3MiB; selected native kit27.26MiB, below32MiB. This is decoded art
  accounting, not a hardware frame-time or thermal result.

`core-exposed-*` and `shutdown-*` are actual Flutter painter captures on both floors.
The ground masks and connected spine remain shared with authoritative geometry.
`validation.json` records source hashes and results; logs are adjacent.

## Backend rollout

Commit **0516da57de14a96e9cb5b7aadc1c7ecd911a94a3** is pushed to server main and the
remote ref was verified. Public schema now advertises **segmented_bosses**; Online
remains enabled. See `live-api.json`. The client discovers this marker before
attaching capability11; old/mixed rooms retain their supported roster. Private
navigation history stays off public snapshots. No new gameplay input trusts
client health, attack phase, target coordinates or damage.

Test-only reducers and identity bypass exist only in the disposable transport
harness, never the deployed module. Local transport plus the public capability
check does not establish a completed authenticated WAN match or physical fairness,
readability, audio/comfort or performance acceptance.
