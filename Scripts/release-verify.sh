#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"

readonly release_mode="${RELEASE_MODE:-unsigned}"
case "$release_mode" in
    unsigned|signed|notarized) ;;
    *) release_fail "RELEASE_MODE must be unsigned, signed, or notarized" ;;
esac

release_require_command ditto
release_require_command lipo
release_require_command codesign
release_require_archive

verify_developer_id_and_runtime() {
    /usr/bin/codesign --verify --deep --strict "$extracted_app"
    /usr/bin/codesign -dv --verbose=4 "$extracted_app" 2>&1 \
        | grep -Fq 'Authority=Developer ID Application:' \
        || release_fail "application is not signed with Developer ID Application"
    /usr/bin/codesign -dv --verbose=4 "$extracted_app" 2>&1 \
        | grep -Eq 'flags=.*runtime' \
        || release_fail "signed application does not use hardened runtime"
}

verify_temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pet-halo-release-verify.XXXXXX")"
chmod 700 "$verify_temp_dir"
cleanup() {
    rm -rf "$verify_temp_dir"
}
trap cleanup EXIT

/usr/bin/ditto -x -k "$release_archive" "$verify_temp_dir"
extracted_app="$verify_temp_dir/Pet Halo.app"
[[ -d "$extracted_app" ]] || release_fail "archive did not contain one top-level Pet Halo application"
[[ "$(find "$verify_temp_dir" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" == "1" ]] \
    || release_fail "archive contains unexpected top-level entries"

info_plist="$extracted_app/Contents/Info.plist"
executable="$extracted_app/Contents/MacOS/Pet Halo"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist")" \
    == "io.github.jianshicodes.PetHalo" ]] || release_fail "bundle identifier mismatch"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")" \
    == "$release_marketing_version" ]] || release_fail "marketing version mismatch"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist")" \
    == "$release_build_number" ]] || release_fail "build number mismatch"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$info_plist")" \
    == "14.0" ]] || release_fail "minimum macOS version mismatch"

architectures="$(lipo -archs "$executable")"
for required_architecture in arm64 x86_64; do
    [[ " $architectures " == *" $required_architecture "* ]] \
        || release_fail "release executable is missing $required_architecture"
done

[[ -f "$extracted_app/Contents/Resources/Assets.car" ]] \
    || release_fail "compiled icon assets are unavailable"
if find "$extracted_app" -type f \( \
    -iname '*fixture*' -o \
    -iname '*smoke*' -o \
    -iname '*report*' -o \
    -iname '*.py' -o \
    -iname '*.json' -o \
    -iname '*.ts' \
\) | grep -q .; then
    release_fail "release bundle contains test, schema, fixture, smoke, or report material"
fi
if LC_ALL=C grep -aERl '/Users/[A-Za-z0-9._-]+/' "$extracted_app" >/dev/null 2>&1; then
    release_fail "release bundle contains a machine-specific user path"
fi

case "$release_mode" in
    unsigned)
        if /usr/bin/codesign --verify --deep --strict "$extracted_app" >/dev/null 2>&1; then
            release_fail "unsigned verification received a signed application"
        fi
        ;;
    signed)
        verify_developer_id_and_runtime
        ;;
    notarized)
        verify_developer_id_and_runtime
        /usr/bin/xcrun stapler validate "$extracted_app" >/dev/null
        /usr/sbin/spctl --assess --type execute "$extracted_app" >/dev/null
        ;;
esac

echo "Release verification: $release_mode artifact passed"
