# Airdrop navigation and title spacing — 24 October 2026

| Verification | Result | Log |
|---|---|---|
| Game analyzer/full suite | Clean; 711 passed, five existing opt-in skips | [Full verification](mobile-verify.txt) |
| Focused native cover/crowd checks | 24 passed | [Focused checks](mobile-focused.txt) |
| Existing title/menu layout checks | 23 passed | [Layout checks](upgrade-layout-focused.txt) |
| Server typecheck/tests/module build | 151 passed; build passed | [Full verification](server-verify.txt) |
| Expanded server cover checks | Two tests, including all three footprint arrangements | [Focused checks](server-focused.txt) |

Before the fix, dense pursuit failed in both native and server reproduction:
[Native](mobile-reproduction-before.txt), [server](server-reproduction-before.txt).
The expanded regressions pass with a pod, a proposed 70×44 sentry-base rectangle,
and adjacent temporary cover. The real native mixed 16-enemy scene also passes.
Server checks cover body spacing, solid exclusion and bounded movement.
Existing fence-side/contact/removal and committed attack stops remain covered.

[Actual rendered title spacing](upgrade-title-spacing.png): 24px minimum top
clearance, with bottom controls still visible. Small landscape and large-text
layouts are included in the game suite.

[Navigation change](../../AIRDROP_NAVIGATION_FIX.md).
[Sentry/Aura proposal](../../AIRDROP_EXCLUSIVE_POWERUPS_PLAN.md).

Sentry Gun and Aura Farm are NOT implemented. The sentry rectangle is navigation
preparation, not a completed sentry entity or visual. No installation, server
deployment, balance publication or physical-device acceptance is claimed.
