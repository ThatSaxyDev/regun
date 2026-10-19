# Regun

A mobile twin-stick survival shooter built with Flutter and Flame.

- [Complete game blueprint](docs/REGUN_COMPLETE_GAME_PLAN.md): product scope, combat, builds, bosses, mobile controls, presentation, milestones, and release gates.
- [Implementation progress](docs/REGUN_PROGRESS.md): completed work, verification evidence, and remaining audit findings.
- [Initial assessment](docs/REGUN_REVIEW.md): historical review and research.

- [Full testing breakdown](docs/REGUN_TESTING_AND_REVIEW.md): every implemented system, practical test sessions, known shortcomings, and improvement priorities.
- [Collection system guide](docs/COLLECTION_SYSTEM_GUIDE.md): what each tab does, why players visit, temporary versus permanent progression, all recipes/unlocks/styles, and current clarity gaps.
- [Playtest guide](docs/PLAYTEST_GUIDE.md): how to try all weapons, characters, bosses and fusions, plus the physical-device acceptance checklist.
- [Asset and creator review](docs/ASSET_REVIEW.md): provenance, presentation approval and distribution requirements.

The full functional-content build is available for mobile testing. Training exposes the entire roster without changing normal progression. Physical performance, interruption handling, comfort and balance remain device acceptance gates; see the current progress log for measured evidence.

Use `make verify`, `make soak`, `make buildAPK`, and `make buildIOS`. Local Android candidates use debug signing until an upload keystore is configured.

- [Sprite and arena art overhaul plan](docs/REGUN_ART_OVERHAUL_PLAN.md): proposed visual direction, full asset roster, animation/weapon pipeline, map authoring, production phases and acceptance gates.

- [Art overhaul implementation and phone review](docs/art/ART_OVERHAUL_PROGRESS.md): replaced roster, screenshots, geometry changes, measured texture budget and remaining gates.
- [Art bible](docs/art/ART_BIBLE.md): the implemented quarantine-facility direction and asset pipeline.

- [Monetization, SpacetimeDB backend and multiplayer plan](docs/REGUN_MONETIZATION_AND_BACKEND_PLAN.md): code audit, competitor/store research, product catalog, purchase architecture and implementation gates.
- [Five-boss expansion plan](docs/REGUN_BOSS_EXPANSION_PLAN.md): distinct new encounter concepts, fair difficulty, the path toward fifteen bosses and future paired fights.
