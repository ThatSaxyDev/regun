# Combat visibility and hurtbox validation — 25 October 2026

| Check | Result | Evidence |
|---|---|---|
| Game analyzer/full suite | Clean; 716 passed, five existing opt-in skips | [Final log](mobile-verify.txt) |
| Visibility, hurt geometry, field boundaries and supply coverage | 23 passed | [Focused log](focused-visibility.txt) |
| Hostile contact plus existing weapon/supply checks | 18 passed | [Contact log](focused-contact.txt) |
| Final actual swept and Scorpion cardinal boundary test | Passed | [Boundary log](swept-and-contact-boundaries.txt) |
| Server typecheck/tests/module build | 155 passed; built | [Server log](server-verify.txt) |
| iOS release | Built, 177.0 MB | [Build log](ios-build.txt) |
| Android release | Built, 228.9 MB | [Build log](android-build.txt) |

Release identity remains 1.0.0+21. No installation, hosted deployment or balance
publication was performed. Shotgun values/catalogue/live configuration were not
edited or regenerated.

Actual rendered game scenes, using shipped art and fonts:

- [Paired compact boss strips and accepted hit](compact-boss-hurt.png)
- [Single health-loss HUD/survivor cue](player-damage.png)

Both boss identities remain accessible; names ellipsise on small screens rather
than making larger plates. Paired 568×320 strips pass at default and 2× text.
The hurt-radius fixture is byte-identical between native/server. Native and
hosted 400-unit hostile sweeps agree on the same close hit and graze cases;
Scorpion contact above/beside the player also agrees. Movement radius stays30.

An initial full run hit the pre-existing random Training placement timing check
(no arrivals within its one-second window). [Initial failure](initial-training-timing-failure.txt)
is retained; [all six Training checks passed on recheck](training-recheck.txt),
and the final complete suite then passed without changing the arrival test.
The separate supply-pack fixture now leaves room beyond the pod for16 bodies
rather than demanding they compress into a small gathering area; its cover and
committed movement assertions remain.

[Implementation and phone review](../../COMBAT_VISIBILITY_AND_HURTBOX.md).
Automated/rendered checks do not establish physical feel, readability or device
performance. Matching server deployment is required for the hosted geometry.
