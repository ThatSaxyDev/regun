# Boss recovery, grenade pressure and solid supply pods

23 October 2026. Local implementation; no build-number change, device installation
or server deployment performed by this task.

Each actual boss death grants two current HP, including beyond maximum health.
Maximum health itself stays unchanged. The existing exactly-once death path owns
this reward; retiring a practice boss never grants it. Normal capped healing and
Salvage cannot reduce overflow HP. Checkpoints now accept bounded overflow and
Continue neither repeats the reward nor replays the victory notice. Online co-op
grants the two HP to every living, connected teammate; it does not revive downed
players. Existing boss cores, XP, score and encounter progression remain intact.

A brief charcoal/olive and brass pixel plate reads the boss name, VANQUISHED and
+2 HEALTH. It ignores pointers and does not pause combat. Native notices queue for
pairs and expire after2.8 active seconds; pause and upgrade selection freeze them.
Reduced Motion uses the same still plate. Online uses a server scene event.

Grenades pass over enemies without detonating on contact. The existing vertical
arc hits the ground at roughly one second, bounces, then detonates once when its
1.4-second release fuse expires. Walls/pods still bounce the casing; the damage,
throw speed, power range and charge/recharge contracts are unchanged. The native
preview and server simulation agree. Saved flights retain their existing vertical
state. Legacy online servers retain contact-aware preview until the new
`ground_ordnance` capability is present; new servers own the revised behavior.

Grenade damage retains its existing205-unit base radius and upgrades. A separate
130-unit outer pressure band deals no damage. It pushes ordinary movable enemies
with distance falloff, existing mass resistance, stagger recovery, body occupancy
and cover constraints. Base full reaction is140 units over.32s (previously86/.25s),
with.18s stagger. Blast Harness still scales native grenade/mine force. Bosses,
nests and sentinels stay planted. No pressure-only hit earns damage or primary procs.

A supply pod still crushes ordinary enemies in its62-unit center and deals3% of
maximum boss health there. Landing now adds an8-damage/205-radius blast and the
same pressure band, without Fragmentation shards, player damage or ammo cost.
The phase transition remains the once-only trigger; restoring an active pod
cannot repeat it. Capture remains260 units/eight seconds with50-second expiry.

Active/opened pods have a92×52 footprint anchored at their painted base. They block
player/enemy walking and dashes, shot/cover sight and grenade paths. A player
beneath a friendly landing is moved to the nearest footprint edge without damage.
The footprint disappears when breakdown starts, and is derived from saved phase,
not an extra obstacle persisted independently. Online movement, enemy world,
projectiles and client prediction use the same footprint. Breach's original
removed pillars remain absent; Foundry's authored obstacles are unchanged.

Ground presentation now lives in world floor siblings, separate from actor depth:
Queen/Demon/Shadow warnings, all boss arrival stamps/contact shadows, ordinary
enemy shadows, survivor shadows/deployment dust, grenade shadows/aim guide,
corpses, cosmetic foot trails and recovery pulses. Existing hostile floor attacks,
burning ground, capture fields and arsenal floor overlays retain floor priority.
The pod body remains depth sorted; aerial shots, muzzle effects and the explicitly
requested Marshal laser keep their aerial presentation. Online separates pod body
from its capture field and renders shadows/spawn cues/remains before living actors.

Native physical force, pod corner comfort, grenade placement, health reward
balance and VFX readability still need creator playtesting. Automated results do
not establish device performance or physical acceptance.

## Verification

Game `make verify`: analyzer clean,562 tests passed with five existing optional
skips. After the final render and online-dust ordering pass,25 focused online/
recovery tests passed; the checkpoint/Continue subset also passed10 tests. Server
`npm run verify`:112 tests passed and module build succeeded. `git diff --check`
passes in both repositories. Rendered and inspected the narrow large-text victory
plate and actual Queen/pod scene in build/test-previews/boss-vanquished.png and
queen-ground-layers.png. No physical-device acceptance or live deployment is claimed.
