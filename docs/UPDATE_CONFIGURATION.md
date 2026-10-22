# Regun update prompts

Regun checks the project's Telling version configuration when the home screen opens, and when the app resumes while home is visible. It does not interrupt a live run, the upgrade picker or another menu route. A remote check sends platform, installed version and installed build, with the project's SDK key. No crash reporting, session tracking or player analytics is enabled.

## What players see

- **Optional:** a charcoal/brass pixel panel with **Update** and **Later**. Later snoozes this exact version/build target for one day. A new target prompts again.
- **Required:** **Update required**, **Update**, and **Check again**. Back and taps outside cannot dismiss it. A successful check that lifts the requirement closes it. A failed retry retains the known requirement.
- **Current:** no prompt.
- **Offline or failed first check:** no prompt, and play remains available. The startup deadline is five seconds, including metadata and preferences. There is no permanent offline lock across relaunches: this remains an offline-capable game, not an online entitlement system.
- **Store launch fails:** the prompt remains with a brief retry message.

Copy stays brief. The dashboard's update message replaces the default sentence. Long messages scroll, including on compact landscape phones and with enlarged text.

Preview: [required-update panel](../build/test-previews/update-required.png).

## Set up the dashboard

Use the Regun project associated with the supplied key. Configure iOS and Android separately:

1. Set the minimum supported version and, if needed, minimum build. Either threshold can trigger an update in Telling 1.5.0. Builds should increase across releases.
2. Set the platform's actual listing URL: `https://apps.apple.com/.../id<APPLE_APP_ID>` for iOS; `https://play.google.com/store/apps/details?id=dev.kiishi.regun` for Android. While testing through Firebase App Distribution, the Android release share link (`https://appdistribution.firebase.google.com/testerapps/<app-id>/releases/<release-id>`) or short invite (`https://appdistribution.firebase.dev/i/<code>`) is also accepted. The Apple numeric app ID is different from the bundle identifier. Do not copy an example ID.
3. Choose optional or compulsory and enter a brief player-facing message.
4. Enable a requirement only when the corresponding update is available in that store. A TestFlight build is not a publicly available App Store update; use its invite link only for beta testing.

The adapter accepts HTTPS platform store listings, official iOS TestFlight invitations (`https://testflight.apple.com/join/<8-character-code>`) and Firebase App Distribution tester links for the Regun Android app. TestFlight and Firebase links are suitable for beta testers; use the public App Store/Play listing for production players. A missing or invalid store link does not suppress an update policy. A required prompt still blocks entry, shows a brief link-unavailable message and disables Update. Check again re-fetches configuration so adding the proper link restores the action. Optional prompts retain Later. Invalid URLs are never opened. The supplied key was checked against the live endpoint on 19 October 2026; iOS 1.0.0 build 4 initially returned `{"requiresUpdate":false}`. A later check returned a compulsory minimum build of 5 with an empty store URL; the missing-link suppression bug was corrected and covered by regression tests. The latest response now supplies the configured TestFlight invitation, and the adapter accepts that official beta destination.

## Builds and configuration

The key is stored locally in ignored `config/release.local.json`, not copied from Wolka or committed into the repository. This is an embedded mobile SDK project key, not an administrative credential. Keep administrative tokens out of this file.

```
flutter build ipa --release --export-method app-store --dart-define-from-file=config/release.local.json
flutter build ios --release --dart-define-from-file=config/release.local.json
```

`make buildIPA`, `make buildIOS`, `make buildAPK`, `make build` and `make runRelease` use the combined local release file when present, falling back to the older `config/telling.local.json`. See [release configuration](../config/README.md) for all service defines and the phone command. CI must provide the same file/defines. A build without a project key leaves release checks disabled. `TELLING_API_URL` can override the HTTPS API base; default is `https://telling-api.kiishi.space/api/v1`.

`telling_logger` is pinned to **1.5.0**. Its version-only helper is in an internal library, isolated in `AppUpdates`; full SDK initialization would also collect device/session data and start telemetry timers, contrary to this feature's scope. Review that adapter when updating the dependency. `package_info_plus` uses 9.x to satisfy the SDK's dependency range. Wolka's separate release-check/snooze approach was used as reference; its code and configuration were not changed. Package reference: https://pub.dev/packages/telling_logger#remote-config--force-update.

## Test on the phone

The installed candidate reports **v1.0.0 (4)**. The current live policy requires build 5, so this build-4 test candidate must show the required-update prompt. Its Update action accepts the configured TestFlight invite after installing the corrected code. The Transporter IPA is build 6; it meets the current minimum of 5 and should open normally. Clear/lower the minimum build and use Check again to return to the game.

For the direct build-4 phone test, use an actual store listing or official TestFlight invite, then temporarily set the iOS minimum build to **5**, with minimum version **1.0.0**:

1. Start with **optional**. Relaunch the app; check the panel, Update opening the correct listing, and Later allowing play. Relaunch again; the same target should be snoozed.
2. Make that target **compulsory**. Relaunch; it must appear despite the earlier snooze. Try Back, outside taps, retry and a failed store launch.
3. Raise the target build again while optional; an older target's snooze must not suppress it.
4. Restore minimum build to **4** (or clear it) and version **1.0.0**. Check again; the required panel should disappear.
5. Try startup offline, then return online. Play remains available after a failed startup check. While a known required prompt is visible, failed retries must not dismiss it.
6. Repeat with enlarged text and both landscape orientations.

These dashboard steps change remote behavior for every installed build using the project key. They were not performed automatically. Do not leave a higher compulsory target configured before a downloadable update exists.

Automated coverage includes request metadata, target-scoped snooze, forced override, malformed policies, invalid store links, offline startup, retry policy withdrawal, failed launch feedback, Back blocking and responsive panel rendering. Physical store navigation and dashboard configuration still require the real listing and device acceptance.
