# Web Scrap purchase plan

Status: proposed, not implemented. Created 7 November 2026.
Baseline: game `88e7e63`, web export `1.0.1+43` (`playregun.kiishi.space`),
server `../regun-server` working tree.

Scope: sell Scrap in the browser with Bachs hosted checkout. Apple checkout,
the wallet, and earned Scrap stay exactly as they are.

## 1. The pricing problem, stated exactly

Prices are **not** in Regun's source today. They are in App Store Connect and
arrive at runtime through StoreKit:

- `lib/widgets/scrap_store_dialog.dart:175` renders `offer.product.price`.
- `AppleScrapStore.load()` returns `(amount, ProductDetails)` pairs, where the
  price string comes from `queryProductDetails`.
- The server catalog is quantity-only:
  `../regun-server/spacetimedb/src/scrap_packs.ts` maps six
  `dev.kiishi.regun.scrap.<qty>` IDs to `1000…25000`. `/apple-scrap`
  (`identity/src/service.ts:367`) returns `{accountId, packs, environment}` and
  carries no money at all.

A browser has no StoreKit, so it has no price source. **Web therefore needs a
server-owned price catalog.** That is the only structural addition this plan
makes to pricing. Apple keeps reading its own localized price from StoreKit; the
Naira ladder in `SCRAP_PURCHASE_PLAN.md` is the reference both must match.

Consequence for trust: the server must know the expected amount and currency
before it grants, because it has to reject a Bachs webhook whose amount does not
match the pack it claims to represent.

## 2. Non-displacement contract

These may not change behaviour. Any diff touching them is a defect in this work.

| Surface | Preserved |
|---|---|
| `identity/src/apple_scrap.ts` | Verification, allowlist, modes, JWS checks |
| `/apple-scrap` response | Exactly `{accountId, packs, environment}`; no new required fields |
| `/apple-notifications` | Unchanged ingress and refund clawback |
| `wallet.ts` | `grantAppleSandboxScrap`, `revokeAppleScrap`, journal, cloud revision projection |
| `scrap_packs.ts` | Six Apple product IDs and quantities; append only |
| `http.ts` `body()` | Every existing route keeps the current buffered `JSON.parse` path |
| `apple_scrap_store.dart` | Apple flow byte-identical; no new required deps |
| Native UI | `AppleScrapStore.supported` continues to gate iOS/macOS exactly as today |
| Default web UI | No plus affordance and no store entry until a flag is turned on |

`AppleScrapStore.supported` (`apple_scrap_store.dart:16`) is `false` on web
today, which is why the wallet chip shows only `3,103` and the Wallet dialog has
only **Close**. That is the correct default and stays the shipping state until
Phase 4.

## 3. Architecture

One new provider joins the existing grant boundary. Bachs never talks to the
Flutter client and never writes a balance.

```
Web (Flutter) ── /web-scrap {catalog|create|status} ──▶ identity gateway
                                                        │
                          Bachs Checkout (hosted) ◀─────┤ create session
                                                        │
      Bachs ── /bachs-notifications (signed raw body) ──┤ verify + reduce
                                                        ▼
                                              SpacetimeDB wallet reducer
```

### 3.1 New server surfaces

- `identity/src/bachs_scrap.ts` — config, checkout creation. Bachs base URL
  switches on `REGUN_BACHS_ENV` (`off|sandbox|production`); the secret key's
  prefix must agree with it.
- `spacetimedb/src/web_scrap_catalog.ts` — pack key → `{quantity, currency,
  amount, amountMinor}` plus the reference format. Single source for the amount
  check. Lives in the shared module so the wallet reducer validates the pack
  itself instead of trusting the caller; identity imports it because it has no
  internal imports.
- `spacetimedb/src/web_scrap_orders.ts` — checkout intent: order-first record,
  then attach the provider checkout ID. Same reference with different inputs is
  a conflict; same inputs are a replay.
- `/web-scrap` actions: `catalog`, `create`, `status`. Same bearer auth as
  `/apple-scrap`, same account binding rules.
- `/bachs-notifications` — new ingress branch **before** `http.ts` `body()`,
  scoped to that exact path: read raw bytes, verify
  `X-Bachs-Signature-V2` (HMAC-SHA256 over `"{timestamp}.{raw_body}"`, 300 s
  tolerance, accept any `v1=` for rotation), then parse locally.
- `spacetimedb/src/wallet.ts` — `grantBachsScrap` / `revokeBachsScrap`, mirroring
  the Apple pair: idempotent by collection ID, journal row, cloud profile
  revision, refund floors at zero.
