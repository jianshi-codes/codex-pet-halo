#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly smoke_temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pet-halo-m3-smoke.XXXXXX")"
readonly test_log="$smoke_temp_dir/m3-tests.log"
chmod 700 "$smoke_temp_dir"
touch "$test_log"
chmod 600 "$test_log"
cleanup() {
    rm -rf "$smoke_temp_dir"
}
trap cleanup EXIT
cd "$repository_root"

if ! ./Scripts/m3-tests.sh >"$test_log" 2>&1; then
    echo "M3 smoke blocker: deterministic presentation checks did not complete" >&2
    exit 1
fi
echo "Expanded layout: deterministic pass"
echo "Optional capability gating: deterministic pass"
echo "Stale and unavailable states: deterministic pass"
./Scripts/m2-smoke.sh

echo "M3 deterministic presentation: pass"
echo "M3 authenticated Halo lifecycle: pass"

trap - EXIT
cleanup
