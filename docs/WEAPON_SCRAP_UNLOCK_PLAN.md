# Earned Scrap weapon unlocks — approved end-to-end plan

24 October 2026. **Implementation authorized, not yet live.** The creator approved an8,000–15,000
Scrap range after the initial plan, with Mourning Bell at15,000 and the later-approved Belt-fed Repeater price
of10,000. “Sniper85” is interpreted as8,500 within that stated range. Deliberate
grinding is intended; Scrap remains earned through play. Account sync recovery and the app/API/admin implementation are now in source.
See [ARMORY_IMPLEMENTATION.md](ARMORY_IMPLEMENTATION.md) for actual behavior,
trust boundaries, rollout and acceptance. Production activation remains separate.

## 1. Product decision

Keep a generous achievement-unlocked arsenal and introduce a small collection of
expensive permanent weapon unlocks paid with earned Scrap. Recommend six Scrap
weapons and fifteen existing starter/achievement weapons. A purchase grants the
whole implemented weapon permanently, not a stronger variant, rental, magazine,
damage upgrade or repair obligation.

Scrap must remain unpurchasable: no Credits-to-Scrap exchange, paid multiplier,
paid pass granting Scrap, paid weapon unlock or paid skip of its prerequisite.
Otherwise this policy would create a route from money to combat power. Expensive
earned unlocks create progression and currency demand; they are not themselves
cash monetization.

For the six selected weapons, the existing boss requirement unlocks the **right
to buy**, not free ownership. Then the player explicitly spends the displayed
Scrap price once. Keeping the current automatic boss-count unlock as an OR
condition would bypass the purchase entirely. No requirement to buy other weapons
first: players can save directly for the Repeater. The other fifteen keep their
existing free earned conditions.

Keep all weapons freely testable in Training. No new spending during a run,
change to run XP/fusions/offer odds, paid ammunition or personalized difficulty.
The existing55-Scrap revive remains optional and unchanged. Existing live-balance
snapshots stay stable through Continue/revive.

## 2. Audit baseline before implementation

Source audit covers the app plus sibling `regun-server` and `regun-admin` checkouts.
Current code has **21 weapons**, despite several older documents describing four
or fifteen. No weapon currently costs Scrap.

`PlayerProfile.weaponUnlocked()` uses achievement flags and, for expansion
weapons, cumulative settled boss victories. Settlement adds weapon challenge flags
when those thresholds are reached. The legacy `breachHammer` flag also grants
Longwatch Sniper; preserve that alias during migration.

| Weapon | Current normal-run access | Proposed new-player access | Proposed Scrap |
|---|---|---|---:|
| Pump Shotgun | Starter | Keep starter | — |
| Carbine | Complete/skip Training introduction | Keep earned | — |
| Revolver | Defeat Shadow | Keep earned | — |
| Arc Caster | Defeat Demon | Keep earned | — |
| Burst Rifle |3 total boss victories | Keep earned | — |
| Rail Lance |7 | Keep earned | — |
| Rivet Driver |12 | Keep earned | — |
| Cinder Hose |15 | Keep earned | — |
| Reaper Disc |18 | Keep earned | — |
| Scrap Mortar |27 | Keep earned | — |
| Belt-fed Repeater |5 |5 for purchase availability, then buy | **10,000** |
| Frost Shotgun |9 | Keep earned | — |
| Prism Cutter |21 | Keep earned | — |
| Spore Lobber |24 | Keep earned | — |
| Longwatch Sniper |30, or legacy Breach Hammer unlock |30, then buy |8,500 |
| Twin Verdict |33 | Keep earned | — |
| Flak Regent |36 |36, then buy |8,000 |
| Anchor Engine |40 |40, then buy |11,000 |
| Faultline Driver |44 | Keep earned | — |
| Cyclone Breacher |48 |48, then buy |12,500 |
| Mourning Bell |52 |52, then buy |15,000 |

The creator approved the8,000–15,000 range and implementation. The Repeater is10,000 and
Bell is15,000; Sniper is8,500; Flak8,000; Anchor11,000; Cyclone12,500. These are
implementation defaults and remain unpublished until the reviewed rollout. Boss thresholds are current rules reused as blueprint gates,
not newly validated pacing targets.

Why these six:

- **Repeater:**100-round belt, .4s spin-up, .085s cadence ramping toward .040s
  over sustained fire,3.6s base reload and6% walking penalty. A clear aspirational
  sustained-fire weapon;5 bosses alone currently makes it available relatively
  early. Actual values can also come from the pinned live-balance snapshot.
