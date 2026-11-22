# Regun 1.0.2 — release copy pack

Six copy-paste blocks: website overview, website copy, player changelog, patch notes, and one store template per platform.

---

## 1. WEBSITE OVERVIEW (reference, not for publishing)

The marketing site lives in `../regun-landing-page` and deploys from `dist/` via Netlify (`netlify.toml`). It is a single dark landing page plus four supporting pages.

| Route | Purpose | Current state |
|---|---|---|
| `/` | Hero, download buttons, weapon-spotlight video | **BETA TESTING** badge; says "Currently in beta. The game is still evolving." |
| `/support/` | Help/contact | Live |
| `/privacy/` | Privacy policy + account deletion | Live |
| `/terms/` | Terms, beta availability clause | Live |
| `/thanks/` | Payment return page | Live |

Structure of the home page: wordmark header → hero ("One more **run.**") → three downloads (Play on web → `playregun.kiishi.space`, iOS → App Store `id6749497084`, Android → Firebase App Tester) → muted looping spotlight video with a sound toggle → footer with "Support Regun" (Bachs checkout), Support, Privacy, Terms.

Gaps to fix when Expedition ships: the badge still reads BETA TESTING; nothing on the page mentions Expedition, the 24 weapons, the 10 survivors or the 10 bosses; Android still points at Firebase rather than Play; there is no "What's new" page to host the changelog below.

---

## 2. WEBSITE COPY (paste into the landing page)

### Meta description
```
Regun is a twin-stick survival shooter. Fight procedurally built rooms across four regions, draft a build, break each region's boss, and survive with 24 weapons and 10 survivors.
```

### Hero
```
MOBILE SURVIVAL SHOOTER

One more run.

Survive. Draft. Break the boss. Start over with more.

[Play on web]  [Download for iOS]  [Join Android beta]

Free to play. No ads.
```

### Section — Expedition
```
EXPEDITION

Four regions. One build. No second life.

Every run builds a new route. Clear five to seven sealed rooms, spend the reward behind each door, then face the region's boss. Carry one evolving build from Breach to the Relay Graveyard — or lose it and start again.

Breach → Walker
Foundry → Kiln Sovereign
Floodworks → Last Marshal
Relay Graveyard → Lodestar
```

### Section — Arsenal
```
24 WEAPONS

From the Pump Shotgun to the Mourning Bell.

Every weapon has its own reload, recoil and reason to exist. Twelve original guns, twelve endgame additions, plus incendiary, cryo, arc, rail, mortar and melee flavours.

10 survivors. Each one changes how you actually play, not just your health bar.
```

### Section — Arena and Online
```
ARENA

Classic endless survival. Deep builds, escalating waves, ten-minute cycles.

ONLINE CO-OP

Build a room and fight alongside friends. Server-authoritative, so the boss you see is the boss everyone sees.

TRAINING

Every weapon, every survivor, every boss, unlocked from the start. Practise the fight before it costs you a run.
```

### Section — Progression
```
EARNED, NOT BOUGHT

Scrap is earned by playing. Spend it on survivor styles and cosmetics — never on power. Purchases unlock looks; runs unlock everything else.
```

### FAQ
```
Q: Is Regun pay to win?
A: No. Purchases are cosmetic. Weapons, survivors and upgrades are unlocked by playing.

Q: Does it work offline?
A: Expedition, Arena and Training all run offline. Online co-op needs a connection.

Q: How long is a run?
A: A full Expedition clear runs about 35 to 50 minutes of active play. A run saves at any point, so you can split it across sessions.

Q: Which platforms?
A: iOS, Android, macOS and the web. Desktop builds support keyboard, mouse and controller.

Q: Is there controller support?
A: Yes, on desktop and mobile.
```

---

## 3. CHANGELOG (player-facing running history)