- `spacetimedb/src/schema.ts` — `bachsScrapGrant`, `bachsScrapRefund`,
  `webScrapOrder` (append to the export list).
- `deploy/nginx.conf` — append `/web-scrap` and `/bachs-notifications` to the
  allowlist. No existing location changes.

### 3.2 Client

- `lib/services/scrap_store.dart` — small interface: `supported`, `load()`,
  `buy(pack)`, `recover()`. Apple becomes a thin adapter with no behaviour
  change; Bachs is a web-only adapter.
- `scrap_store_dialog.dart` takes the interface instead of `AppleScrapStore`.
  The price widget renders `offer.priceLabel`, which Apple fills from
  `ProductDetails.price` and Bachs fills from the server catalog.
- Gate: `REGUN_WEB_SCRAP` compile-time flag, default absent = off, **and**
  `kIsWeb`. Native never sees the Bachs path; web never sees the Apple path.
- Return handling: hosted checkout opens in a new tab; on window focus the
  client polls `status` for the outstanding order. Redirect never grants, and
  the game never navigates away, so no SPA rewrite is needed on the static host.
- Entry points mirror Apple exactly: wallet chip, Armory shortfall, eligible
  revive offer. Same three call sites, switched from `AppleScrapStore.supported`
  to the flag-gated provider check.

## 4. Phases and exit evidence

| Phase | Work | Exit evidence |
|---|---|---|
| 0. Decisions | ~~Approve the web price ladder and pack→product mapping~~ **Sealed, section 6** | Apple and Bachs resolve to the same six quantities |
| 1. Server contract, flags off | `web_scrap_catalog.ts`, `/web-scrap`, reducers, schema, nginx | Server tests: catalog shape, ownership mismatch, replay, wrong-amount refusal, refund floor. `/apple-scrap` response diff empty |
| 2. Webhook ingress | Raw-body branch, signature verify, dedupe-before-side-effect | Fixture tests: valid, tampered, stale timestamp, rotated `v1`, duplicate ID, `checkout.completed` before `collection.succeeded` |
| 3. Client adapter, flag off | Interface extraction, Bachs adapter, focus polling | `flutter analyze` clean; Apple widget tests unchanged and passing; web build still shows no plus sign and no store entry |
| 4. Sandbox on HTTPS staging | Six Bachs sandbox products, webhook endpoint, `REGUN_WEB_SCRAP=true` | End-to-end purchase on staging; `version.json` and build ID recorded |
| 5. Production | Live keys, merchant approval, sales switch | Rollback switch proved: flag off hides checkout while claims and refunds still process |

### Phase 1 record · 7 November 2026

Implemented, flags off. No existing file's behaviour changed.

- `spacetimedb/src/web_scrap_catalog.ts` — six packs, Naira ladder, strict
  `amountMinor` parser, reference format.
- `spacetimedb/src/web_scrap_orders.ts` — order-first intent with replay and
  conflict rules.
- `spacetimedb/src/schema.ts` — `bachs_scrap_grant`, `bachs_scrap_refund`,
  `web_scrap_order`, appended to the export list.
- `spacetimedb/src/wallet.ts` — `grantBachsScrap`, `revokeBachsScrap`, and two
  journal kinds. Grant settles the matching order in the same transaction.
- `spacetimedb/src/identity.ts` + `index.ts` — four operator-only reducers.
- `identity/src/bachs_scrap.ts` — mode, prefix agreement, public-HTTPS return
  URL check, sales switch, checkout creation.
- `identity/src/service.ts` — `/web-scrap` catalog/create/status behind the
  existing bearer auth.
- `deploy/nginx.conf` — `web-scrap` appended to the identity allowlist.

Verification: server 244 tests pass and `spacetime build` succeeds; identity 52
tests pass, TypeScript build succeeds, and the compiled gateway smoke passes.
Untouched: `apple_scrap.ts`, the `/apple-scrap` response, `/apple-notifications`,
`http.ts`, and `apple_scrap_store.dart`. Webhook ingress remains Phase 2, so
nothing can grant without a verified event yet.

### Phase 2 record · 7 November 2026

Implemented, flags off. Webhook ingress exists and is proven without live
traffic; the deployed nginx still refuses the path, so no delivery can arrive
until Phase 4 deploys it.

- `identity/src/bachs_webhook.ts` — HMAC-SHA256 over `"{timestamp}.{raw}"`,
  `X-Bachs-Signature-V2` preferred with every `v1=` tried, legacy
  `X-Bachs-Signature` + `X-Bachs-Timestamp` fallback, 300 s tolerance,
  constant-time compare with a length guard, comma-separated secrets so a
  24-hour rotation stays valid.