- **Longwatch:** long-range, deliberate release and piercing identity; a premium
  earned precision branch while Revolver and Rail remain free earned choices.
- **Flak:** high-capacity crowd fire with forward fragments; an expensive heavy
  branch while burst, shotgun and explosive alternatives remain accessible.
- **Anchor:** distinctive delayed gathering/crush control with a7% walking
  penalty; strong workshop identity worth saving for.
- **Cyclone:** rapid close-range five-pellet volleys; Pump and Frost remain free
  earned alternatives, so basic shotgun viability is not withheld.
- **Bell:** late-career cone/echo signature weapon.15,000 is a collection goal,
  not a claim that its five-target cone is objectively stronger than every gun.

Price is not a substitute for balancing an overpowered weapon. Compare damage,
uptime, range, coverage, reload exposure, survivor/build combinations and movement
tradeoffs. Existing stationary weapon audits are not a human win-rate ranking.
Keep strong free-earned options such as Arc, Mortar, Twin and Faultline rather
than putting every powerful weapon behind the shop.

## 3. Earning and the intended grind

Current Solo award:

`run salvage + floor(kills/10) +15*bosses +floor(active seconds/60)`.

Training awards zero. Extra run Scrap includes earned Salvage choices and surplus
cores. Only settled/banked funds may be spent. Existing online match result
totals are a separate path; do not automatically add them into the account wallet
or import them repeatedly as part of this feature.

Two arithmetic examples, **not observed player averages**:

-300 kills,1 boss,10 minutes:55 Scrap before extra salvage.
-1,000 kills,3 bosses,20 minutes:165 Scrap before extra salvage.

| Price |55-Scrap example runs | Active time at10m/run |165-Scrap example runs | Active time at20m/run |
|---:|---:|---:|---:|---:|
|8,000 |146 |24h20m |49 |16h20m |
|8,500 |155 |25h50m |52 |17h20m |
|10,000 |182 |30h20m |61 |20h20m |
|11,000 |200 |33h20m |67 |22h20m |
|12,500 |228 |38h00m |76 |25h20m |
|15,000 |273 |45h30m |91 |30h20m |

Starting from zero, no other spending, no extra salvage and every example run
completed. These are not minimums, forecasts or session counts for real users.
Revives/cosmetics lengthen saving; extra salvage changes it in the other direction.
Keep10,000 as the intended Repeater target and measure the actual journey. Do not
silently inflate all earnings: that would also change the meaning of55-Scrap
revives and100–225-Scrap finishes. Any earning-rate revision is a separately
reviewed economy change, not a hidden part of weapon pricing.

Pinning a weapon shows current funds, price, shortfall and boss prerequisite.
It does not reserve currency, prevent optional revives or erase earned blueprint
progress if the player buys a finish. No losing-player sales targeting.

## 4. Purchase-only access, including past gameplay unlocks

The creator explicitly replaced the earlier grandfathering proposal. All six
weapons require a Scrap purchase, even if previously unlocked through normal
boss milestones, achievement flags or the old Breach Hammer alias. Progress and
Scrap are retained; past gameplay unlocks do not confer ownership or a discount.

Version2 access caches represent purchased weapons only. Old unversioned saves
and version1 mixed/free ownership caches do not grant access. The server rebuilds
old private ownership records from actual weapon_purchase receipts, removes free
grants and records a one-time migration audit. It ignores legacyWeaponClaims,
uploaded ownedWeapons and boss counts as ownership proof. Genuine earlier Scrap
purchases remain permanent and are never charged again, including purchases at
the earlier price. There is no automatic debit for a gameplay-earned gun.

A version1 client cache cannot distinguish a confirmed free grant from a paid
one. Such an old cache needs one cloud sync to recover receipt-backed ownership.
After that, the version2 purchased cache works offline without expiry. New normal
runs and Continue both recheck ownership; an old checkpoint is not a purchase
bypass. Training still tries every weapon freely. Active combat/balance snapshots
are not rebalanced by this policy.

Reset preserves purchased weapons. Account deletion retains its existing policy.
Disabling or hiding sales never grants free ownership or removes paid access.
Older binaries cannot be retroactively changed while offline. The checkout/API
requires accessVersion2 and compatible catalogue metadata. Deploy the matching
app, module and gateway together; old checkout clients receive an update message.

## 5. App contract and design

Create one weapon-access resolver shared by loadout, Training, Challenges/Field
Record, pinned goals, result announcements, preferred loadout and new-run entry.
Its states are `owned`, `milestone locked`, `available to buy`, and `purchase
awaiting confirmation`. For shop weapons, challenge/boss flags alone must not
resolve to `owned` after the migration. For the other fifteen, current earned
rules remain. Use stable IDs, not enum positions, and share fixtures with TS.

