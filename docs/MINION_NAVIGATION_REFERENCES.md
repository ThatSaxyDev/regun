# Minion navigation: external references and renewed implementation baseline

Research rechecked 2 November 2026. These are primary developer/engine sources,
not evidence that Regun's movement has been fixed. Raw search/extraction results
are in ignored `.firecrawl/navigation-recheck-*-2026-11-02.*` files.

## What other developers actually describe

| Source | Published approach | Relevance to Regun |
|---|---|---|
| [Elijah Emerson, Supreme Commander 2 / Game AI Pro, chapter 23](http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter23_Crowd_Pathfinding_and_Steering_Using_Flow_Field_Tiles.pdf), especially §23.12 | Shared tiled flow fields provide route directions for hundreds or thousands of units. Steering, line-of-sight shortcuts and collision response remain additional work. | A flow field is a possible shared route layer if profiling warrants it. It does not by itself resolve mummies competing for the same occupied destination. |
| [Epic, Using Avoidance With the Navigation System](https://dev.epicgames.com/documentation/unreal-engine/using-avoidance-with-the-navigation-system-in-unreal-engine) | RVO reasons about relative agent velocities. Detour Crowd uses adaptive velocity sampling with directional bias and corridor optimization. Epic warns that RVO alone can leave navigable bounds. | Evaluate future collision before contact; score several legal velocities. Retain cover routing and hard swept collision. This is engine guidance, not a claim about a particular shipped Unreal game's configuration. |
| [Epic, DetourCrowd Avoidance for Non-Detour Controlled Agents](https://dev.epicgames.com/community/learning/knowledge-base/qX23/unreal-engine-detourcrowd-avoidance-for-non-detour-controlled-agents) | Agents outside the normal crowd controller need explicit representation for Detour agents to avoid them. | Include bosses, planted attackers and reservations deliberately. An actor's absence from the steering set must not make its body disappear. |
| [Godot, Using NavigationAgents](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html), Pathfollowing common problems and NavigationAgent Avoidance | Pathfollowing and RVO avoidance are separate. Avoidance has no knowledge of physics collision or the navigation mesh. Frequent path updates can produce alternating/dancing motion; long prediction horizons can over-brake. | Keep navigation, avoidance and final placement separate; use stable bypass commitments and bounded replanning. Measure horizons rather than assuming more anticipation is always better. |
| [Valve, Replayable Cooperative Game Design: Left 4 Dead, GDC 2009](https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ReplayableCooperativeGameDesign_Left4Dead.pdf), Procedurally Populated Environment / Robust AI Actors | Navigation areas support spatial reasoning and an active area set for the Director. Robust actor behavior is a separate requirement from population direction. | Encounter admission and actor navigation solve different problems. Regun should retain its population budget while fixing individual movement. This presentation does not establish Left 4 Dead's exact local collision solver. |

The Regun applications in the last column are engineering inferences. None of
these sources diagnoses our particular mixed-pack bug. The older standalone
Godot `navigation_using_agent_avoidance.html` stable URL now returns a 404; use the
NavigationAgents chapter above instead.

## Decision for this game

Retain the plan's **role goal → bounded velocity selection → swept occupancy**
pipeline. Start with the smaller change appropriate to the current encounter
budget; profile before introducing global flow-field infrastructure. A custom
sampled solver must not be described as an ORCA implementation or assigned its
mathematical guarantees.

1. Give each mobile role an achievable goal. Detect sustained lack of useful
   progress and choose a reachable bypass or temporary approach opportunity.
   Maintain its side long enough to execute. Fixed attack rings and random
   per-frame nudges could create new formations or jitter.
2. Plan from an immutable position/achieved-velocity frame. Sample a bounded set
   of velocities, including braking and stopping, against relative swept contact
   risk, progress and turn continuity. Commit through live occupancy in a stable
   simulation order independent of sprite depth, with bounded waiting fairness.
3. Treat bosses through current grounded geometry and committed motion. Include
   all grounded bosses, Lodestar's clipped sections and retained wrecks. Airborne
   phases, immobile casts and released leaps retain their authored contracts.
   The current fixed front rectangle cannot represent these differences.
4. Route on static and temporary obstruction consistently. A safe local velocity
   does not prove a complete route, and a route does not authorize body overlap.
5. Preserve role attacks and measure actual threat. A minion that avoids everyone
   indefinitely without reaching a usable attack is still failing. Drive gait
   from accepted displacement so blocked actors do not walk in synchrony.

## Work required before calling the replacement successful

Use the existing [implementation plan](MINION_NAVIGATION_IMPLEMENTATION_PLAN.md)
for ordering and detailed gates. Extend its fixtures with head-on/crossing traffic,
overtaking a slower body, stationary attackers, all approach angles, invalidated
bypasses and stationary/moving/compound bosses. Check for oscillation and
over-braking as well as overlap. Retain the 36-mummy/one-scorpion real-component
scene, normal melee/contact assertions, save/restart/pause checks and native/server
shared golden decisions. A pure steering fixture cannot validate Flame update
ownership or real authoritative co-op integration.

Measure useful progress and persistent close-packed neighbor relationships across
seeds and timing schedules. Parallel pursuit alone is expected. Record legitimate
attack holds separately from avoidable stalls; do not relabel jams as holds to
pass. Profile the full admitted crowd and compound bosses on devices; laptop
microbenchmarks cannot establish a phone frame-time budget.

## Historical checkout audit on 2 November 2026

The candidate was recovered and retested on 3 November. See the
[candidate record](validation/minion-navigation-2026-11-03/README.md).

- Client HEAD is `0c083af` (Lodestar correction). The plan and original
  investigation exist; `lib/systems/minion_navigation.dart` and the replacement
  integration tests do not. Current `moveActor` still uses the first-boss corridor,
  the temporary-cover gate and force-sum spacing.
- Backend HEAD is `03218af`, which explicitly reverts navigation commit
  `269c9fa`, based on Lodestar revision `3530aa1`. The reverted implementation is
  available for review, but is not the current backend. Its tests cannot certify
  the reverted tree.
- Earlier session notes mention candidate tests, soak results and captures, but
  the candidate client files and referenced `/tmp` logs are absent here. Do not
  carry those pass counts forward as current validation or silently undo the
  explicit backend revert.
- Existing staged release/orientation changes (including source build 30) are
  separate from this research. This pass leaves them intact and makes no release,
  deployment or physical-acceptance claim.

Re-establish an actual paired source baseline and rerun verification when
implementation resumes. The old plan's hashes and pass counts remain historical
evidence, not the renewed candidate's identity.
