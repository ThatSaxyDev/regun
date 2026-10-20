# Regun Collection: what it does and why players would use it

Reviewed against the current implementation on **19 October 2026**. This describes the game that exists now. Recommendations are explicitly separated from implemented behaviour. This document changes no gameplay or progression rules.

## 1. What Collection is supposed to be

Collection is the player's **guidebook, progress record and cosmetic wardrobe** between runs.

A player should visit it to answer four questions:

1. **What should I try next?** Learn an upgrade combination or identify an unlock to pursue.
2. **How do I deal with that enemy?** Read its role and counterplay.
3. **What have I achieved?** Check completed challenges and recorded discoveries.
4. **What can I do with my scrap?** Buy a cosmetic and equip a look.

It does not currently let players buy permanent damage, craft a fusion outside a run, select their starting upgrades, or choose their survivor/weapon/arena. Starting equipment belongs in **Play → Loadout**; Training lets players try the roster without normal unlock restrictions.

The intent is useful. The current presentation is confusing because all six tabs look equally interactive even though most are just reading material. There is also no overview telling the player what this place is for.

## 2. A map of the six tabs

| Tab | Why a player visits | What the player can do now | What carries into the next run |
|---|---|---|---|
| **Upgrades** | Understand the choices offered while levelling up | Read all 30 upgrade descriptions and rank limits | Knowledge only; the upgrades must be earned again during each run |
| **Fusions** | Plan a combination before fighting bosses | Read six recipes and see which were recorded as discovered | Discovery marks remain; the fusion's combat effect does not |
| **Enemies** | Understand a threat and how to react | Read eight enemy roles and three bosses; see ordinary-enemy encounter marks | Recorded encounter marks |
| **Challenges** | Find the next goal and understand its reward | Read 20 goals, check completion, and see a few numeric counters | Completed goals, lifetime counters and their permanent unlocks |
| **Style** | Spend earned scrap and change appearance | Preview, buy and equip cosmetics | Owned styles and the selected style |
| **Credits** | See creation/technology acknowledgements | Read project information | Nothing to unlock |

**Only Style contains purchase/equip actions.** The other Collection cards are informational. Challenges complete automatically; there is no Claim button.

## 3. Two kinds of progression that must not be confused

### During a run: temporary build progression

Kill enemies → collect XP → level up → choose upgrades → combine suitable upgrades through a boss core.

These choices make that particular attempt stronger. A fresh run starts a fresh build. Continuing a saved run resumes that build.

### Between runs: persistent profile progression

Finish a normal attempt → receive scrap and record achievements → unlock more loadout choices or appearances → try another build.

Persistent profile data includes scrap, owned/equipped styles, challenge completion, fusion discoveries, encountered enemies, lifetime kill counters, best records and cycle completions by weapon/survivor.

**XP pickups, score and scrap are different things:**

- **XP:** levels you up in the current run. The pickups on the floor are not the shop currency.
- **Score:** measures the run's performance. It cannot be spent.
- **Scrap:** is banked between runs and can currently buy three cosmetic palettes.
- **Boss cores:** create an in-run upgrade/fusion choice. They are not a persistent wallet or a Collection crafting currency.

## 4. Upgrades: a build reference, not an upgrade shop

### What players should expect

“I saw a choice called Static Charge. What does it do, and what might work with it?”

The tab lists all 30 standard upgrade families immediately. Players do not need to discover or purchase them to read them. Each card shows the upgrade name, its group, maximum ranks and a short effect description.

**Rank** means how many times the same upgrade has been selected during the current run. Most have three ranks. Afterimage has one. For example, selecting Hot Shot three times gives Hot Shot rank 3 for that run.

The displayed rank limit is not an owned inventory count. The Collection card does not show the current run's rank or let the player apply it.

### The groups

| Group | Role | Included upgrades |
|---|---|---|
| **Core** — 8 | Improve the gun's basic performance | Heavy Load, Quick Trigger, Extended Tube, Sleight of Hand, Scattershot, Piercing Rounds, Long Barrel, High Velocity |
| **Utility** — 8 | Help survival, movement and progression | Fleet Foot, Vitality, Field Medic, Scrap Armour, Quickstep, Afterimage, Scavenger, Lucky Find |
| **Special** — 14 | Build distinctive offensive combinations | Hot Shot, Accelerant, Static Charge, Conductive Core, Dash Mine, Fragmentation, Ricochet, Bank Shot, Last Shell, Breach Loader, Orbit Drone, Targeting Link, Shrapnel, Executioner |