Version2 permanent `ownedWeapons`/access cache is separate from cosmetic `owned`, challenge
progress and the selected weapon. An explicit policy version prevents a missing
network response from falling back to the old free boss rule on new installs.
Cached server-confirmed purchased ownership works offline without expiry or
reauthentication on each launch. A different device needs an initial account sync.

Use the existing Weapon tab and pixel design system, not an intrusive new store:

- Compact wallet beside the title; keep the assembled kit and Start controls.
- A locked card states its boss prerequisite and price. Selecting it previews
  the weapon; a locked preview cannot start a normal run.
- Once eligible: `Unlock /10,000` plus owned/balance/shortfall state. An explicit
  confirmation names the permanent weapon and shows before/after Scrap.
- Guests: `Sign in to unlock`. Offline: `Connect to unlock`; no local debit or
  optimistic ownership grant. Owned weapons still equip offline.
- Price changed/offer hidden: refresh and ask the player to choose again; never
  silently accept a higher amount. Already-owned weapons never show Buy.
- After confirmation: show owned/equip, update the wallet, and remove the saving
  goal. Blueprint discovery and actual ownership are distinct events/copy.
- Training retains Your weapons / Try locked weapons for all21. Trying a locked
  gun never grants normal access or rewards. Show the accurate unlock goal.
  Leave Training before opening checkout; don't hold the active local-play lease
  while waiting for the account transition lock.
- Normal run admission rechecks access at the actual start, not just card tap.
  Prevent bypass through preferences, direct route construction, stale selected
  cards, old achievement flags, Training loadouts or malformed checkpoints.

No new startup network gate, daily-login obligation or shop prompt after death.
Test ordinary compact landscape, safe insets and large text; keep important
actions pinned using the existing buttons/frames.

## 6. Server authority and API

Current `economy_contract.ts`, app `ShopCatalog`, LocalPreferences checkout and
admin editor accept **six cosmetics only**, priced25–5,000. `wallet.owned` is a
cosmetic list. `/save` currently accepts device-reported challenge/progress fields.
Merely adding a price or weapon name to that list is insufficient.

Recommend a separate versioned Armory contract/release channel so cosmetic v1
clients and limits remain intact. Implemented route names:

- Public `GET /economy/v1/armory`: compatible production metadata only; stable
  weapon IDs, policy/release version, currency Scrap, exact prices, visibility,
  current fixed blueprint gates and minimum client capability. No damage,
  cadence, scripts, arbitrary IDs or personal pricing in this contract.
- Authenticated account response includes authoritative weapon entitlements and
  migration/policy version, with an owner-scoped durable client cache.
- `POST /weapon-purchase`: weapon, displayed quote/release, operation UUID,
  expected profile revision and reset epoch. Host-verified email/session required.
- `POST /weapon-purchase-status`: read the same receipt, never resubmit spending.
- `POST /weapon-purchase-cancel`: atomic unpaid cancellation tombstone, or return
  an already-committed grant. A delayed original request cannot spend after cancel.
- Gateway nginx allowlist includes all new routes; test real route dispatch and
  non-JSON403 behavior, not only module functions.

Add a private, unique account/weapon entitlement store with source and receipt
reference, plus one-time purchase-only policy migration records. Reuse the existing wallet
balance and audited receipt framework. Keep schema additions non-destructive.

One database transaction checks the active release, fixed sellable allowlist,
blueprint eligibility, owner/session, epoch/revision, not-owned state and balance;
then debits Scrap, grants the weapon, updates the profile projection/revision and
writes the receipt. The server computes the price.15,000 must be accepted by the
new Armory validator without raising the cosmetic limit accidentally.

Retry of the same successful operation returns its receipt without another debit.
Another operation for the same owned weapon returns owned/no spend. Concurrent
buys, another cosmetic purchase and revive spending must serialize against the
same wallet balance. No negative balance and no duplicate entitlement.

Upload/attach/save/reset must project weapon ownership from server entitlements;
an uploaded `ownedWeapons`, challenge flag or high boss total cannot self-grant
one of the six after the purchase-only migration. Uploaded omissions cannot revoke ownership either.
The app's wallet confirmation/merge path must include entitlements while keeping
newer unsynced ordinary progress; don't replace the entire profile with an old
purchase response.

Persist the purchase intent before sending it. If the debit response is lost,
reconcile that receipt before an ordinary cloud comparison can misinterpret the
debit's new revision as a conflict. Recovery must still work if the session expires,
the item is hidden, its price changes, the policy is disabled or the account is
reset after a committed grant. New spending always needs online authorization.

