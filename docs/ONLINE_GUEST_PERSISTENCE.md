# Repeated rejected guests — 21 October 2026

In-place installs retain the endpoint-specific native Keychain credential. The
physical iPhone check confirmed both the saved and archived guests were still
present, neither expired, yet the hosted server rejected them. A new guest from
the same issuer connected. The probe used in-memory copies and verified the saved
credential remained unchanged. The normal release build10 was restored in-place
and successfully launched after diagnosis.

See `docs/validation/online-guest-phone-2026-10-21.json` for the credential-free
report. No token, identity, signature or raw claims are recorded. Do not silently
clear rejected guests or automatically create replacements.

Isolated backend Docker tests preserve the same guest across container replacement
with the same named volume. A replacement state/signing-key volume reproduces
rejection; fresh connectivity remains available. This is strong evidence for
investigating server signing-key continuity, not proof of the actual production
mount configuration.

Backend `deploy/ensure_identity.sh` now guards existing state against missing,
corrupt, mismatched or changed signing keys, with a recorded public-key fingerprint.
All-empty replacement volumes still look like first startup, so this safeguard
cannot replace correct persistent storage. See the sibling server's
`docs/GUEST_IDENTITY_PERSISTENCE.md` for tests and the state-preserving repair.

Production status: Dokploy's actual mount is unverified; configured SSH access is
unavailable. No guest-related server rollout has been triggered pending storage
inspection. Inspect the existing source for `/var/lib/regun`; preserve its complete
data/keys/CLI volume before changing mounts. An empty replacement named volume
would discard continuity. Earlier rejected identities require their original
signing key/trust to be recovered; a client cannot mint that identity safely.

Acceptance still required: an existing guest survives a real hosted redeployment
using verified persistent storage, plus relaunch/in-place update/reconnect. The
local replacement test does not establish production acceptance.