A run can take **six different Special upgrade families**. Further ranks in already selected families remain possible, subject to their limits. Core and Utility upgrades do not consume these six Special slots. A fusion does not remove its ingredients or free their slots.

Level-ups roll up to three choices from the eligible pool. The player normally starts with two rerolls and one ban for the run. Collection does not choose these offers or increase those allowances. Some upgrades stop being offered early when their practical stat limit is reached.

**Scrap Cache** is a fallback offer: it grants five run scrap and restores a heart up to the health limit. It is not one of the 30 standard Collection families. The legacy Long Dash upgrade is also excluded from this tab.

### Why return here?

To compare effects before a run or understand an unfamiliar choice. At present it has little reason for repeat visits once a player knows the upgrades: there are no favourites, search, grouping controls, linked recipe details or personal upgrade discovery records.

## 5. Fusions: recipes for a run, not permanent equipment

### What a recipe means

**Hot Shot 3 + Accelerant 2** means:

- Reach Hot Shot **rank 3** during the run.
- Reach Accelerant **rank 2** during that same run.
- Defeat a boss to receive a core choice.
- Select **Firebreak** from that choice if it is eligible.

The numbers are upgrade ranks. They are not scrap prices, levels, quantities of inventory items or numbers of boss kills.

### All six recipes

| Fusion | Required ranks in the current run | Result |
|---|---|---|
| **Firebreak** | Hot Shot 3 + Accelerant 2 | Burning enemy deaths can leave burning ground |
| **Storm Circuit** | Static Charge 3 + Conductive Core 2 | Adds two targets to lightning chains |
| **Minefield** | Dash Mine 3 + Fragmentation 2 | Dashes leave a trail of mines |
| **Pinball** | Ricochet 3 + Bank Shot 2 | Extra ricochets with stronger impacts |
| **Breach Engine** | Last Shell 3 + Breach Loader 2 | Improves final shots and the shot after reloading |
| **Hunter Swarm** | Orbit Drone 3 + Targeting Link 2 | Three drones focus marked targets |

Two current descriptions need tightening: Firebreak's code creates ground on eligible burning kills, rather than every ignition. Storm Circuit's “marked clusters” wording suggests a mark requirement or preference, but its chain logic adds targets without requiring marks. Those are copy/behaviour mismatches to review, not extra mechanics to assume exist.

A run can hold **at most two different fusions**. The same fusion cannot be selected twice. Taking one fusion leaves its ingredient upgrades in place.

### What happens at a boss core

A defeated boss opens a choice. Eligible fusions appear alongside ordinary upgrade choices. Selecting a fusion adds its effect to that run. Selecting an ordinary upgrade takes that upgrade instead.

**The core is consumed when its choice is opened.** If the player has no eligible recipe, the choice offers ordinary upgrades; the core is not stored in Collection waiting for ingredients. If a core arrives while another choice is open, it is queued until that choice is resolved.

This makes preparation matter: players should build toward a recipe before the boss dies.

### What the badges mean

- **BOSS CORE:** this recipe requires a boss-core choice during gameplay. It does **not** mean the player owns a core, can buy the recipe, or is currently ready to fuse.
- **DISCOVERED:** a completed normal run recorded that this fusion was created at least once. The recipe remains available to earn again in future runs, but the effect does not start equipped.

All six recipes are visible from the beginning. Discovering one does not unlock a previously hidden recipe page.

### A practical player example

A player decides to try Minefield. They check the recipe, start a run, choose Dash Mine three times and Fragmentation twice, defeat a boss and pick Minefield. Their dashes now lay a mine trail. After the attempt ends, Minefield gains a persistent discovery mark. On the next run they must build it again.

Training can prepare each fusion from its pause menu so the player can test the actual effect without earning the ingredients. Training tests do not add normal fusion discoveries.

## 6. Enemies: a field guide

This tab contains **eight ordinary roles and three bosses**. Its purpose is to help players recognise a threat and decide how to respond.

