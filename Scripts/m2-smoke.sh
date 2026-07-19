#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly derived_data_path="${DERIVED_DATA_PATH:-$repository_root/DerivedData/M2Smoke}"
readonly smoke_temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pet-halo-m2-smoke.XXXXXX")"
readonly test_log="$smoke_temp_dir/xcodebuild.log"
readonly smoke_report="$smoke_temp_dir/report.txt"
chmod 700 "$smoke_temp_dir"
touch "$test_log" "$smoke_report"
chmod 600 "$test_log" "$smoke_report"
cleanup() {
    rm -rf "$smoke_temp_dir"
}
trap cleanup EXIT
cd "$repository_root"

if ! ./Scripts/generate.sh >/dev/null 2>&1; then
    echo "Project generation: unavailable" >&2
    exit 1
fi
if ! /usr/bin/env PET_HALO_RUN_REAL_SMOKE=1 PET_HALO_SMOKE_REPORT_PATH="$smoke_report" xcodebuild \
    -project PetHalo.xcodeproj \
    -scheme PetHalo \
    -configuration Debug \
    -derivedDataPath "$derived_data_path" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    -only-testing:PetHaloCoreTests/RealCodexSmokeTests/testReadOnlyLocalIntegration \
    test >"$test_log" 2>&1; then
    if ! rg '^M2 smoke blocker:' "$smoke_report"; then
        echo "M2 smoke blocker: read-only Codex integration did not complete" >&2
    fi
    exit 1
fi
rg '^(Codex located:|Protocol version:|Handshake:|Rate-limit buckets:|Weekly capability:|Five-hour capability:|Account Usage capability:|Shutdown:)' "$smoke_report"

DERIVED_DATA_PATH="$derived_data_path" ./Scripts/m2-app-smoke.sh
trap - EXIT
cleanup
