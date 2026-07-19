#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly derived_data_path="${DERIVED_DATA_PATH:-$repository_root/DerivedData/M2Smoke}"
readonly smoke_marker="/tmp/pet-halo-m2-real-smoke-enabled"
readonly test_log="/tmp/pet-halo-m2-real-smoke.log"
cleanup() {
    rm -f "$smoke_marker" "$test_log"
}
trap cleanup EXIT
cd "$repository_root"

if ! ./Scripts/generate.sh >/dev/null 2>&1; then
    echo "Project generation: unavailable" >&2
    exit 1
fi
touch "$smoke_marker"
if ! xcodebuild \
    -project PetHalo.xcodeproj \
    -scheme PetHalo \
    -configuration Debug \
    -derivedDataPath "$derived_data_path" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    -only-testing:PetHaloCoreTests/RealCodexSmokeTests/testReadOnlyLocalIntegration \
    test >"$test_log" 2>&1; then
    if ! rg '^M2 smoke blocker:' "$test_log"; then
        echo "M2 smoke blocker: read-only Codex integration did not complete" >&2
    fi
    exit 1
fi
rg '^(Codex located:|Protocol version:|Handshake:|Rate-limit buckets:|Weekly capability:|Five-hour capability:|Account Usage capability:|Shutdown:)' "$test_log"
rm -f "$smoke_marker"

DERIVED_DATA_PATH="$derived_data_path" ./Scripts/m2-app-smoke.sh
trap - EXIT
cleanup