```
REGUN — CHANGELOG

1.0.2 — Expedition
New mode: Expedition. Four regions — Breach, Foundry, Floodworks, Relay Graveyard — with procedurally built routes, sealed combat rooms, two-door reward choices, and an authored boss at the end of each region.
New Expedition boon system: six reward families (Weapon, Ordnance, Ember, Storm, Mobility, Guard) plus Repair, twelve signature effects and nine fusions.
Persistent campaign records: first clear, mastery, deepest region, highest pressure and a discovered-boon collection.
New rooms, doors, staging and region presentation for Breach, Foundry, Floodworks and Relay Graveyard.
Expedition saves at any point; Retry starts a fresh seed with the same kit.
Free Scrap at the start of a new profile, so the shop is reachable immediately.

1.0.1 — Arsenal and platform
Desktop builds: keyboard, mouse and controller support, including menu navigation and control settings.
Scrap store: six Apple packs, owner-bound purchases, retryable claim recovery and wallet sync.
Push notifications and notification preferences.
Arena scenery, hazards and movement audio added to both survival arenas.
New weapon flourishes on dash and reload.
Update and maintenance gates so outdated clients are told, not broken.

1.0.0 — Launch
Twin-stick survival shooter with Arena, Training and Online co-op.
24 weapons, 10 survivors, 4 arenas, 10 bosses, 41 upgrade families, 8 fusions, 20 challenges.
Scrap cosmetics and survivor styles.
```

---

## 4. PATCH NOTES — 1.0.2 (App Store / Play "What's New")

```
EXPEDITION IS HERE

A full roguelite campaign. Four regions, built fresh every run.

• Four regions — Breach, Foundry, Floodworks and Relay Graveyard — each ending in its own boss.
• Sealed combat rooms with procedural layouts, cover and hazards.
• Two doors after every clear. Pick your reward family: Weapon, Ordnance, Ember, Storm, Mobility, Guard or Repair.
• Twelve signature effects and nine fusions to build around.
• One life per attempt. Health and build carry room to room.
• Persistent campaign records: first clear, mastery, deepest region and a boon collection.
• Save and quit at any point, then continue the same run later.

ALSO IN THIS UPDATE

• New rooms, doors and region presentation across all four arenas.
• Free starting Scrap on new profiles.
• Desktop polish: keyboard, mouse and controller throughout menus.
• Bug fixes and stability improvements.
```

---

## 5. iOS — APP STORE TEMPLATE

**Name (30 max)**
```
Regun
```

**Subtitle (30 max)**
```
Twin-stick survival shooter
```

**Promotional text (170 max)**
```
Expedition is here: a four-region roguelite campaign built fresh every run. Draft a build, break each region's boss, and carry it all the way to the Relay Graveyard.
```

**Keywords (100 max, comma separated)**
```
twin stick,roguelite,survival,shooter,bullet hell,pixel,dungeon crawler,offline,co-op,arena
```

**Description (4000 max)**
```
One more run.

Regun is a twin-stick survival shooter about building something strong enough to survive the next room — and losing it anyway.

EXPEDITION
A four-region roguelite campaign. Every run generates a new route of sealed combat rooms. Clear a room, then choose one of two doors: Weapon, Ordnance, Ember, Storm, Mobility, Guard or Repair. Your health and your build carry forward. Your life does not.

• Breach — learn the doors, then survive Walker's mounted guns.
• Foundry — read the vents and break the Kiln Sovereign.
• Floodworks — break sight lines against the Last Marshal.
• Relay Graveyard — crack Lodestar's armour and reach the core.

Two doors, one build, twenty-one to twenty-five rooms, four bosses. Save and quit whenever you like; the run waits.

24 WEAPONS, 10 SURVIVORS
A pump shotgun with shell-by-shell reloads. A rail lance that pierces a crowd. A spore lobber that leaves a field behind. A mourning bell that rings twice. Every weapon has its own cadence, recoil and reload, and every survivor changes how you actually play — not just your health bar.

ARENA
Classic endless survival. Deep upgrade trees, escalating waves and ten-minute cycles, with 41 upgrade families and 8 fusions to break the game open.

ONLINE CO-OP
Build a room and fight alongside friends. Server-authoritative combat means the boss you see is the boss everyone sees.

TRAINING
Every weapon, survivor and boss unlocked from the start. Practise the fight before it costs you a run.

EARNED, NOT BOUGHT
Scrap is earned by playing. Spend it on survivor styles and cosmetics — never on power. Purchases unlock looks. Runs unlock everything else.

• Landscape, offline-capable, reduced-motion friendly.
• Controller support.
• No ads.
```

**What's New (4000 max)**
Use block 4.

---

