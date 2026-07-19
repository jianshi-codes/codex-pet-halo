#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly derived_data_path="${DERIVED_DATA_PATH:-$repository_root/DerivedData/M2Smoke}"
readonly app_bundle="$derived_data_path/Build/Products/Debug/Pet Halo.app"
readonly bundle_id="io.github.jianshicodes.PetHalo"
app_pid=""
child_pid=""

cleanup() {
    if [[ -n "$app_pid" ]] && kill -0 "$app_pid" 2>/dev/null; then
        /usr/bin/osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

cd "$repository_root"
if ! CONFIGURATION=Debug DERIVED_DATA_PATH="$derived_data_path" ./Scripts/build.sh >/dev/null 2>&1; then
    echo "Application build: unavailable" >&2
    exit 1
fi
if ! /usr/bin/open -n "$app_bundle" >/dev/null 2>&1; then
    echo "Application launch: unavailable" >&2
    exit 1
fi

for _ in {1..40}; do
    app_pid="$(pgrep -n -x 'Pet Halo' || true)"
    [[ -n "$app_pid" ]] && break
    sleep 0.25
done
if [[ -z "$app_pid" ]] || ! kill -0 "$app_pid" 2>/dev/null; then
    echo "Application launch: unavailable" >&2
    exit 1
fi

for _ in {1..60}; do
    child_pid="$(pgrep -P "$app_pid" -f 'codex.*app-server' | head -n 1 || true)"
    [[ -n "$child_pid" ]] && break
    sleep 0.25
done
if [[ -z "$child_pid" ]]; then
    echo "Owned app-server: unavailable" >&2
    exit 1
fi

if ! xcrun swift "$repository_root/Tools/AppSmokeInspector/main.swift" "$app_pid"; then
    echo "Application runtime inspection: unavailable" >&2
    exit 1
fi
/usr/bin/osascript -e "tell application id \"$bundle_id\" to quit"

for _ in {1..40}; do
    if ! kill -0 "$app_pid" 2>/dev/null; then
        break
    fi
    sleep 0.25
done
if kill -0 "$app_pid" 2>/dev/null; then
    echo "Application shutdown: unavailable" >&2
    exit 1
fi
if kill -0 "$child_pid" 2>/dev/null; then
    echo "Owned app-server shutdown: unavailable" >&2
    exit 1
fi

trap - EXIT
echo "Application launch: pass"
echo "Owned app-server: clean shutdown"