Solo boss/time/Scrap earning inputs remain device-reported in the current offline
model. Server-authoritative debit/ownership is not server-verified offline combat
or currency provenance. Retain that stated trust boundary; no cash exchange,
trading or ranked-value promise. Existing online weapon admission stays unchanged;
none of these six becomes playable online just because it is owned. Before future
online admission, its room reducer must authenticate the account entitlement.

## 7. Admin authoring and reporting

Add an **Armory unlocks** section beside cosmetics and revives. It shows all21
weapons with their free/achievement/blueprint-shop rule; only the six reviewed
shop IDs have editable whole-Scrap prices (recommended allowed range8,000–15,000)
and sale availability. Gate/type changes are a reviewed policy migration, not a
casual price edit. Do not mix combat balance authoring into this page.

Reuse existing operator/session authorization, staging vs production, immutable
release history, expected-revision conflicts, reason and durable publication ID.
Draft/pending publication survive navigation, rotation and restart. Preview lists
old/new price and availability, gates, owners protected and arithmetic saving
scenarios. Staging cannot spend production funds. History restoration creates a
new reviewed release. Same publication retry cannot make duplicate releases.

Add private support views for ownership source, quote/version, amount spent,
operation status and migration grant. Separate weapon spending/counts from
cosmetics and revives in reports. These are earned-Scrap operations, not revenue.
Disable new sales without revoking owners or discarding committed recovery. A
sale kill switch must not revert all unowned weapons to the old free OR rule.

Measure unique confirmed transactions separately from retry request counts;
observe saving/purchase time, boss eligibility time, abandonment, failures and
free-weapon viability. Current unlock medians alone cannot measure time spent
saving after blueprint discovery. Add these events deliberately; don't fabricate
historical times or infer real player averages from synthetic runs.

## 8. Implementation order after approval

1. Approve the six-weapon list, fixed boss gates, high-price table and migration
   promise. Treat10,000 Repeater as the creator's intended goal. No auto-purchases.
2. Define Dart/TS access/catalogue/receipt fixtures and collect baseline earning
   observations without changing earnings or combat balance at the same time.
3. Build additive server entitlement/migration/transaction storage and gateway
   routes, with catalogue/purchases disabled pending complete compatibility.
4. Build admin draft/review/publication/support/reporting and its retry tests.
5. Build app migration/cache/access resolver, then loadout/Training/career UI and
   durable checkout recovery. Verify all old boss-count bypasses are removed for
   new-policy shop weapons while earned free weapons remain correct.
6. Run integration/fault/compatibility checks below; use fresh test profiles to
   see locked prices and upgraded profiles to confirm old free access is removed and actual purchases remain.
   Do not wipe the creator's main profile to demonstrate the feature.
7. Deploy module, gateway/nginx, admin and compatible app in that order with
   preserved publisher identity/secrets/volumes. Review migration counts before
   publishing the Armory release and enabling a test cohort.
8. Review real saving journeys and strong-weapon/free-weapon runs. Keep prices
   global. Any later price/rate change gets a new explicit reviewed release.

Implementation is now authorized. Verification and rollout must be recorded as
they occur; this design document by itself is not proof of deployment or testing.

## 9. Acceptance matrix

| Area | Required evidence before rollout |
|---|---|
| Access | All21 rules; the six need prerequisite AND ownership;15 retain old rules; no dependency on buying another gun |
| Funds |9,999 cannot buy10,000 Repeater;10,000 can, leaving zero; insufficient funds neither spend nor grant |
| Progress |5 bosses exposes Repeater purchase, not free ownership;52 exposes Bell; per-weapon flags cannot bypass; Training cannot grant |
| Existing owners | Old achievements, boss totals, aliases and free grants require purchase; receipt-backed purchased guns survive migration/sync/reset without a second debit |
| Permanence | Offline launch/equip, expired session, hidden offer, changed price and progress reset preserve owners; accounts/devices remain isolated |
| Recovery | Timeout before/after commit, force close before/after local write, double tap, cancel/delayed request, stale quote,403/401 and status-only retry |
| Concurrency | Same weapon from two devices, different weapon, cosmetic and revive racing on one wallet; one valid debit/grant, never negative |
| Cloud | Stale save cannot restore spent Scrap or remove grants; uploaded ownership cannot fabricate grants; reset/new epoch invalidates unpaid old intent |
| Entry points | Selected/preferred loadout, direct normal route, malformed checkpoint, legacy Continue, Training/normal switching and future online admission |
| Admin | Auth failures, invalid IDs/prices, stale revision, lost publication ACK, draft write failure, history restore, staging isolation and sale disable |
| Presentation | Compact landscape/notch/large text; exact before/after price confirmation; pinned controls; no new startup/update/modal regressions |
| Economy | Actual Scrap per active hour and saving-time distributions;55-Scrap revive/finish opportunity cost; viable free arsenal; no cash/premium shortcut |

