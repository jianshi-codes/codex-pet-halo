#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly derived_data_path="${DERIVED_DATA_PATH:-$repository_root/DerivedData/M7Smoke}"
readonly app_bundle="$derived_data_path/Build/Products/Debug/Pet Halo.app"
readonly bundle_id="io.github.jianshicodes.PetHalo"
readonly smoke_temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pet-halo-m7-smoke.XXXXXX")"
readonly test_log="$smoke_temp_dir/m7-tests.log"
readonly live_log="$smoke_temp_dir/live.log"
chmod 700 "$smoke_temp_dir"
touch "$test_log" "$live_log"
chmod 600 "$test_log" "$live_log"
app_pid=""
cleanup() {
    if [[ -n "$app_pid" ]] && kill -0 "$app_pid" 2>/dev/null; then
        /usr/bin/osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null 2>&1 || true
    fi
    rm -rf "$smoke_temp_dir"
}
trap cleanup EXIT
cd "$repository_root"

if pgrep -x 'Pet Halo' >/dev/null 2>&1; then
    echo "M7 smoke blocker: quit any existing Pet Halo process before testing the current build" >&2
    exit 1
fi
if ! CONFIGURATION=Debug DERIVED_DATA_PATH="$derived_data_path" ./Scripts/build.sh >/dev/null 2>&1; then
    echo "M7 smoke blocker: current application build failed" >&2
    exit 1
fi
if ! /usr/bin/open -n "$app_bundle" >/dev/null 2>&1; then
    echo "M7 smoke blocker: current application launch failed" >&2
    exit 1
fi

pet_halo_pids=()
for _ in {1..40}; do
    pet_halo_pids=()
    while IFS= read -r pet_halo_pid; do
        pet_halo_pids+=("$pet_halo_pid")
    done < <(pgrep -x 'Pet Halo' || true)
    [[ ${#pet_halo_pids[@]} -eq 1 ]] && break
    sleep 0.25
done
if [[ ${#pet_halo_pids[@]} -ne 1 ]]; then
    echo "M7 smoke blocker: exactly one running Pet Halo process is required" >&2
    exit 1
fi
app_pid="${pet_halo_pids[0]}"

owned_app_server_pid=""
for _ in {1..60}; do
    owned_app_server_pid="$(pgrep -P "$app_pid" -f 'codex.*app-server' | head -n 1 || true)"
    [[ -n "$owned_app_server_pid" ]] && break
    sleep 0.25
done
if [[ -z "$owned_app_server_pid" ]]; then
    echo "M7 smoke blocker: the running app's owned app-server was not observed" >&2
    exit 1
fi

echo "M7 live observation starts now and prints only sanitized outcomes."
echo "Keep Pet visible and confirm the ring has a transparent center with no rectangular card."
echo "Then move Pet, Tuck Away, Wake, and Quit Pet Halo during the observation window."
sleep 5
if ! xcrun swift "$repository_root/Tools/M6CenterLockSmoke/main.swift" 60 >"$live_log" 2>&1; then
    echo "M7 smoke blocker: live read-only Pet Ring observation did not complete" >&2
    exit 1
fi

required_live_lines=(
    'Accessibility permission: available'
    'Exact Codex process: found'
    'Exact Pet Halo process: found'
    'Pet visible at start: yes'
    'Pet target found: yes'
    'Automatic attachment: observed'
    'Center alignment maintained: yes'
    'Independent Pet movement: observed'
    'Pet Tuck Away: observed'
    'Codex-window fallback: observed'
    'Pet Wake: observed'
    'Pet Halo Quit: observed'
    'Pet Ring selected: observed'
    'Fallback card restored: observed'
    'Application remained inactive: yes'
)
for required_line in "${required_live_lines[@]}"; do
    if ! grep -Fqx "$required_line" "$live_log"; then
        echo "M7 smoke blocker: $required_line" >&2
        sed -n '1,100p' "$live_log" >&2
        exit 1
    fi
done

if kill -0 "$owned_app_server_pid" 2>/dev/null; then
    echo "M7 smoke blocker: the owned app-server remained after Quit" >&2
    exit 1
fi
app_pid=""

if ! ./Scripts/m7-tests.sh >"$test_log" 2>&1; then
    echo "M7 smoke blocker: deterministic Pet Ring checks did not complete" >&2
    exit 1
fi

echo "Pet Ring target selection: direct pass"
echo "Pet/Halo center alignment and independent movement: direct pass"
echo "Tuck Away fallback and Wake recovery: direct pass"
echo "Transparent center and card-background exclusion: deterministic pass"
echo "Weekly, optional 5h, and Today token gating: deterministic pass"
echo "Pet Ring click-through and non-activation: deterministic/direct pass"
echo "Fallback cards and Expanded rejection on Pet: deterministic pass"
echo "Observer, panel, and owned app-server shutdown: direct pass"
echo "Visual Pet visibility and no rectangular card: observer confirmation required"

trap - EXIT
cleanup
