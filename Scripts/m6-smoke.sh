#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly smoke_temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pet-halo-m6-smoke.XXXXXX")"
readonly test_log="$smoke_temp_dir/m6-tests.log"
readonly live_log="$smoke_temp_dir/live.log"
chmod 700 "$smoke_temp_dir"
touch "$test_log" "$live_log"
chmod 600 "$test_log" "$live_log"
cleanup() { rm -rf "$smoke_temp_dir"; }
trap cleanup EXIT
cd "$repository_root"

echo "M6 live observation starts now and prints only sanitized outcomes."
echo "During the next 45 seconds: move Pet around the screen, Tuck Away, then Wake."
if ! xcrun swift "$repository_root/Tools/M6AdaptiveSmoke/main.swift" 45 >"$live_log" 2>&1; then
    echo "M6 smoke blocker: live read-only geometry observation did not complete" >&2
    exit 1
fi

required_live_lines=(
    'Accessibility permission: available'
    'Exact Codex process: found'
    'Exact Pet Halo process: found'
    'Saved Pet anchor: absent'
    'Pet target found: yes'
    'Automatic attachment: observed'
    'Center alignment: observed'
    'Independent Pet movement: observed'
    'Pet Tuck Away: observed'
    'Pet Wake: observed'
)
for required_line in "${required_live_lines[@]}"; do
    if ! grep -Fqx "$required_line" "$live_log"; then
        echo "M6 smoke blocker: $required_line" >&2
        exit 1
    fi
done

if ! ./Scripts/m6-tests.sh >"$test_log" 2>&1; then
    echo "M6 smoke blocker: deterministic adaptive-placement checks did not complete" >&2
    exit 1
fi

echo "Pet target found: pass"
echo "Saved Pet anchor absent: pass"
echo "Automatic attachment: direct pass"
echo "Pet/Halo center alignment: direct pass"
echo "Tuck Away and Wake: direct pass"
echo "Fine-tune and Reset-to-Automatic: deterministic pass"
echo "Compact click-through: deterministic pass"
echo "Expanded non-activation: deterministic pass"
echo "Observer, panel, and app-server shutdown: deterministic clean"

trap - EXIT
cleanup