- `identity/src/http.ts` — `/bachs-notifications` branch added **before** the
  shared `body()` call, reading raw bytes through a separate `rawBody()`.
  `body()` itself is byte-for-byte unchanged, so every other route keeps its
  existing parsed path. With no secret configured, the route is `404`.
- `identity/src/service.ts` — `bachsEvent()` flattens the envelope and hands a
  normalised delivery to one reducer.
- `spacetimedb/src/web_scrap_events.ts` — one reducer per delivery: dedupe on
  the event `id`, then fulfil, close, or claw back. `checkout.completed` and
  `collection.succeeded` are both fulfilment paths, because either can arrive
  first; safety comes from the amount and order check, not the event type.
- `spacetimedb/src/schema.ts` — grants and refunds rekeyed on Bachs `charge_id`
  (the only identifier shared by `collection.succeeded` and `refund.paid`),
  plus `bachs_scrap_grant.amountPaid`, `.reference`, and a
  `bachs_webhook_event` delivery log.
- The Phase 1 operator-only `identity_grant_bachs_scrap` reducer was removed:
  fulfilment now has exactly one entry point, so there is no manual bypass.

Judgement calls recorded rather than hidden:

- **Partial refunds are not clawed back.** `refund.paid` is partial-capable, so
  debiting the whole pack would take Scrap the player still paid for. Anything
  short of a full refund is stored with outcome `refund_review` and the reason,
  and left for a human.
- **A refund with no matching grant** is stored with outcome `refund_review`.
  Silently ignoring it would mean a refund you paid out disappears.
- **Out-of-order deliveries** are handled by state, not by timestamps: only an
  `open` order can be closed, and `paid`/`refunded` are terminal. A late
  `checkout.expired` cannot reopen or override a paid order.
- **Test webhooks have a null `charge_id`**, so they cannot fulfil. They are
  stored as `missing_charge` instead of being granted on an unbacked event.

Verification: server 255 tests pass, identity 60 tests pass, `spacetime build`
succeeds, and the compiled-gateway test proves a signed delivery with unusual
whitespace reaches the reducer unchanged while unsigned, tampered, and stale
deliveries never touch the database.

Money is compared in minor units on both the gateway-adjacent reducer and the
wallet, so a provider that sends `"1350"` for a `"1350.00"` pack still matches
while `"1.00"` and unparsable amounts are refused.

## 5. Verification matrix
Run against the real transactional database plus provider fixtures.

| Scenario | Pass condition |
|---|---|
| Duplicate webhook | One grant row, one wallet delta |
| Redirect before webhook | Balance unchanged until verified event |
| Webhook lost, player returns | `status` reports pending; no grant invented |
| Tab closed after paying | Grant appears on next sign-in, same account |
| Account switched mid-checkout | Grant never lands on the second account |
| Amount or currency mismatch | Rejected, recorded, no grant |
| Refund twice, and refund before grant | Net zero once; no negative wallet |
| Apple purchase while Bachs enabled | Unchanged grant, unchanged receipt |
| Web build with flag off | No plus sign, no store entry, Wallet has only **Close** |

Commands: `make verify`, `flutter analyze`, the focused wallet/store suites, and
the identity gateway smoke. Record revisions before and after.

## 6. Sealed decisions

Confirmed by the creator, 7 November 2026. These are settled; reopening one
requires amending this section first.

| # | Decision | Value |
|---|---|---|
| D1 | Web price | Mirrors the Apple Naira ladder exactly |
| D2 | Presentment currency | NGN, identical to the Apple base storefront |
| D3 | Return flow | Hosted checkout in a new tab; game polls on window focus |
| D4 | Web entry points | All three, matching Apple: wallet chip, Armory shortfall, eligible revive offer |

Resolved without escalation:

| # | Decision | Value | Reason |
|---|---|---|---|
| D5 | Pricing source | `pricing` per checkout, **not** `product_cart` | *(amended 7 Nov: see 6.1)* |
| D6 | Catalog location | Constant in `web_scrap_catalog.ts` | Six values do not justify a migration; deploy-gated price change is acceptable |
| D7 | Refund rule | Claw back unspent, floor at zero | One rule across providers |
| D8 | Sales switch | Compile-time `REGUN_WEB_SCRAP` **and** server `salesEnabled` | Stop sales without rebuilding the web bundle; claims and refunds keep running |
| D9 | Economy review gate | Already satisfied | Build 43 shipped production Apple Scrap; web inherits a cleared gate |
| D10 | Redirect grants | Never | There is no grant path at all in the return flow |

### 6.1 Amendment to D5 — pricing source

