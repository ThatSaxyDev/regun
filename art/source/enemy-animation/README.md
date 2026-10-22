# Mummy walking cycle — 22 October 2026

Generated using the built-in imagegen tool with `assets/art/enemies/mummy.png`
as the character reference. The output is the packaged master
`assets/art/enemies/mummy_walk.png` (eight poses,4×2,transparent alpha).
The original attack/hurt/death atlas remains intact.

Direction: preserve the gray bandages, gas mask, harness, heavy boots and existing
three-quarter right-facing silhouette. Author a heavy contact/down/passing/up
stride with its opposing half; keep scale and pelvis steady, no camera turn,
background, attack poses or image stretching. Left playback mirrors the same
sequence. Runtime distance advances each pose, preserving phase through turns.

`python3 tool/register_mummy_walk.py` measures the atlas alpha and updates only
its manifest entry. It never edits pixels. Pelvis registration excludes swinging
hands/feet; the reference height preserves the old walking body scale. The atlas
is decoded once at640px wide and shared by all native/online Mummies.

SHA-256: `0e26ee2b76430547f0e5bda56e4c676e2bea195ff1abf559b76ead391803fad9`

Review artifact: `build/test-previews/mummy-walk-both-directions.png` renders
actual registered runtime sprites at120-unit scale. Physical motion/readability
and sustained device performance remain hands-on acceptance.

The creator rejected the first candidate: its legs only opened/closed without
proper passing steps. The replacement is conditioned on the explicit near/far
leg guide `art/source/gait-guides/mummy-eight-step-guide.png`. Frames3 and7 have
separate raised-boot/bent-knee passing poses; frames1 and5 trade contact legs,
and frame8 lowers the leading heel toward the next contact. Depth shading keeps
the near leg in front of the weight-bearing far leg in the second half.

Regenerate the authoring guide with:
`flutter test --dart-define=REGUN_GAIT_GUIDE=true --dart-define=REGUN_GAIT_GUIDE_MUMMY=true test/gait_guide_test.dart`.
Render the runtime motion frames with:
`flutter test --dart-define=REGUN_MUMMY_VIDEO=true test/mummy_walk_test.dart`.
The current review clip is `build/test-previews/mummy-walk-corrected.mp4`.
