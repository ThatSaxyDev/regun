# Weapon feedback validation — 24 October 2026

Local source verification and release builds for game 1.0.0+21. No installation,
deployment or balance publication was performed. Native listening, comfort and
physical performance remain hands-on review.

| Check | Result | Evidence |
|---|---|---|
| Game analyzer and tests | Clean; 706 passed, 5 opt-in skips | [Log](mobile-verify.txt) |
| Admin analyzer and tests | Clean; 49 passed | [Log](admin-verify.txt) |
| Server typecheck/tests/module build | 149 passed; build passed | [Log](server-verify.txt) |
| Gateway typecheck/tests/build/compiled smoke | 22 tests + 1 smoke passed | [Log](gateway-verify.txt) |
| Rank parity | 43 families, 238560 transitions, 2040 shared samples | [Audit](rank-audit.txt) |
| Game Android release | APK built, 228.8 MB | [Log](game-android-build.txt) |
| Game iOS release | Runner.app built, 177.0 MB | [Log](game-ios-build.txt) |
| Admin macOS release | Built, 47.4 MB | [Log](admin-macos-build.txt) |
| Admin iOS release | Built, 19.7 MB | [Log](admin-ios-build.txt) |

Catalog: 24 weapons, 314 numeric fields, ID
`928d79fb30d90d1bd957a691cbfc99cecf10cdc7fd7088c1dc748c629a8ce51b`.

Focused coverage includes intrinsic Revolver bounce without an upgrade, bought
rank stacking and configurable zero/two bounces; rocket acceleration, off-axis
guidance and equal near/far damage; orb swept crossings and saved hit ledgers;
muzzle-based ring launch, return and legacy saves; selected texture cleanup;
bounded hit/flight audio; and picker layouts at 844×390 with text scale 1/1.5/2
and 568×320 at default text size. Default cards and Ban buttons fit; larger-text
body content scrolls while Reroll remains visible and operable.

These are actual rendered game/admin frames, not concept mockups:

- [Power-up picker](power-up-menu.png)
- [Wide admin Revolver header and innate stat](admin-revolver-wide.png)
- Ring: [launch](ring-launch.png), [opening](ring-opening.png),
  [fully open](ring-open.png), [recall](ring-recall.png)
- [Houndrack](houndrack.png), [Storm Orb](stormOrb.png)

[Listen to the 10-second rocket/orb mix](frontier-feedback.wav).
The 11 corrected/new WAVs passed PCM16 mono 44100 Hz, peak/DC/end-point checks;
review mix peak 0.4240 at native event gains and 0.8 SFX volume.
All 148 expansion cues also passed; expansion mix peak 0.6483.
[Frontier metrics](frontier-audio.csv), [expansion metrics](expansion-audio.csv).
This is an offline event mix, not a recording of a physical device speaker.

See [implementation contracts](../../WEAPON_FEEDBACK_REVIEW.md) and
[audio provenance/levels](../../art/FRONTIER_AUDIO_REVIEW.md).
