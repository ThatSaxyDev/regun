# Monetization and backend research record

Research accessed 19 October 2026 through the Firecrawl CLI search/scrape skills. No paid-provider accounts, live products, backend resources or advertising campaigns were created. This is a source-supported product/engineering report, not a legal certification or revenue forecast.

## Method and limits

- Audited the actual local code before recommending currency or purchase changes.
- Compared five relevant mobile storefront listings, explicitly distinguishing free and premium versions.
- Used Apple/Google policy and native-purchase documentation for compliance/fulfillment requirements.
- Reviewed Flutter purchase integration, RevenueCat, SpacetimeDB official docs/pricing, two community Dart client descriptions, and backend fallbacks.
- Competitor prices are captured storefront examples, not a comprehensive catalog or proof of current in-game placement, player conversion or revenue. Embedded user reviews were not treated as developer-confirmed feature documentation.
- SpacetimeDB native compatibility, load capacity, latency, recoverability and license suitability require a pinned-release implementation spike. Maintainer descriptions are not test evidence.
- Search results included irrelevant community/social pages. Those were discarded except explicitly labelled observational review references. No forum post establishes store policy.
- Raw retrieved content is cached locally in ignored `.firecrawl/`; it is not copied wholesale into the deliverable. Citations and this source index preserve provenance without redistributing full pages.
- Store rules, product prices, SDK versions and infrastructure/vendor pricing can change. Recheck at implementation/submission; the plan identifies especially time-sensitive Billing Library and regional-fee details.

## Source index

