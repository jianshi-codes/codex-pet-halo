#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly smoke_temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pet-halo-m5-smoke.XXXXXX")"
readonly test_log="$smoke_temp_dir/m5-tests.log"
readonly discovery_log="$smoke_temp_dir/discovery.log"
chmod 700 "$smoke_temp_dir"
touch "$test_log" "$discovery_log"
chmod 600 "$test_log" "$discovery_log"
cleanup() {
    rm -rf "$smoke_temp_dir"
}
trap cleanup EXIT
cd "$repository_root"

echo "Pet movement observation starts in 5 seconds."
sleep 5
echo "Move the visible Codex Pet independently during the next 10 seconds."
if ! xcrun swift "$repository_root/Tools/M5PetDiscovery/main.swift" \
    --observe-pet-target 10 >"$discovery_log" 2>&1; then
    echo "M5 smoke blocker: live read-only discovery did not complete" >&2
    exit 1
fi

required_lines=(
    'Accessibility permission: available'
    'Exact Codex process: found'
    'Codex standard window: resolved'
    'Route A Pet core resolution: unique'
    'Pet core independent movement: observed'
    'Codex standard window stationary: yes'
)
for required_line in "${required_lines[@]}"; do
    if ! grep -Fqx "$required_line" "$discovery_log"; then
        echo "M5 smoke blocker: $required_line" >&2
        exit 1
    fi
done

if ! ./Scripts/m5-tests.sh >"$test_log" 2>&1; then
    echo "M5 smoke blocker: deterministic Pet-following checks did not complete" >&2
    exit 1
fi

echo "Pet discovery route: Accessibility window"
echo "Pet target resolution: pass"
echo "Independent Pet movement: pass"
echo "Codex standard window stationary: pass"
echo "Pet-relative geometry: deterministic pass"
echo "Codex-window fallback: deterministic pass"
echo "Pet recovery: deterministic pass"
echo "Non-activation: deterministic pass"
echo "Observer shutdown: deterministic clean"
echo "Direct Pet loss/recovery, Codex restart, and panel interaction: recorded manual validation required"

trap - EXIT
cleanup
