# Regun app updates and release announcements

Draft for review · 12 November 2026

Regun Admin publishes an update for one platform. The Regun server becomes the
source of truth for that platform's update banner and queues its push
announcement. Admin can resend the current announcement to players who still
qualify.

## 1. Scope and current behavior

- Give **iOS, Android, and macOS** independent controls, version thresholds, and
  download links. This plan covers those three native distribution targets.
  The model can add other platforms with their own download and delivery
  support.
- Move the web build's iOS and Android download links to the Regun server as
  part of the Telling cutover. The browser continues to serve its deployed web
  build.
- Today [AppUpdates](../lib/services/app_updates.dart) calls Telling for iOS
  and Android. macOS reads the iOS policy using the Mac app's installed
  version. [AppUpdateGate](../lib/widgets/app_update_gate.dart) owns the Home
  banner, and [the web build script](../tool/refresh_web_store_links.py) reads
  Telling's mobile download links.
- Use the existing iOS and Android push delivery. Add native macOS APNs
  registration and delivery through the Regun server. The
  [OneSignal Flutter SDK](https://github.com/OneSignal/OneSignal-Flutter-SDK)
  covers iOS and Android. Apple documents separate registration and signing
  requirements in its [APNs registration guide](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns).

## 2. What the operator does

Add **App updates** to Regun Admin as its own destination. The landing screen
shows one row per platform with its published build, whether any players are
required to update, and the last announcement status. Selecting a row opens
that platform's editor.

### First publish

Pre-fill the first production draft for each platform from these confirmed
release baselines. Use these values even when a privately installed candidate
has a higher build number.

| Platform | Latest version | Build |
| --- | --- | --- |
| iOS | 1.0.1 | 44 |
| macOS | 1.0.1 | 43 |
| Android | 1.0.0 | 44 |

The **Update link** starts blank. It is the only field the operator needs to
enter before reviewing and publishing. The platform, production channel,
version, and build are already filled in. The minimum supported version starts
unset, so the first banner is optional. Regun generates the banner and push
copy from the platform and version. Operators can override the copy or set a
minimum when needed. Seeding drafts does not activate a policy or queue push.
The first confirmed publish queues the platform's announcement.

### Later releases

Pre-fill the next version and build from release metadata supplied by the
trusted build or distribution pipeline. A locally built or privately signed
artifact must never replace the production baseline automatically. Admin
shows the source and build before review, and the operator confirms that it
is available from the selected download destination. Carry forward the last
published minimum and update link. Ask for a fresh link when the previous
one points to a specific older build. Generate the default copy for the new
version.

1. **Save draft** prepares the update for review. Drafts never affect players.
2. **Review update** shows the platform, old and new builds, optional or
   required banner behavior, download destination, and estimated audience.
3. **Publish update** confirms the change. Admin shows the live policy and
   whether an announcement was queued or whether the edit only changed the
   banner.
4. **Resend announcement** previews the current audience again. Confirming
   creates a new send for the selected platform and current published update.
5. **History** shows who published or resent, the version, and the outcome.
   Use plain states such as **Queued**, **Accepted by push service**,
   **No eligible devices**, and **Failed**. Show a failure reason and keep
   provider acceptance distinct from confirmed device delivery.

On phones, the platform list opens one editor at a time. On tablets and Macs,
the list can sit alongside the editor. Keep announcement history collapsed
behind the current status. A failed request keeps the operator's draft and
offers retry. A stale editor must reload the current revision before it can
publish.

## 3. Update policy and player experience

Store versioned policies by **platform and distribution channel**. Production
and beta settings have separate histories and audiences. A client's release
channel comes from its build configuration. Never infer it from a store URL,
version number, or operating system alias. Confirm the actual production and
beta destinations before seeding. Disable push for a beta channel until the
server can reliably identify its registered installs.

Compare numeric version components, then the numeric build when versions
match. Validate a complete version and build pair for each threshold. The
minimum must be at or below the latest build. Use the same comparison in the
banner decision and notification audience. Unknown installed versions should
be skipped for targeted push. A malformed client version must not receive a
required-update decision.

Expose a small public, read-only update check on the Regun identity origin.
The request carries platform, channel, installed version, and build. It
requires neither an account nor a Telling key. The server returns the active
revision, the target and download link, and a current, optional, or required
decision. Use authenticated Admin routes for all writes and retain a revision
history. Validate platform-specific HTTPS destinations on publication and
again before the client opens them. An invalid or unavailable destination
must block publishing a new required policy.

Keep the existing Home experience.

- Check when Home opens or resumes, with the existing bounded request and
  passive checking state. Keep gameplay and other routes uninterrupted.
- Optional updates retain **Update** and **Later**. A snooze lasts one day and
  matches the platform, channel, and target build. A required update overrides
  a snooze.
- Required updates retain **Update** and **Check again**. A failed first check
  permits offline play. A failed retry leaves a known required prompt in
  place for that session. A valid response that lowers or withdraws the
  requirement clears it. A failed download launch keeps the prompt and offers
  retry.
- A notification tap returns to the update flow at Home and checks current
  policy. It must neither interrupt combat nor launch an old download URL
  embedded in a notification. A player who already updated sees no prompt.

## 4. Automatic push and resend

| Published change | Automatic announcement |
| --- | --- |
| First confirmed publish for a platform and channel | One release announcement for eligible installs below the seeded build. |
| Latest build increases | One release announcement for eligible installs below that build. |
| Minimum increases and latest stays the same | One required-update notice for eligible installs newly below the minimum. |
| Latest and minimum increase together | One release announcement for eligible installs below latest. The in-game policy determines who must update. |
| Draft save, copy or link edit, import, rollback, or lowered minimum | Banner policy only. |

Save the policy revision and insert the announcement job atomically. Give the
automatic job a unique key derived from platform, channel, and published
revision. Publishing twice through a retry must create only one job. A failed
push does not undo the update policy.

Reuse the notification worker and audit trail with an app-update message type.
Queue immediately after publishing and dispatch when the existing notification
quiet-hours policy permits it. Before dispatch, check that the update is still
current and re-resolve the eligible audience. Cancel superseded jobs. Respect
OS permission, subscription availability, and the in-app push master switch.
The **Return reminders** preference and re-engagement rollout apply to
recurring reminders. Publishing an app update is the operator's explicit send
decision.

Resolve the target platform and channel before deduplicating recipients. Pick
one eligible install per owner on that platform and channel. An account's iPhone
must never win selection for an Android update. Use each install's last
reported version and refresh registration on upgrades. A device that upgraded
without reconnecting can have an older reported version, so every notification
tap checks the latest policy again.

**Resend announcement** is a separate, confirmed send for the current update.
Use a new request ID for a deliberate resend and reuse it for retries of that
action. Apply a send cap and recheck eligibility. If the published revision
changes after the preview, require a fresh preview. Retain the original
announcement and the resend as separate audit entries. Record an ambiguous
provider result as unconfirmed and apply provider-specific retry handling to
avoid duplicate sends.

For macOS, validate signed release entitlements, register through APNs, and
associate the token with the Mac install and its reported build. Keep push
credentials on the server. Use the same targeting, permission checks, and
Admin history for all three platforms.

## 5. Telling cutover

1. Seed the three confirmed platform baselines as unpublished drafts with
   blank links. Review the old Telling policies for legacy-client continuity.
   Keep its current minimums and links separate from the new drafts.
2. Deploy the Regun update API, Admin editor, and notification worker. Check
   the migration against a copy of existing data and exercise all three
   platforms in an isolated test environment.
3. Ship clients that read the Regun API and switch the web store-link build.
   Keep Telling available for older binaries that still call it. Keep its
   legacy upgrade path reachable while players migrate.
4. Once the replacement is verified, remove Telling from new builds and their
   configuration. Retire the legacy service after confirming which old
   binaries still need it.

## 6. Joint acceptance checklist

For each check, record the environment, platform, installed build, policy
revision, expected result, observed result, and evidence in the review.

- [ ] **Independent platforms.** Publish an Android update. iOS and macOS keep
  their prior policies and receive no Android announcement. Repeat for iOS
  and macOS, including one account signed in on multiple platforms.
- [ ] **First-publish form.** Each platform shows the exact seeded version
  and build. Enter only its update link, review the generated copy and
  optional banner, then publish. Verify that loading the drafts queues
  nothing and that a private build never changes the production baseline.
- [ ] **Banner decisions.** On each physical device, test a build below
  minimum, a build between minimum and latest, and the latest build. Check
  the destination, Later, Check again, and a rollback that clears a required
  prompt. Include phone landscape, enlarged text, and a resized Mac window.
- [ ] **First publish.** One version publication creates one announcement.
  Retrying the same publish and changing banner copy or link create no
  additional send. A staging or beta update reaches only its own audience.
- [ ] **Push receipt.** A physical iPhone, Android phone, and signed Mac release
  each receive the correct announcement. A current build, opted-out device,
  and device on another platform receive none. Confirm the tap on warm and
  cold app launches and verify that an active run stays uninterrupted.
- [ ] **Resend.** Install the new build on one test device, report its new
  version, then resend. Only the still-outdated eligible device receives it.
  Confirm the new audit entry and try a stale preview.
- [ ] **Failure and recovery.** Simulate a lost response after publishing,
  provider failure, invalid download link, stale Admin revision, and a
  superseded queued notification. Confirm the policy, queue, and history
  remain consistent. Check offline Home and a failed retry on a visible
  required prompt.
- [ ] **Cutover.** A new build reads Regun, an older build still checks Telling,
  and the web download page resolves the correct iOS and Android links.

## 7. Decisions to confirm in review

- iOS, Android, and macOS are the initial native distribution targets.
- First publish, a newer build, or a raised minimum automatically queues an
  announcement. Drafts and copy-only edits leave delivery unchanged.
- Announcements respect quiet hours. Admin shows when a send is queued.
- Confirm the real Mac distribution link and signed build that will be used
  for physical APNs acceptance.
