#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly derived_data_path="${DERIVED_DATA_PATH:-$repository_root/DerivedData/PetFollowingSmoke}"
readonly app_bundle="$derived_data_path/Build/Products/Debug/Pet Halo.app"
readonly bundle_id="io.github.jianshicodes.PetHalo"
readonly smoke_temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pet-halo-following-smoke.XXXXXX")"
readonly route_a_log="$smoke_temp_dir/route-a.log"
readonly live_log="$smoke_temp_dir/live.log"
chmod 700 "$smoke_temp_dir"
touch "$route_a_log" "$live_log"
chmod 600 "$route_a_log" "$live_log"
app_pid=""
route_a_pid=""
cleanup() {
    if [[ -n "$route_a_pid" ]] && kill -0 "$route_a_pid" 2>/dev/null; then
        kill -TERM "$route_a_pid" >/dev/null 2>&1 || true
        wait "$route_a_pid" >/dev/null 2>&1 || true
    fi
    if [[ -n "$app_pid" ]] && kill -0 "$app_pid" 2>/dev/null; then
        /usr/bin/osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null 2>&1 || true
    fi
    rm -rf "$smoke_temp_dir"
}
trap cleanup EXIT
cd "$repository_root"

if pgrep -x 'Pet Halo' >/dev/null 2>&1; then
    echo "Pet-following smoke blocker: quit any existing Pet Halo process before testing the current build" >&2
    exit 1
fi
if ! CONFIGURATION=Debug DERIVED_DATA_PATH="$derived_data_path" ./Scripts/build.sh >/dev/null 2>&1; then
    echo "Pet-following smoke blocker: current application build failed" >&2
    exit 1
fi
if ! /usr/bin/open -n "$app_bundle" >/dev/null 2>&1; then
    echo "Pet-following smoke blocker: current application launch failed" >&2
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
    echo "Pet-following smoke blocker: exactly one running Pet Halo process is required" >&2
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
    echo "Pet-following smoke blocker: the running app's owned app-server was not observed" >&2
    exit 1
fi

echo "Unified Pet-following observation starts now and prints only sanitized outcomes."
echo "Keep Pet visible. After 5 seconds, move Pet first; then Tuck Away, Wake, and Quit Pet Halo within 60 seconds."
echo "Confirm concentric Usage rings share one transparent center with no rectangular card; if activity appears, confirm it occupies the arc opening."
sleep 5
xcrun swift "$repository_root/Tools/M5PetDiscovery/main.swift" \
    --observe-pet-target 60 >"$route_a_log" 2>&1 &
route_a_pid="$!"
if ! xcrun swift "$repository_root/Tools/M6CenterLockSmoke/main.swift" 60 >"$live_log" 2>&1; then
    echo "Pet-following smoke blocker: live read-only Ring observation did not complete" >&2
    exit 1
fi
if ! wait "$route_a_pid"; then
    echo "Pet-following smoke blocker: Route A observation did not complete" >&2
    exit 1
fi
route_a_pid=""

required_route_a_lines=(
    'Accessibility permission: available'
    'Exact Codex process: found'
    'Codex standard window: resolved'
    'Route A Pet core resolution: unique'
    'Pet core independent movement: observed'
    'Codex standard window stationary: yes'
)
for required_line in "${required_route_a_lines[@]}"; do
    if ! grep -Fqx "$required_line" "$route_a_log"; then
        echo "Pet-following smoke blocker: $required_line" >&2
        exit 1
    fi
done

required_live_lines=(
    'Accessibility permission: available'
    'Exact Codex process: found'
    'Exact Pet Halo process: found'
    'Legacy Pet anchor: absent'
    'M4 window anchor: present'
    'Pet visible at start: yes'
    'Pet target found: yes'
    'Automatic attachment: observed'
    'Visual-center offset sample: observed'
    'Post-movement visual-center offset: observed'
    'Post-Wake visual-center offset: observed'
    'Visual-center offset maintained: yes'
    'Independent Pet movement: observed'
    'Pet Tuck Away: observed'
    'Codex-window fallback: observed'
    'Pet Wake: observed'
    'Pet Halo Quit: observed'
    'Pet Ring selected: observed'
    'Pet loss Halo hidden: observed'
    'Application remained inactive: yes'
)
for required_line in "${required_live_lines[@]}"; do
    if ! grep -Fqx "$required_line" "$live_log"; then
        echo "Pet-following smoke blocker: $required_line" >&2
        sed -n '1,100p' "$live_log" >&2
        exit 1
    fi
done

if kill -0 "$owned_app_server_pid" 2>/dev/null; then
    echo "Pet-following smoke blocker: the owned app-server remained after Quit" >&2
    exit 1
fi
app_pid=""

echo "Route A unique Pet target and stationary Codex window: direct pass"
echo "Automatic center-lock and visual-center persistence: direct pass"
echo "Independent movement, Tuck Away fallback, and Wake recovery: direct pass"
echo "Pet Ring selection, default hide, and non-activation: direct pass"
echo "Concentric rings, fallback cards, and activity orientation: live geometry pass"
echo "Observer, panel, and owned app-server shutdown: direct pass"
echo "Visual Pet containment, transparent center, complementary activity side, and no card: observer confirmation required"

trap - EXIT
cleanup