| Enemy | What the player should learn |
|---|---|
| **Scorpion** | Fans around the sides at distance, then closes directly. Keep an escape route |
| **Mummy** | Intercepts movement and threatens a close strike. Change direction and leave its reach |
| **Revenant** | Keeps distance, strafes and plants to cast. Dodge the shot or close during the cast |
| **Skitter** | Flanks, warns, lunges along a committed line, then recovers. Sidestep the lunge |
| **Shield Warden** | Resists front shots outside recovery. Attack from another angle or use its recovery window |
| **Burster** | Intercepts, then commits to a marked explosion. Leave the marked area |
| **Brood Nest** | Remains an area threat and produces reinforcements. Destroy it to stop its brood |
| **Sentinel** | Marks ground attacks. Move out of the warning |
| **Shadow** | Aimed projectile fans, committed dashes and close strikes |
| **Demon** | Cleaves, marked slams and charge lanes |
| **Scorpion Queen** | Tail attacks, brood and lingering poison |

Ordinary enemies show **FIELD GUIDE** until recorded and **ENCOUNTERED** afterward. Their descriptions are readable in both states. Boss cards currently always say **BOSS**; they do not display equivalent seen/defeated completion states.

An implementation detail matters here: ordinary encounters are tracked when enemies are spawned/added to a run, not when the camera proves that the player has seen one or when it is killed. They are banked after the normal run ends. Therefore ENCOUNTERED is not a kill achievement or a precise seen-on-screen record.

The current guide is text only. It lacks enemy portraits, attack diagrams, personal kill totals and a direct training shortcut. Those omissions make an unfamiliar name much harder to connect to an enemy in play.

## 7. Challenges: goals and permanent unlocks

A challenge is an automatically checked condition with a reward. Players do not activate challenges before playing, spend scrap on them, or press Claim afterward.

Most are evaluated when a **normal run ends in death** and its results are settled. Completing Training is the exception: its completion action records First Steps directly.

### Every current challenge

| Challenge | Actual condition | Current reward |
|---|---|---|
| **First Steps** | Complete Training | Carbine in normal Loadout |
| **Clean Sweep** | 500 total kills across settled normal runs | Scrapper survivor |
| **Hold the Line** | Survive 8 minutes in one unassisted normal run | Warden survivor |
| **Out of the Dark** | Defeat Shadow in a normal run | Revolver |
| **Cool the Furnace** | Defeat Demon in a normal run | Arc Caster |
| **First Cycle** | Defeat Scorpion Queen in a normal run | The Foundry arena |
| **Fusion Made** | Create any fusion in a normal run | Completion record labelled “Recipe archive”; no additional archive is actually unlocked |
| **Royal Pardon** | Defeat Scorpion Queen in a normal run | Queen emblem style |
| **Still Standing** | Survive 15 minutes in one unassisted normal run | Veteran style, currently badge/stripes rather than an independently displayed title |
| **Beyond the Breach** | Survive 20 minutes in one unassisted normal run | Endless cosmetic trail |
| **Pest Control** | 1,000 total scorpion kills | Scorpion charm style |
| **Elite Hunter** | 100 total elite kills | Hunter emblem style |
| **Untouched Shadow** | Defeat Shadow without taking player-health damage during its encounter | Shadow palette |
| **Untouched Flame** | Defeat Demon without taking player-health damage during its encounter | Ember palette |
| **Pump Action** | Defeat Queen using Pump Shotgun | Shotgun mastery completion record |
| **Steady Hands** | Defeat Queen using Carbine | Carbine mastery completion record |
| **Six Chambers** | Defeat Queen using Revolver | Revolver mastery completion record |
| **Live Wire** | Defeat Queen using Arc Caster | Arc mastery completion record |
| **Full Circuit** | Record all six fusion discoveries across normal runs | Engineer palette |
| **Everyone Out** | Defeat Queen with each of the three survivors across normal runs | Survivor emblem style |

“Complete a cycle” currently means **defeat Scorpion Queen**, not simply reach ten minutes. The encounter director normally requests Shadow around three minutes, Demon around six and Queen around ten; long fights and recovery windows can delay requests. The run continues after Queen.

The four mastery “badges” are currently Challenge completion records, not separately equippable Style entries. First Cycle and Royal Pardon intentionally share the same condition and grant different rewards.

### What the displayed progress actually means

- **COMPLETE:** permanently recorded as completed.
- Clean Sweep, Pest Control and Elite Hunter show lifetime kill counters.
- Full Circuit shows recorded fusions out of six.
- Everyone Out shows survivors with a recorded Queen victory out of three.
- Most other unfinished cards say only **IN PROGRESS**, even for binary boss goals or time goals. There is no useful countdown or detailed progress view for them yet.