D5 was sealed as "six Bachs catalog products, 1:1 with pack keys". Live
credentials contradict that plan, so it is amended rather than left to rot.

Evidence gathered 7 November 2026 against `https://sandbox-api.bachs.io` with
the Regun sandbox key. Earlier probes in this session used keys from an older
project and are superseded; only the results below are authoritative.

| Probe | Result | Reading |
|---|---|---|
| `GET /v1/products` | `200 OK`, `total: 0` | Key is valid, holds `products:read`, catalog is **empty** |
| `POST /v1/checkout-sessions` with `{}` | `400 VALIDATION_ERROR`, "Provide exactly one pricing source: 'pricing', 'product_cart', or 'product_collection_id'" | Key **can** create checkouts |

The empty catalog is the important result. It confirms a dedicated Regun
account rather than a shared one, and it removes any dependency on Bachs-side
products for this work.

Amended decision stands, now on stronger grounds: each checkout is created with
a server-computed `pricing` object taken from `web_scrap_catalog.ts`. The pack
key travels in `metadata` and the order identity in `reference`. Nobody edits a
Bachs product to change a price; the deploy does.

`pricing` with `currency_options` expresses the approved Naira ladder exactly,
with no Bachs catalog at all: `{"currency":"NGN","amount":"1350.00"}` per pack.
This keeps the price ladder in version control and reviewable in a pull request,
which `product_cart` would move into a dashboard.

Risk accepted: a raw `pricing` checkout has no Bachs-side product to reconcile
against, so the gateway's own `webScrapOrder` record becomes the only order
ledger. This is why `/web-scrap status` and the admin lookup are mandatory, not
optional.

Merchant-account status: a Regun-specific sandbox account exists and is
reachable. The remaining Phase 4 questions are unchanged in kind but narrower:
whether nontransferable game currency is an approved product for this account,
and which entity is merchant of record for tax and receipts. Neither blocks
Phase 1–3.

### 6.2 Payment corridors available to this account

Documented corridors are `USD_CARD`, `NGN_CARD`, `NGN_BANK_TRANSFER`, `MOMO_GHS`,
`MOMO_KES`, `MOMO_TZS`, `MOMO_UGX`, `MOMO_XAF`, `MOMO_XOF`, `MOMO_RWF`,
`MOMO_MWK`, `MOMO_ZMW` and `CRYPTO`. Which are *enabled* for this account is a
dashboard fact, not inferable from the API key. Phase 4 must read it from
`/guides/payments/payment-method-support` while signed in, then record the
result here.

Launch restriction, pending that check: `NGN_CARD` plus `USD_CARD`. A checkout
restricted to a corridor the account cannot accept fails with
`CHECKOUT_RESTRICTION_LEAVES_NO_PAYMENT_METHOD`, which is a safe failure —
it cannot take money it cannot settle.

### 6.3 Webhook ordering correction

Earlier drafts of this plan asserted that `checkout.completed` is never proof of
payment. That is wrong. Bachs documents that `checkout.completed` and
`collection.succeeded` can arrive in either order, and that the correct
behaviour is to fulfil on whichever arrives first, **once**.

The server rule is therefore: accept either event, and in both cases verify the
paid amount and currency against `web_scrap_catalog.ts` plus the order record.
Amount verification, not event type, is what makes the grant safe. A free
checkout emits only `checkout.completed`, which fails the amount check for every
real pack and is rejected.

### Approved web price ladder

The server catalog must reproduce this table. Apple generates these amounts from
Naira; Bachs charges them directly. Each pack carries a Naira base price plus a
USD price, because the hosted page settles in the buyer's currency.

| Scrap | Pack key | NGN | USD | Note |
|---:|---|---:|---:|---|
| 1,000 | `scrap_1000` | ₦1,350 | $1.00 | Bachs floor |
| 2,500 | `scrap_2500` | ₦2,900 | $1.99 | |
| 5,000 | `scrap_5000` | ₦4,900 | $2.99 | |
| 10,000 | `scrap_10000` | ₦7,900 | $4.99 | |
| 15,000 | `scrap_15000` | ₦9,900 | $5.99 | |
| 25,000 | `scrap_25000` | ₦14,900 | $7.99 | |

**The 1,000 pack is $1.00, not $0.99.** Bachs rejects any USD amount below
1.00, verified against the sandbox API: `currency_options {"USD":"0.99"}` and
`currency:"USD", amount:"0.99"` both return `VALIDATION_ERROR`, while `1.00`
returns `201`. The App Store still charges $0.99. The one-cent difference is
forced by that floor, not chosen.

Two further API facts worth keeping:

