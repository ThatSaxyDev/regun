# Release build configuration

`release.local.json` is the ignored, combined configuration for phone and store
builds. The existing local Telling project key has been preserved there. On a
fresh checkout, copy `release.example.json` to `release.local.json`, then supply
the Regun Telling project key. This is the embedded SDK project key; Sendbyte,
Resend, signing and administrative secrets belong only on the backend.

Run on a connected iPhone:

```sh
make runRelease DEVICE=00008101-000248EC1450001E
```

Use `flutter devices` to find a different device ID. Equivalent Flutter command:

```sh
flutter run --release --dart-define-from-file=config/release.local.json -d 00008101-000248EC1450001E
```

`make buildIOS`, `make buildIPA`, `make buildAPK` and `make build` read the same
file. Override with `RELEASE_CONFIG=path/to/config.json` if needed. Older checkouts
with only `config/telling.local.json` remain supported by the Make targets.

- `TELLING_PROJECT_KEY` / `TELLING_API_URL`: existing release/update checks.
- `REGUN_SERVER_HOST`: multiplayer hostname, without `https://`.
- `REGUN_DATABASE` / `REGUN_SERVER_TLS`: database and TLS selection.
- `REGUN_IDENTITY_URL`: HTTPS origin of the email/account service, without a path.
  Leave empty until that service is deployed. This is separate from Telling and
  the multiplayer socket. Never substitute the Sendbyte API URL.

On 22 October 2026, `https://regunserver.kiishi.space/` and `/health` returned 200,
and `/features` reported online play enabled. Its root OIDC discovery endpoint
returned 403, consistent with the current multiplayer-only proxy configuration;
this does not establish a working account service at that origin. Offline play
does not require an identity URL.