Time-based unlocks use the profile's unassisted best time. Assisted runs still grant scrap, kills, other applicable challenges and discoveries, but their separate best time does not satisfy those time-unlock checks. That distinction is not explained clearly in the current Collection UI.

The no-hit condition concerns actual health damage, rather than every collision or an attack absorbed by a guard. Damage from other enemies during an active boss encounter can invalidate it too.

## 8. Style: the only current shop and equipment screen

This tab has **13 entries**: the default look, nine challenge styles and three scrap palettes.

### Scrap purchases

| Style | Price | Effect |
|---|---:|---|
| **Copper** | 100 scrap | Warm copper palette |
| **Moss** | 100 scrap | Muted green palette |
| **Ivory** | 150 scrap | Pale ivory palette |

These are appearance changes, not stronger survivors. They do not change health, damage, speed, drops or challenge requirements. There are no Apple/Google purchases, premium currency or cash checkout in this screen today. Monetisation plans are separate from this implemented scrap shop.

### How scrap is earned

At the end of a normal run:

```text
scrap awarded = scrap collected through Scrap Cache offers
              + floor(total run kills / 10)
              + 15 × bosses defeated
              + floor(survival seconds / 60)
```

For example: 250 kills, one boss, seven full minutes and no Scrap Cache grants **47 scrap**. Score and uncollected XP do not directly convert into scrap.

Training awards no normal-run scrap. Pausing or leaving a living run for the menu saves it for Continue; it does not bank its pending results into the profile.

### What the states and buttons mean

| State | Behaviour |
|---|---|
| **LOCKED**, challenge style | Complete its challenge. The Locked button cannot purchase it |
| **LOCKED**, scrap style | Buy becomes usable when the wallet covers the price |
| **OWNED** | Equip applies a style already owned, without charging again |
| **EQUIPPED** | That style is selected; its button is disabled |
| **Buy** | Immediately deducts scrap, permanently adds the style to ownership, and equips it |

There is no separate purchase confirmation or later Claim step. Insufficient scrap disables the purchase action.

**There is one cosmetic slot.** A palette, emblem, charm and trail are not independent slots. Equipping a Queen emblem replaces the Copper palette; equipping Endless replaces the previously selected style. Players cannot currently combine them.

Challenge styles include Shadow/Ember/Engineer palettes, Queen emblem, Veteran, Endless, Scorpion charm, Hunter emblem and Survivor emblem. Standard is owned from the beginning, although its generic card description incorrectly calls it a “Challenge reward.”

The preview uses **Rook**, regardless of the survivor the player plans to select. The equipped style applies to the chosen survivor in gameplay. Many rewards are currently small tints or drawn accessories, not unique fully animated skins; some preview accessories are less detailed than their gameplay rendering.

## 9. When progress is saved—and when it is not

| Action | Effect on Collection |
|---|---|
| Normal player death/results | Banks the run's scrap, counters, discoveries and applicable challenge rewards |
| Retry after results | Begins a new temporary build; banked profile progress stays |
| Leave a living normal run / background the app | Saves the run for Continue; its pending rewards are not yet banked |
| Continue | Resumes that run and its build; does not pay its rewards twice |
| Replace an unfinished run with a new run | Discards the unfinished attempt; its pending rewards are not settled |
| Complete Training | Records First Steps and unlocks Carbine |
| Other Training combat/fusions | Does not farm profile scrap, normal discoveries or other challenges |
| Buy/equip a style | Requests an immediate local profile save |
| Reset progress in Settings | Clears profile progression and the saved run |

The profile is stored locally on the device, with a local backup. It is not a cloud account or a guaranteed cross-device save. App updates normally preserve local app data; uninstalling, clearing data or Reset progress can lose it.

Each settled run has an identity recorded to prevent duplicate rewards. That does not make storage infallible: a profile save can fail. Results can report a save issue, but the current Style purchase/equip callback does not surface its save failure to the player. This needs improvement before paid entitlements are added.

## 10. What players should want to do here: concrete journeys

### New player: “Give me one achievable next goal”

Complete Training → Carbine unlocks → see First Steps completed → choose Carbine in Loadout → aim for surviving eight minutes to earn Warden.

The Collection should support this journey without expecting the player to read 30 upgrade cards first.

### Build explorer: “I want to try the mine build”

Read Minefield's recipe → learn Dash Mine/Fragmentation → try it in Training → pursue it in a normal run → record the discovery → work toward Full Circuit.

