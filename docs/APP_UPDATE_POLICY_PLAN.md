# Regun updates, maintenance, and announcements

## 1. Update settings

In Regun Admin, open **App updates → Updates** and select **Edit update**
under iOS, Android, or macOS. Each platform saves independently. The
production and beta channels keep separate settings.

- **Minimum version** and **Minimum build** are independent. A device below
  either configured number sees the update prompt. Leave a field blank to
  skip its check.
- **Require update** on blocks entry until the device meets both configured
  minimums. Off lets the player choose **Later**.
- **Update link** opens the store or distribution invite. A player message
  is optional. iOS supports the App Store and TestFlight. Android supports
  Google Play and short Firebase App Distribution invites.
- **Save** applies the edited platform's settings. Lower a minimum in the
  same form. Clear both minimums to turn off the prompt.

Production starts with iOS **1.0.1 (44)**, Android **1.0.0 (44)**, and macOS
**1.0.1 (43)** prefilled in the editor for platforms without a saved policy.
An existing policy remains in force until that platform is saved in the new
form. The game checks on Home entry and resume, and refreshes while Home
is visible. A failed refresh keeps a visible required prompt in place.

## 2. Announcements

Raising either minimum, or switching an active prompt from optional to
required, queues an announcement for eligible devices on that platform and
channel. Lowering or clearing a minimum, or editing the link or message,
uses the same Save action without queuing another announcement.

The announcement uses the same version and build comparison as the Home
prompt. Delivery respects notification permissions, player preferences, and
quiet hours. **Resend announcement** uses the current settings and audience.
View delivery attempts in **Notifications → App announcements**. Provider
acceptance can be checked there, and device receipt can be verified on the
physical device.

## 3. Maintenance

### Controls in Admin

Add **Maintenance** beside the platform update controls. Show an **All
platforms** switch and separate **iOS**, **Android**, **macOS**, and **Web**
switches. Each row shows the effective state and whether the global switch,
its platform switch, or both are keeping it in maintenance. The rule is
`effective maintenance = global switch OR platform switch`.

Review the affected platforms before applying a change. The review shows the
Home message, the estimated push audience for each supported platform, and
which platforms will only display the in-game gate. An optional operator
note belongs in the audit. Show the default player copy in the preview and
keep it editable as an override. Publishing a maintenance change updates the
gate immediately. A push failure leaves the gate in its published state.

| Change | Effective result |
| --- | --- |
| Enable a platform switch | That platform enters maintenance. |
| Enable **All platforms** | Every platform enters maintenance, including web. Platforms already in maintenance remain there. |
| Disable a platform switch while **All platforms** is on | That platform remains in maintenance. |
| Disable **All platforms** | Only platforms with their own switch still on remain in maintenance. |

Store global and per-platform settings independently from app versions. Apply
the switch change, effective transitions, audit entry, and announcement jobs
in one database operation. Use a revision check to prevent two operators or
browser tabs from overwriting each other's changes. Keep test environments
isolated from production settings and push audiences.

### Home gate on native and web

Use the forced-update panel's layout and accessibility behavior. The default
player copy is:

| Element | Copy |
| --- | --- |
| Heading | Maintenance in progress |
| Body | Regun is temporarily unavailable while we make improvements. |
| Failed recheck | Regun will keep checking for you. |

Maintenance takes precedence over an app update. The gate blocks Play,
Continue, Training, and Online from Home. Back, outside taps, keyboard
shortcuts, and deep links cannot enter a run while the gate is active. Runs
already in progress continue. When a player returns to Home, check again.
After maintenance clears, evaluate the latest version policy and show a
required update if it still applies.

Read maintenance through a lightweight Regun availability endpoint that
stays reachable while gameplay services are paused. Check on Home entry,
resume, and browser focus. Refresh periodically while Home is visible.
Keep a known active gate across reloads
and failed requests until the server confirms maintenance has ended.

The playable **web** entry waits for an authoritative availability check
before allowing game entry. If a fresh browser cannot reach the endpoint,
show **Can’t check game availability** with **Try again**. A valid inactive
response lets the player enter. A browser identifies itself as web even when
it runs on iOS or Android. Revalidate the availability response on reload so
a cached web build or service worker cannot reuse a stale inactive response.
On native, preserve offline play when no maintenance policy has ever been
received. A previously confirmed active gate remains until a successful
check clears it.

### Announcements in Notifications

Add maintenance to **Regun Admin → Notifications** with its own entries in
announcement history. When applying a change, **Send announcement** is on
by default for affected platforms with a push path. The operator can clear
it for a silent change. Preview the affected platforms and delivery type
before confirming.

| Effective change | Push title | Push body |
| --- | --- | --- |
| Available → Maintenance | Maintenance in progress | Regun is temporarily unavailable while we make improvements. |
| Maintenance → Available | Regun is back online | Maintenance is complete. You can play again. |

- Queue one job per affected platform and transition. An overlapping switch
  that leaves a platform's effective state unchanged queues nothing for it.
  Retrying the same Admin action never creates another job.
- Target the affected platform and channel. Maintenance applies regardless
  of app version. Honor OS permission and the in-app push master switch.
  The re-engagement rollout and Return reminders preference do not apply.
- Recheck effective maintenance before dispatch. If maintenance ends before
  the start notice can send, expire that job. Expire a queued restoration
  notice if maintenance restarts before it can send. Use the announcement
  history to show queued, accepted, expired, failed, and in-game-only results.
- **Resend maintenance notice** uses the current effective status and a
  fresh audience preview. Confirm it separately and apply the same resend
  protections as release announcements. A push tap opens Regun at Home and
  checks the latest state.
- Web must display the gate in the browser from the first release. The
  current plan treats web as **In-game banner only** in Notifications.
  Background browser push would need its own subscriptions and permission
  flow. Admin should never count web banner coverage as push delivery.

## 4. Telling cutover

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

## 5. Acceptance checklist

- [ ] Open iOS and Android editors from the same settings. Save both and
  confirm each platform keeps its own minimums.
- [ ] Set minimum build **45** and verify that **44** sees the prompt, including
  when its version is newer than the configured version. Verify a version
  below the minimum still prompts when its build meets the minimum.
- [ ] Toggle **Require update**, lower the minimum, and clear both fields.
  Verify **Later** for optional updates and automatic recovery at Home.
- [ ] Open the App Store, TestFlight, or Android distribution link on a device.
  Check compact landscape, large text, and desktop.
- [ ] Confirm a raised threshold sends to eligible opted-in installs only.
  Verify resend and provider status. Confirm lowering the threshold sends
  no new announcement.
- [ ] Test Web-only and global maintenance, overlap, offline recovery, and an
  active run. Confirm effective transitions are reflected in announcements.

See the [operations runbook](UPDATE_CONFIGURATION.md) for rollout steps.
