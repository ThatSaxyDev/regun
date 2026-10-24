# Earned weapon Armory — 24 October 2026

Implemented in the app, sibling regun-server module/account gateway and regun-admin.
This is a source implementation, not a production deployment. Sales default OFF.
The approved policy and reasoning are in [WEAPON_SCRAP_UNLOCK_PLAN.md](WEAPON_SCRAP_UNLOCK_PLAN.md).

| Permanent weapon | Boss victories before buying | Earned Scrap |
|---|---:|---:|
| Flak Regent | 36 | 8,000 |
| Longwatch Sniper | 30 | 8,500 |
| Anchor Engine | 40 | 11,000 |
| Cyclone Breacher | 48 | 12,500 |
| Belt-fed Repeater | 5 | 10,000 |
| Mourning Bell | 52 | 15,000 |

“Sniper85” was interpreted as 8,500 inside the approved 8,000–15,000 range.
Scrap is earned through play; no billing, Credits exchange, multiplier or paid
weapon skip was added. The other fifteen weapons keep their existing free rules.
Boss victories unlock a blueprint for these six, not ownership. Current earning
rates and the 55-Scrap revive are unchanged; affordability needs real player data.

## App

PlayerProfile.weaponUnlocked is the normal access resolver. Six IDs require
permanent purchased ownedWeapons; old boss counts, achievement flags and Breach
Hammer aliases do not grant ownership. Unversioned/version1 free or mixed caches
are replaced with access version2. Actual server purchase receipts are preserved;
there is no free legacy import or automatic debit. Old version1 caches need one
cloud sync to recover previously purchased ownership because they do not record
the distinction between a free grant and purchase. Version2 ownership stays
usable offline without expiry. A same-revision policy projection sync does not
create a false progress conflict.

Training can try all21 without buying or earning rewards. BaseView rejects an
unpurchased normal-run weapon through new entry and old Continue checkpoints.
New checkpoints record access version2; active combat/balance snapshots remain
unchanged. The online-room weapon allowlist is unchanged.

Loadout's Weapon tab allows a locked preview and replaces Start with Unlock.
The existing pixel confirmation names the permanent item, exact price and remaining
balance. Boss prerequisites, current price, shortfall, unavailable policy, offline
and changed-price states are handled without a local debit. Sign-in leaves Loadout
before opening the email flow so it does not deadlock the owner lease. A purchase
never automatically starts a run or equips a different weapon.

ArmoryRepository reads public production metadata and caches it per API origin.
Only the Loadout catalogue waits for refresh; startup/ordinary play do not.
PurchaseWeapon checks a fresh authenticated account quote and journals an operation
before sending it. Double taps are serialized. Recovery reads the existing receipt;
it never resubmits a debit on reconnect. Cancellation records an unpaid tombstone,
or recovers a committed grant. Weapon operations share the existing durable pending
purchase slot with cosmetics, keeping one unresolved checkout at a time. Receipt
merges preserve newer local gameplay. Cached permanent ownership works offline,
with an expired session and when an item is hidden or sales are disabled.

## Server and admin

Public GET /economy/v1/armory and authenticated /account return production metadata.
POST /weapon-purchase, /weapon-purchase-status and /weapon-purchase-cancel use existing
host-verified email authentication. The nginx account route allowlist includes them.
The reducer requires accessVersion2 and checks the six IDs, enabled/visible release, exact displayed price,
boss count, profile revision/reset epoch, ownership and wallet balance. Debit,
private entitlement, receipt and profile revision change in one transaction.
Repeating a successful operation cannot spend twice. Uploaded ownedWeapons is not
trusted. Purchases, historical free grants and purchase-only migration audits are distinguishable in support history
and economy reports; weapon spending is separate from cosmetic counts.

No table migration or new ENV variable is needed. Existing private identity_action
rows hold permanent ownership, policy pointers, immutable publication records and
receipts. Existing signing/hash/operator/admin configuration stays in place.
Progress reset preserves these entitlements. Account deletion uses existing policy.

Admin → Scrap economy → Armory has per-channel persisted drafts, enabled/disabled
sales, six visibility controls and whole-Scrap prices constrained to 8,000–15,000.
Boss gates and combat parameters are not editable here. Publication retains reason,
review, expected revision, durable request UUID, immutable history and restore as
a new draft. Staging never changes production spending. A pending publication
freezes editing and retries its original request, including after restart.

The server migrates old mixed ownership from real purchase receipts on first
mutation, using the indexed account history. The gateway projects the same paid
set read-only before that migration. Removed free IDs and retained purchased IDs
are audited and visible in player support history. Old legacyWeaponClaims are
ignored. Admin publication no longer grants old weapons or walks all profiles.
Solo earnings/bosses remain device-reported; this is not anti-cheat proof.

## Rollout and end-to-end checks

1. Back up production. Deploy the matching SpacetimeDB module, then the gateway
   and nginx routes; deploy admin and a compatible app. Keep production sales off.
   The gateway refresh-recovery fix also needs the matching app; see
   [ACCOUNT_SYNC_RECOVERY.md](ACCOUNT_SYNC_RECOVERY.md).
2. With a separate fresh test account, confirm six locked prices and free Training.
   An upgraded profile must buy gameplay-earned weapons; actual earlier Scrap
   purchases must remain owned.
   Do not reset the creator's main account to demonstrate locks.
3. Review/publish staging, then explicitly activate production through admin.
   Staging is catalogue review, not a playable staging session. Check that old
   free grants are removed and earlier paid receipts remain before broad release.
4. On a fresh eligible test account, earn the required boss count and bank enough
   Scrap. Buy once, check the exact debit, ownership and support receipt. Restart,
   sign in on another device, then go offline: the owned weapon should still equip.
5. Try insufficient funds, offline/new spend, a changed quote, double taps and a
   connection drop after debit. Reconnect/status must recover one grant, never a
   second charge. Cancel an unpaid request and verify a delayed request cannot spend.
6. Hide/disable the offer and reset progress on a disposable account. Ownership
   stays. Verify guest/account separation and no Training progression rewards.
7. Review compact landscape/large text and the real phone confirmation flow.
   Automated screenshots are layout evidence, not physical comfort/balance proof.

Automated acceptance and remaining physical checks are recorded in the plan's
implementation checkpoint. No app installation or production publication occurred
as part of this source work.

Purchase-only policy verification:640 app tests (5 opt-in skips),39 admin tests,
134 module tests and18 gateway tests passed, with clean analyzers/typechecks,
module/compiled gateway builds and compiled HTTP smoke. Updated migration tests
prove free grants are removed, paid receipts survive, old Continue cannot bypass
ownership and same-revision access refresh does not create a progress conflict.
