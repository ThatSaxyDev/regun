#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 || $1 == "$2" ]]; then
  echo "Usage: $0 HOST_SIM_UDID PEER_SIM_UDID DEFINES_JSON [breach|foundry]" >&2
  exit 2
fi

cd "$(dirname "$0")/../.."
host=$1
peer=$2
defines=$3
map=${4:-ossuary_cross_1v1}
bundle=dev.kiishi.regun
output=$(mktemp -d "${TMPDIR:-/tmp}/regun-versus.XXXXXX")
echo "Probe artifacts: $output"

for role in host peer; do
  device=${!role}
  app=$(xcrun simctl get_app_container "$device" "$bundle" app)
  ditto "$app" "$output/$role.app"
done

flutter build ios --simulator --debug --no-pub \
  --dart-define-from-file="$defines" \
  --dart-define=REGUN_HOSTED_VERSUS_PROBE=true \
  --dart-define=REGUN_HOSTED_PROBE_MAP="$map" \
  -t tool/multiplayer/versus_probe.dart >"$output/build.log" 2>&1 || {
    tail -30 "$output/build.log" >&2
    exit 1
  }

restore() {
  for role in host peer; do
    device=${!role}
    xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
    xcrun simctl install "$device" "$output/$role.app" &&
      xcrun simctl launch "$device" "$bundle" ||
      echo "Restore failed for $role. Backup: $output/$role.app" >&2
  done
}
trap restore EXIT

for role in host peer; do
  device=${!role}
  xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
  xcrun simctl install "$device" build/ios/iphonesimulator/Runner.app
  container=$(xcrun simctl get_app_container "$device" "$bundle" data)
  mkdir -p "$container/Documents"
  printf '%s' "$role" >"$container/Documents/regun-net-role"
  result="$container/Documents/regun-versus-result.json"
  if [[ -e "$result" ]]; then mv "$result" "$output/$role-previous.json"; fi
  printf '%s' "$result" >"$output/$role.path"
done

xcrun simctl launch "$host" "$bundle"
xcrun simctl launch "$peer" "$bundle"
deadline=$((SECONDS + 120))
while (( SECONDS < deadline )); do
  if [[ -s "$(cat "$output/host.path")" && -s "$(cat "$output/peer.path")" ]]; then
    for role in host peer; do
      cp "$(cat "$output/$role.path")" "$output/$role-result.json"
    done
    python3 - "$output" <<'PY'
import json
from pathlib import Path
import sys

folder = Path(sys.argv[1])
passed = True
for role in ('host', 'peer'):
    result = json.loads((folder / f'{role}-result.json').read_text())
    print(role, {key: value for key, value in result.items() if key not in ('trials', 'tickTrace', 'observedTicks')})
    passed &= result.get('status') == 'passed' and result.get('leftRoom') is True
raise SystemExit(0 if passed else 1)
PY
    exit
  fi
  sleep 1
done
echo "Timed out waiting for both reports. See $output." >&2
exit 1
