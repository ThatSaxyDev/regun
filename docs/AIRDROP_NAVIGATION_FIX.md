# Airdrop crowd routing correction

24 October 2026. This implements the creator's existing-pod bug report; Sentry
Gun and Aura Farm remain proposals in AIRDROP_EXCLUSIVE_POWERUPS_PLAN.md.

A reproducible 16-body approach left a flanking pursuer behind the pod. The old
router tested only the straight line to the player. A clear straight line could
still leave the enemy's actual flanking heading aimed into a pod face. Routing
also replaced the already-separated movement direction, dropping lateral crowd
avoidance. At crowded corners the preferred body-slide tangent could itself be
blocked by cover, with no attempt at the other legal side.

The router now checks a body-sized lookahead along actual movement as well as
the player route. Native crowd separation runs after the detour. Ordinary swept
body movement tries the opposite tangent when its first side is occupied or
clipped to a negligible step; it uses the same body and cover checks. There is
no teleport or body/cover bypass. Committed attacks do not use this slide path.

Native routing reads registered geometry instead of requiring a supply-pod
argument. Its graph includes corners of adjacent solids and invalidates saved
routes when geometry or the destination changes. RegunGame invokes it for
registered temporary cover, providing the future sentry's integration point.
The sentry must register its planted footprint there; it is not implemented now.

The authoritative server had a stronger version of the crowd jam: ordinary moves
stopped against occupied destinations without native-style body sliding. It now
checks actual heading and uses bounded 12-unit swept steps with legal body slides
and an alternate tangent. Committed movement retains its original straight path.
Server graph corners retain a 14-unit clearance, matching native detour padding.
No damage, supply capture/reward, firing or balance-catalog values change.

Regressions include dense Scorpion/Mummy intent around the actual pod rectangle,
a proposed 70×44 sentry base, and adjacent temporary cover; direct sightline versus
blocked flank; every approach angle; existing fence/contact/cover-removal cases;
and a real mixed 16-enemy native scene. Server tests assert body separation,
cover exclusion and bounded movement alongside completed passage. These proxy
shapes establish reusable navigation behavior, not sentry art/runtime acceptance.

The upgrade title also moves from 8 to 24 logical pixels minimum top clearance.
Existing focused small-screen/large-text checks pass with the footer visible.

[Reproduction and verification evidence](validation/airdrop-navigation-2026-10-24/README.md).
Physical-device pack behavior remains hands-on review. No installation, server
deployment or balance publication was performed.
