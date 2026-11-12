# Release build configuration

Copy `release.example.json` to the ignored `release.local.json`. Use
`RELEASE_CONFIG=path/to/config.json` to select another file in the Make targets.

- `REGUN_SERVER_HOST`, `REGUN_DATABASE` and `REGUN_SERVER_TLS` select multiplayer.
- `REGUN_IDENTITY_URL` is the HTTPS origin for accounts, app availability and
  announcements. Use the same environment for the game and Admin.
- `REGUN_RELEASE_CHANNEL` is `production` by default. Set it to `beta` in
  separately distributed test builds. Policies and announcements are independent.
- `ONESIGNAL_APP_ID` is the public iOS and Android push app ID. Keep provider
  secrets in the server environment.

Run on a connected iPhone with `make runRelease DEVICE=<device-id>`. Find the
device ID with `flutter devices`. The same config is used by `make buildIOS`,
`make buildIPA`, `make buildAPK` and `make build`. See the
[update and maintenance runbook](../docs/UPDATE_CONFIGURATION.md) for server
setup, Mac signing and live verification.