- Prices are **decimal strings**. `"900"` means nine hundred dollars, not nine
  hundred cents. Types are enforced: a JSON number is rejected.
- The base `amount` must clear the same floor, so USD cannot be the base
  currency for the cheapest pack. Naira stays the base on every pack.

Drift rule: if App Store Connect repricing changes an Apple storefront amount,
this table does not move automatically. A mismatch is a **display** difference
only — grants are governed by pack quantity, and the webhook amount check
compares the settled currency against the price for *that* currency in this
catalog. A settled amount that matches no listed price is refused. Reconcile the
two ladders quarterly.

Corridor rule: every currency the catalog prices must have a payable corridor,
checked at boot. Pricing USD without `USD_CARD` (or pricing Naira without any
`NGN_` corridor) refuses to start, because the hosted page would otherwise offer
a currency the buyer cannot use.

### Deferred to Phase 4

These cannot be answered without a Bachs account and do not block Phase 1–3:

- Merchant account approval for Regun specifically (ITE's account does not
  transfer), and whether sandbox keys exist today.
- Written confirmation that nontransferable game currency is an approved
  product, and who is merchant of record for tax and receipts.
- Payment corridors. Start narrow — NGN card plus USD card — then widen after
  observing one real settlement and one real refund.

## 7. Credentials

Bachs credentials are supplied to the gateway as environment variables and are
never committed. Every Bachs variable below also accepts a `<NAME>_FILE`
companion, resolved by `bachsEnvironment()`, so a production deployment can
mount secrets as files instead of inlining them. An unreadable file is a
startup error rather than a silently unset secret.

**Both environments' credentials live side by side in one deployment.** Going
live changes `REGUN_BACHS_ENV` and nothing else: no code edit, no rebuild, and
no window where a key is paired with the wrong base URL.

| Variable | Purpose | Needed at |
|---|---|---|
| `REGUN_BACHS_ENV` | `off` \| `sandbox` \| `production`. The single switch | Phase 1 |
| `REGUN_BACHS_SANDBOX_SECRET_KEY` | `sk_sandbox_…`, Bearer auth for sandbox checkout | Phase 4 |
| `REGUN_BACHS_PRODUCTION_SECRET_KEY` | `sk_live_…`, Bearer auth for live checkout | Phase 4 |
| `REGUN_BACHS_SANDBOX_WEBHOOK_SECRET` | `whsec_…` for sandbox deliveries | Phase 2 |
| `REGUN_BACHS_PRODUCTION_WEBHOOK_SECRET` | `whsec_…` for live deliveries | Phase 2 |
| `REGUN_BACHS_SANDBOX_RETURN_URL` | Public HTTPS return page for sandbox | Phase 4 |
| `REGUN_BACHS_PRODUCTION_RETURN_URL` | Public HTTPS return page for live | Phase 4 |
| `REGUN_BACHS_SALES` | `off` pauses new checkout while keeping reconciliation alive | Phase 1 |

Each environment may also carry `_CANCEL_URL`, defaulting to its return URL.
`REGUN_BACHS_RETURN_URL` and `REGUN_BACHS_CANCEL_URL` remain as a shared
fallback when the per-environment pair is absent.

There is no per-pack product variable: section 6.1 sells raw `pricing`, so the
pack catalog in `web_scrap_catalog.ts` is the only place a price lives.

Rules:

- Never paste a secret into a chat transcript, commit, build record, test
  fixture or release note. Local values go in `regun-server/.local/`, which
  `.gitignore` already excludes.
- Phase 1–3 require **no** real credential. Signature verification is tested
  against a locally generated secret and fixed raw-body fixtures, so the
  webhook path is provably correct before any Bachs value exists.
- Only the selected environment is read. A broken or absent production key
  cannot take down a sandbox deployment, which is what makes the switch
  reversible.
- Selecting an environment without that environment's key, or without its
  webhook secret, refuses to boot. A checkout that can take money but cannot
  confirm it is worse than no checkout.
- A key whose prefix disagrees with `REGUN_BACHS_ENV` refuses to boot, because
  Bachs decides the environment from the prefix and would otherwise charge
  real cards from a sandbox-looking deployment.
- Rotating the key after the work is complete is the correct default. Revoke
  the old key rather than only replacing it, and confirm the gateway fails
  closed and logs a startup error when the configured key is rejected.

## 8. Rollback

Every new surface is additive and flag-guarded. `REGUN_WEB_SCRAP` unset rebuilds
today's web binary exactly. `REGUN_BACHS_ENV=off` disables new checkout while
leaving webhook verification and refund reconciliation running, so a mid-flight
purchase or refund is never stranded.
