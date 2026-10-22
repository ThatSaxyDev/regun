# Dash and lighter combat cues — 21 October 2026

Requested by the creator after player reports: full-dash immunity, a modest grounded
visual, lighter Skitter and boss arc warnings, and correctly attached Marshal lasers.
Version remains 1.0.0+10. No new controls/settings or release export.

## Rules

All native damage continues through the shared gate. Base protection now covers the
whole `sprintTimeDistance`; active movement is independently protected against
component/notifier update ordering. The upgrade adds 70ms recovery plus the existing
15ms per later rank. Pause freezes the notifier timer. No guard consumption, HP loss,
hurt audio or damage feedback occurs for an avoided hit. Protection ends normally;
lingering hazards can hurt after the dash. Collision with bodies/cover is unchanged.

Server legacy and queued dash input both use the same protection duration. The grant
includes the current 50ms step because `advanceGun` decrements before damage checks.
An epsilon avoids an extra tick from floating-point residue. All server damage paths
continue to respect protection; clients never grant immunity themselves.

## Presentation

New transparent `effects/ground_motion` atlas: sparse ground scrapes and two modest
dust stages. Native dust is planted at sampled feet, bounded by the existing effect
budget, with one puff under Reduced Motion. It ages on simulation time and freezes
on pause. Online uses a bounded short cosmetic wake and one local foot cue under
Reduced Motion. No afterimage, camera shake, flashing or additional damage effects.

Skitter keeps committed heading, .75s warning and all fairness rules. Thin textured
scrapes replace six heavy outlined claws per section. Initial visibility is tested
on both floor colors; expected coverage is deliberately lower than the former art.
Boss sectors use sparse clipped scuffs and smaller/lower existing material stamps.
Annular safe pockets and all authoritative warning/active geometry stay intact.
Chains, explosion bursts and circles retain their existing material identities.

Marshal uses a separated planted body and articulated gun from
`effects/marshal_aim`. The gun hand, barrel rotation and authoritative laser source
share `MarshalAim` / backend `marshalMuzzle` geometry. Every delayed shot has its own
muzzle; counter uses the same rule. Native selects the next still-living owned beam,
so death/removal/pause cannot leave a detached beam pose. Online associates beams
by owner, selects the next valid cue and only enables articulation for additive
`muzzleProtocol:2` hazards. Old servers retain the old held-pose rendering until the
matching backend deploys. The continuous beam is clipped to its authored segment;
filaments never extend through its endpoint. Damage width, duration and cover checks
are preserved. This is not homing: the target/geometry remains committed.

## Asset provenance

Generated with the built-in image-generation tool on 21 October 2026. Ground-motion
atlas is original; articulated Marshal references the existing approved Marshal
sheet. The original atlas remains unchanged. Generated RGBA files are copied without
image edits; alpha bounds are measured only for manifest metadata. Decode widths
192/256, with expansion-boss atlases decoded at576 instead of640, keep the shared/pair art budget intact. The authored source images and full frame bounds remain unchanged. Paths:

- `assets/art/effects/ground_motion.png`
- `assets/art/effects/marshal_aim.png`

Preview: `build/test-previews/combat-readability.png`. An initial runtime crop of the
old gun exposed overlapping source cells and was discarded before acceptance. The
separated sprites preserve a complete body across angled shots.

## Acceptance

Automated checks cover full-duration immunity, expiry/pause, multiple native damage
causes, eight mirrored muzzle directions, initial warning contrast, full boss
lifecycle/escape tests and the 32MiB texture ceiling. These are not physical feel,
comfort or balance approval. Review a dash across Magistrate chains and Marshal
fire, residual ground hazards after landing, crowded warnings and both arenas.
The online rule/source changes require deployment. No production rollout is included
while the outstanding guest-persistence mount inspection remains unresolved.