1. **Comparables:** [Vampire Survivors - App Store](https://apps.apple.com/us/app/vampire-survivors/id6444525702). Local research cache: `.firecrawl/monetization-vampire.json`.
2. **Comparables:** [20 Minutes Till Dawn - App Store - Apple](https://apps.apple.com/us/app/20-minutes-till-dawn/id1635123906). Local research cache: `.firecrawl/monetization-premium.json`.
3. **Comparables:** [20 Minutes Till Dawn:Premium - App Store - Apple](https://apps.apple.com/us/app/20-minutes-till-dawn-premium/id1630887189). Local research cache: `.firecrawl/monetization-premium.json`.
4. **Comparables:** [Brotato - App Store - Apple](https://apps.apple.com/us/app/brotato/id6445884925). Local research cache: `.firecrawl/monetization-comparables.json`.
5. **Comparables:** [Survivor!.io - App Store](https://apps.apple.com/us/app/survivor-io/id1528941310). Local research cache: `.firecrawl/monetization-survivorio.json`.
6. **Policy:** [App Review Guidelines - Apple Developer](https://developer.apple.com/app-store/review/guidelines/). Local research cache: `.firecrawl/monetization-apple.json`.
7. **Policy:** [Payments - Play Console Help - Google Help](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en). Local research cache: `.firecrawl/monetization-google.json`.
8. **Policy:** [Policies for ad units that offer rewards - Google AdMob Help](https://support.google.com/admob/answer/7313578?hl=en-GB). Local research cache: `.firecrawl/monetization-reward-policy.json`.
9. **Integration:** [in_app_purchase | Flutter package - Pub.dev](https://pub.dev/packages/in_app_purchase). Local research cache: `.firecrawl/monetization-flutter.json`.
10. **Integration:** [Integrate the Google Play Billing Library into your app](https://developer.android.com/google/play/billing/integrate). Local research cache: `.firecrawl/monetization-security.json`.
11. **Integration:** [Testing refund requests | Apple Developer Documentation](https://developer.apple.com/documentation/storekit/testing-refund-requests). Local research cache: `.firecrawl/monetization-apple-tech.json`.
12. **Integration:** [Handling refund notifications](https://developer.apple.com/documentation/storekit/handling-refund-notifications). Local research cache: `.firecrawl/monetization-apple-tech.json`.
13. **Integration:** [In-App Currency | In-App Subscriptions Made Easy](https://www.revenuecat.com/docs/offerings/virtual-currency). Local research cache: `.firecrawl/monetization-revenuecat.json`.
14. **Backend:** [spacetimedb | Dart package - Pub.dev](https://pub.dev/packages/spacetimedb). Local research cache: `.firecrawl/monetization-spacetimedb-fit.json`.
15. **Backend:** [mikaelwills/spacetimedb-dart-sdk - GitHub](https://github.com/mikaelwills/spacetimedb-dart-sdk). Local research cache: `.firecrawl/monetization-spacetimedb-fit.json`.
16. **Backend:** [FAQ | SpacetimeDB docs](https://spacetimedb.com/docs/intro/faq). Local research cache: `.firecrawl/monetization-spacetimedb-security.json`.
17. **Backend:** [Reducer Context | SpacetimeDB docs](https://spacetimedb.com/docs/functions/reducers/reducer-context). Local research cache: `.firecrawl/monetization-spacetimedb-security.json`.
18. **Backend alternatives:** [Row Level Security | Supabase Docs](https://supabase.com/docs/guides/database/postgres/row-level-security). Local research cache: `.firecrawl/monetization-supabase.json`.
19. **Backend alternatives:** [Authoritative Multiplayer - Heroic Labs Documentation](https://heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/). Local research cache: `.firecrawl/monetization-multiplayer.json`.
20. **Backend alternatives:** [Nakama Dart Client SDK · GitHub](https://github.com/heroiclabs/nakama-dart). Local research cache: `.firecrawl/monetization-multiplayer.json`.
21. **Economics:** [App Store Small Business Program - Apple Developer](https://developer.apple.com/app-store/small-business-program/). Local research cache: `.firecrawl/monetization-fees.json`.
22. **Economics:** [Changes to Google Play's service fee in 2021 - Play Console Help](https://support.google.com/googleplay/android-developer/answer/10632485?hl=en). Local research cache: `.firecrawl/monetization-google-fees.json`.
23. **Economics:** [Service fees - Play Console Help - Google Help](https://support.google.com/googleplay/android-developer/answer/112622?hl=en). Local research cache: `.firecrawl/monetization-google-fees.json`.
24. **Design guidance:** [Hybrid-casual: the secret sauce to higher retention and better ...](https://www.gameanalytics.com/blog/hybrid-casual-higher-retention-better-engagement). Local research cache: `.firecrawl/monetization-economy.json`.
25. **Integration:** [RevenueCat Flutter setup](https://www.revenuecat.com/docs/getting-started/installation/flutter). Local research cache: `.firecrawl/monetization-rc-flutter.md`.
26. **Economics:** [RevenueCat pricing](https://www.revenuecat.com/pricing/). Local research cache: `.firecrawl/monetization-rc-pricing.md`.
27. **Backend:** [SpacetimeDB official client list](https://spacetimedb.com/docs/clients/). Local research cache: `.firecrawl/spacetimedb.com-docs-clients.md`.
28. **Backend:** [SpacetimeDB procedures](https://spacetimedb.com/docs/functions/procedures/). Local research cache: `.firecrawl/spacetimedb.com-docs-functions-procedures.md`.
29. **Economics:** [SpacetimeDB pricing](https://spacetimedb.com/pricing). Local research cache: `.firecrawl/spacetimedb.com-pricing.md`.
30. **Backend:** [SpacetimeDB repository/license](https://github.com/clockworklabs/SpacetimeDB). Local research cache: `.firecrawl/monetization-spacetimedb.json`.

## What is inference

The free-core/permanent-packs strategy, indicative Regun prices, proposed gauntlet/rail weapon designs, one-continue cap, backend service split, 20 Hz experiment, co-op upgrade policy and economic scenarios are recommendations. Sources establish that comparable products and underlying capabilities exist; they do not prove those choices will monetize Regun successfully.

## Local evidence

The currency/unlock/death-lifecycle findings refer to the repository state at research time. No monetization code was added in this pass. The existing release build remains the one installed earlier. Read `REGUN_MONETIZATION_AND_BACKEND_PLAN.md` for the implementation sequence and acceptance matrix.
