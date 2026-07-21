#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"

release_require_archive
if pgrep -x 'Pet Halo' >/dev/null 2>&1; then
    release_fail "quit any existing Pet Halo process before release launch verification"
fi

launch_temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pet-halo-release-launch.XXXXXX")"
chmod 700 "$launch_temp_dir"
launch_user_root="$launch_temp_dir/isolated-user"
launch_diagnostic="$launch_temp_dir/bridge-diagnostic"
mkdir -m 700 "$launch_user_root"
app_pid=""
child_pid=""
release_fail_missing_child() {
    local diagnostic
    diagnostic="$(tr -d '\r\n' < "$launch_diagnostic" 2>/dev/null || true)"
    case "$diagnostic" in
        executable-unavailable)
            release_fail "owned app-server unavailable: Codex executable unavailable"
            ;;
        version-blocked)
            release_fail "owned app-server unavailable: Codex CLI version blocked"
            ;;
        runtime-incompatible)
            release_fail "owned app-server unavailable: Codex CLI runtime incompatible"
            ;;
        *)
            release_fail "owned app-server unavailable: generic child-start timeout"
            ;;
    esac
}
cleanup() {
    if [[ -n "$app_pid" ]] && kill -0 "$app_pid" >/dev/null 2>&1; then
        /usr/bin/osascript -e 'tell application id "io.github.jianshicodes.PetHalo" to quit' \
            >/dev/null 2>&1 || kill -TERM "$app_pid" >/dev/null 2>&1 || true
    fi
    rm -rf "$launch_temp_dir"
}
trap cleanup EXIT

/usr/bin/ditto -x -k "$release_archive" "$launch_temp_dir"
launch_app="$launch_temp_dir/Pet Halo.app"
CFFIXED_USER_HOME="$launch_user_root" \
    PET_HALO_RELEASE_SMOKE_DIAGNOSTIC_PATH="$launch_diagnostic" \
    "$launch_app/Contents/MacOS/Pet Halo" >/dev/null 2>&1 &
app_pid="$!"

for _ in {1..40}; do
    if kill -0 "$app_pid" >/dev/null 2>&1; then
        break
    fi
    sleep 0.25
done
kill -0 "$app_pid" >/dev/null 2>&1 || release_fail "release application did not launch"

for _ in {1..60}; do
    child_pid="$(pgrep -P "$app_pid" -f 'codex.*app-server' | head -n 1 || true)"
    [[ -n "$child_pid" ]] && break
    sleep 0.25
done
if [[ -z "$child_pid" ]]; then
    release_fail_missing_child
fi
sleep 1
kill -0 "$child_pid" >/dev/null 2>&1 || release_fail_missing_child

/usr/bin/osascript -e 'tell application id "io.github.jianshicodes.PetHalo" to quit'
for _ in {1..40}; do
    if ! kill -0 "$app_pid" >/dev/null 2>&1; then
        break
    fi
    sleep 0.25
done
! kill -0 "$app_pid" >/dev/null 2>&1 || release_fail "release application did not quit"
! kill -0 "$child_pid" >/dev/null 2>&1 || release_fail "owned app-server remained after quit"

app_pid=""
trap - EXIT
rm -rf "$launch_temp_dir"
echo "Release isolated clean-preferences launch and shutdown: pass"