The reward is a new way to play and a completion goal, not ownership of a permanently equipped fusion.

### Frustrated player: “What keeps exploding beside me?”

Identify Burster in the enemy guide → learn its warning and counterplay → try dodging it in play.

Currently the missing portraits make the identification step harder than it should be.

### Returning player: “I have scrap—what can I get?”

Open Style → compare Copper/Moss/Ivory → buy one → see it equipped in gameplay → return later for another palette or a challenge appearance.

The current shop is small. It is not yet a deep economy or a compelling long-term spend loop.

## 11. Why the current screen feels like too much information

These are implementation shortcomings, not things the player has failed to understand.

| Current issue | Why it is confusing | Recommended change—not implemented by this document |
|---|---|---|
| All tabs open as large card lists | No answer to “what should I do next?” | Open on a short overview: next unlock, recent reward, scrap balance |
| Reference cards resemble actionable cards | Players may expect tapping to buy, craft or equip | Distinguish reference entries from actions; make purposeful detail views |
| Raw recipe text such as “Hot Shot 3” | The player has not learned what ranks mean | Show ingredient names and rank markers with a brief rank label |
| BOSS CORE on every undiscovered fusion | Looks like an owned currency or lock state | Separate “requires a boss core” from “not yet created” |
| “Recipe archive” reward is already available | Promises an unlock with no visible result | Rename the reward or implement a real unlock; do not claim it exists now |
| Enemy guide has names but no portraits | Players cannot connect the guide to the monster | Add portraits and one clear attack/counterplay example |
| Most goals say IN PROGRESS | Gives no useful target or sense of progress | Show actual progress and name where the reward becomes usable |
| Mastery rewards are called badges but have no equip view | Players expect an item they cannot find | Display mastery in a profile area or label it as a completion achievement |
| One style slot mixes palettes and trophies | Players expect a palette and earned emblem together | Consider separate palette and accessory slots |
| Style previews all use Rook | Players cannot judge their actual survivor's look | Preview the selected survivor and make cosmetic differences clear |
| Wallet is repeated on only the paid palette cards | Currency context is buried | Give Style a persistent, obvious scrap balance |
| Discoveries and rewards bank only after death | A mid-run return looks as though progress was lost | Clearly distinguish pending run progress from banked profile progress |
| Credits share priority with progression | Adds a tab to an already dense screen | Move Credits to Settings/About or make it secondary |

A sensible order is: **clarify the purpose and next goal; fix misleading reward/state labels; make recipes and enemies visual; improve meaningful progress displays; then expand cosmetic depth.** More cards alone would increase the confusion.

## 12. Owner review checklist

Use these to judge whether Collection is doing its job:

- Can a first-time player say what each section is for without reading this document?
- Can they tell which things are temporary run effects and which are permanent rewards?
- Can they identify one achievable next unlock and where to use it?
- Can they explain a fusion recipe and when the boss core is used?
- Can they identify a troublesome enemy by appearance?
- Can they find their scrap balance, understand Buy versus Equip, and see the result?
- Does every named reward have a visible, identifiable result?
- Is an unfinished run's pending progress clearly different from banked progress?

The current implementation provides the systems, but it does not yet communicate them well enough. The goal should be a Collection that helps players make their **next decision**, rather than asking them to study an encyclopaedia.

## Implementation sources

Checked against these local files:

- [Collection screen](../lib/views/collection_view.dart): tabs, labels, cards, cosmetic actions.
- [Player profile](../lib/models/player_profile.dart): persistent ownership, challenge checks, discovery records and unlock rules.
- [Challenge definitions](../lib/data/challenges.dart): all 20 displayed goals and reward names.
- [Loadout definitions](../lib/data/loadout.dart): survivors, weapons and arenas.
- [Upgrade/fusion state](../lib/notifiers/game_notifier.dart): the 30 families, ranks, Special slots, recipe eligibility and boss-core choices.
- [Game](../lib/game.dart): encounter tracking, scrap formula, run settlement and Continue flow.
- [Local preferences](../lib/services/local_preferences.dart): local profile saving, backup and Training completion.
- [Encounter director](../lib/systems/encounter_director.dart): boss scheduling and cycles.
- [Survivor preview](../lib/widgets/survivor_portrait.dart) and [player rendering](../lib/components/game_utils/player_component.dart): actual cosmetic appearance.
