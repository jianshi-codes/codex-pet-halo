#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly smoke_temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pet-halo-m4-smoke.XXXXXX")"
readonly test_log="$smoke_temp_dir/m4-tests.log"
chmod 700 "$smoke_temp_dir"
touch "$test_log"
chmod 600 "$test_log"
cleanup() {
    rm -rf "$smoke_temp_dir"
}
trap cleanup EXIT
cd "$repository_root"

if ! ./Scripts/m4-tests.sh >"$test_log" 2>&1; then
    echo "M4 smoke blocker: deterministic window-following checks did not complete" >&2
    exit 1
fi

echo "Free-floating fallback: deterministic pass"
echo "Process and target selection: deterministic pass"
echo "Coordinate conversion: deterministic pass"
echo "Calibration and persistence: deterministic pass"
echo "Move and resize following: deterministic pass"
echo "Multi-display containment: deterministic pass"
echo "Non-activation: deterministic pass"
echo "Observer shutdown: deterministic clean"

xcrun swift "$repository_root/Tools/M4WindowSmoke/main.swift"
./Scripts/m2-smoke.sh

echo "Manual calibration, physical move/resize, and focus observation: required"

trap - EXIT
cleanup