## 6. ANDROID — GOOGLE PLAY TEMPLATE

**App name (30 max)**
```
Regun: Survival Shooter
```

**Short description (80 max)**
```
Twin-stick survival shooter. Draft a build, break the boss, one more run.
```

**Full description (4000 max)**
```
One more run.

Regun is a twin-stick survival shooter about building something strong enough to survive the next room — and losing it anyway.

EXPEDITION — a four-region roguelite campaign
Every run generates a new route of sealed combat rooms. Clear a room, then choose one of two doors: Weapon, Ordnance, Ember, Storm, Mobility, Guard or Repair. Your health and build carry forward. Your life does not.

• Breach — learn the doors, then survive Walker's mounted guns.
• Foundry — read the vents and break the Kiln Sovereign.
• Floodworks — break sight lines against the Last Marshal.
• Relay Graveyard — crack Lodestar's armour and reach the core.

Twenty-one to twenty-five rooms, four bosses, one build. Save and quit whenever you like; the run waits.

24 WEAPONS, 10 SURVIVORS
A pump shotgun with shell-by-shell reloads. A rail lance that pierces a crowd. A spore lobber that leaves a field behind. A mourning bell that rings twice. Every weapon has its own cadence, recoil and reload, and every survivor changes how you actually play.

ARENA — endless survival
Deep upgrade trees, escalating waves and ten-minute cycles, with 41 upgrade families and 8 fusions to break the game open.

ONLINE CO-OP
Build a room and fight alongside friends. Server-authoritative combat means the boss you see is the boss everyone sees.

TRAINING
Every weapon, survivor and boss unlocked from the start. Practise the fight before it costs you a run.

EARNED, NOT BOUGHT
Scrap is earned by playing. Spend it on survivor styles and cosmetics — never on power.

Free to play. No ads. Controller support. Reduced-motion friendly.
```

**What's new (500 max)**
```
EXPEDITION IS HERE

A four-region roguelite campaign, built fresh every run. Sealed rooms, two doors per clear, twelve signature effects and nine fusions. Breach, Foundry, Floodworks and Relay Graveyard, each ending in its own boss.

Also: new rooms and region presentation, free starting Scrap on new profiles, and desktop controller polish.
```

---

## 7. macOS — MAC APP STORE TEMPLATE

**Name (30 max)**
```
Regun
```

**Subtitle (30 max)**
```
Twin-stick survival shooter
```

**Promotional text (170 max)**
```
Expedition is here: a four-region roguelite campaign built fresh every run, with keyboard, mouse and controller support on Mac.
```

**Description (4000 max)**
```
One more run.

Regun is a twin-stick survival shooter about building something strong enough to survive the next room — and losing it anyway. Built for Mac with keyboard and mouse or a controller.

EXPEDITION
A four-region roguelite campaign. Every run generates a new route of sealed combat rooms. Clear a room, then choose one of two doors: Weapon, Ordnance, Ember, Storm, Mobility, Guard or Repair. Your health and your build carry forward. Your life does not.

• Breach — learn the doors, then survive Walker's mounted guns.
• Foundry — read the vents and break the Kiln Sovereign.
• Floodworks — break sight lines against the Last Marshal.
• Relay Graveyard — crack Lodestar's armour and reach the core.

24 WEAPONS, 10 SURVIVORS
Every weapon has its own cadence, recoil and reload. Every survivor changes how you actually play.

ARENA
Endless survival with 41 upgrade families and 8 fusions.

ONLINE CO-OP
Server-authoritative co-op with friends.

TRAINING
Every weapon, survivor and boss unlocked from the start.

EARNED, NOT BOUGHT
Cosmetics only. No ads.

• Keyboard, mouse or controller.
• Save and resume a run at any point.
• Reduced-motion friendly.
```

**What's New**
Use block 4.

---

## Notes before publishing

1. The landing page still shows a **BETA TESTING** badge and "the game is still evolving". Remove both when this becomes the public release copy.
2. Android still links to Firebase App Tester. Swap to the Play listing before publishing store copy.
3. Store copy promises cosmetic-only purchases — that matches `AppleScrapStore`, but confirm the Play/App Store IAP catalogues are live first.
4. Nothing here was published. `regun-landing-page` is untouched.