## 10. Source and research notes

Primary local readers: `lib/data/loadout.dart`, `lib/models/player_profile.dart`,
`lib/models/economy/career_progress.dart`, `lib/models/economy/scrap_reward.dart`,
`lib/views/loadout_view.dart`, `lib/widgets/training_weapon_browser.dart`,
`lib/services/local_preferences.dart`, `lib/services/account/account_controller.dart`,
`lib/models/economy/shop_catalog.dart`, `lib/services/economy/shop_repository.dart`,
`lib/systems/arsenal_system.dart`, `lib/systems/weapon_mobility.dart`,
`docs/WEAPON_POWER_IMPLEMENTATION_REVIEW.md`, `docs/ENDGAME_WEAPONS_REVIEW.md`.
Sibling server readers: `spacetimedb/src/{wallet,identity,economy_contract,schema,index}.ts`,
`identity/src/{service,admin,economy}.ts`, `deploy/nginx.conf`. Admin readers:
`lib/screens/{economy_page,revive_policy_page,server_screens}.dart`.

The previous economy research remains context, not an authority overriding this
new creator decision. An earned weapon shop deliberately expands the earlier
cosmetics/revive-only Scrap scope. It does not authorize selling Scrap or guns.

Fresh external cross-check24 October2026: poncle explicitly documents
[gold-purchased weapon unlocks inside Vampire Survivors Adventures](https://poncle.games/adventures-faq).
That is a specific mode's progression system, not proof of base-game weapon
prices or a universal genre model. Its
[online FAQ](https://poncle.games/vs-online-faq) also distinguishes each player's
own unlocks from host-controlled content. These support considering ownership
and earned spending as separate rules; **Regun's prices/gates above are our design
recommendations and code-derived arithmetic, not numbers copied from another game**.

## Implementation checkpoint — 24 October 2026

App, module/gateway/nginx and admin are implemented with the approved defaults.
The admin editor authors the six shop weapons; the fifteen unchanged free-earned
rules remain in the game rather than being editable economy rules. Publication
review lists price/visibility/enable changes; arithmetic saving scenarios remain
in this plan, not a personalized admin forecast. Sales default disabled.

Shared Dart/TypeScript fixture checks cover all six IDs, gates and prices. Module
tests cover quote/balance/gate checks, idempotency, cancellation, forged ownership,
free-grant removal, paid-receipt preservation and disable/reset permanence. Gateway tests cover read-only receipt
lookup, authenticated actions, production-only metadata and separate report flows.
App fault tests cover lost purchase replies, failed intent writes, offline/guest
spending, double taps and cancellation under the Loadout lease. Layout screenshots
cover 844×390 and 568×320 with enlarged text. Training and combat regression suites
remain required, alongside analyzer/full-suite verification.

Physical phone checkout, interruption testing, production-sized first activation,
actual saving-time telemetry and balance approval remain rollout checks. These
prices deliberately imply a long grind at unchanged earnings; no claim of
validated player pacing is made.

Verification completed: app analyzer clean, **639 tests passed / 5 opt-in tests
skipped**; admin analyzer clean and **39 tests passed**; module **133 tests**,
TypeScript checks and SpacetimeDB build passed; gateway **17 tests**, TypeScript
checks, compiled build and compiled HTTP smoke test passed. These are automated
source checks, not production/physical acceptance.

## Purchase-only correction — 24 October 2026

Grandfathering was explicitly withdrawn. Version2 policy, app migration, new-run
and Continue admission, API projection, reducer ownership and admin copy now agree
that gameplay-earned access is not purchased ownership. Repeater default is10,000
in Dart, TypeScript, shared fixtures and the admin baseline. Existing published
admin releases/drafts are not silently overwritten: publish10,000 through the
reviewed channel if production already has the older price. No deployment was
performed in this source pass.

Purchase-only correction verification: app analyzer clean and640 tests passed
(5 opt-in skips); admin analyzer clean and39 tests passed; module134 tests,
TypeScript checks and build passed; gateway18 tests, TypeScript checks, build
and compiled HTTP smoke passed. No deployment or physical-device acceptance
is implied.
