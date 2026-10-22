# Boss attack geometry candidate — 22 October 2026

The creator rejected the boss attack sprite treatment, particularly the arc
warning. Large scaled rubble stamps lose their source texture scale and cover
the floor; tiny stamps repeated around an arc read as a detached particle border.
The first geometric draft was also rejected during internal review: radial
triangles made the sector look like a pie diagram.

The candidate now in the app uses `BossVfx`: deterministic pixel-stepped cuts,
broken crescent seams, small fractured facets and dark contact backing. It does
not load textures or allocate particle components. Warning geometry is visible
from commitment, remains planted and gains contrast without changing position.
The floor remains visible. Moving waves retain contrast through the final active
frame. Reduced Motion has no decorative movement; the authoritative sweep/wave
still moves so its real damage location remains readable.

| Boss | Candidate treatment |
| --- | --- |
| Shadow | Muted rose/charcoal faults and broken dash lanes |
| Demon | Oxidized ember cleave footprint and layered fractured impact |
| Scorpion Queen | Olive broken seep boundary, angular pools and floor cuts |
| Bellkeeper | Dull brass crescent faults; inner pocket and moving wave gap retained |
| Magistrate | Committed cut lanes, polygon iron links and barbed end anchors |
| Mirror Saint | Cool mineral fissures and narrow faceted glass |
| Kiln Sovereign | Warm slag faults and broken vent/sweep footprints |
| Last Marshal | Existing continuous laser preserved; geometric brace and blade lanes |

Native boss actors, owned floor areas/impacts, expansion attacks and mirror/clasp
weak points use the candidate. Online boss-owned hazard snapshots select the
same renderer using the owner's boss kind. Normal-enemy warnings, weapon and
ordnance effects keep their existing rendering. Far-away boss origins do not
hide a wave/line crossing the viewport.

Collision, committed angles/points, warning/active durations, damage, encounter
coordination and cover contracts are unchanged. No backend changes or additional
network checks are required. No new image memory is added.

## Review artifacts

`flutter test --no-pub test/boss_geometry_vfx_test.dart` exports:

- `build/test-previews/boss-geometry-breach.png`
- `build/test-previews/boss-geometry-foundry.png`

Each row shows old warning/impact material beside candidate warning/impact
material at the same scale with actual boss artwork and arena floors. These are
material studies, not a reproduction of every attack's full timeline (a sweep
only damages along its moving leading edge). The actual sweep renderer uses
that moving line, not a permanently damaging filled sector.

Focused pixel checks verify the annular safe pocket/outside sector stay clear
and that a late damaging wave does not fade away. Existing boss tests exercise
collision/timing and escape contracts. Automated checks and these images do not
establish native comfort, performance, difficulty or creator visual acceptance.
This is a review candidate; no phone installation or version bump was requested.
