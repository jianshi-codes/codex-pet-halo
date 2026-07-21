#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"

release_require_command shasum
release_require_app
release_require_archive
[[ -f "$release_notes_source" ]] || release_fail "release notes are unavailable for $release_tag"

/usr/bin/ditto --noextattr --noqtn "$release_notes_source" "$release_notes"

signing_state="unsigned"
if /usr/bin/codesign --verify --deep --strict "$release_app" >/dev/null 2>&1 \
    && /usr/bin/codesign -dv --verbose=4 "$release_app" 2>&1 \
        | grep -Fq 'Authority=Developer ID Application:'; then
    signing_state="developer-id"
fi
notarization_state="not-submitted"
if /usr/bin/xcrun stapler validate "$release_app" >/dev/null 2>&1; then
    notarization_state="stapled"
fi
source_commit="$(git -C "$release_repository_root" rev-parse HEAD)"

printf '%s\n' \
    '{' \
    '  "product": "Pet Halo",' \
    "  \"version\": \"$release_marketing_version\"," \
    "  \"build\": \"$release_build_number\"," \
    "  \"tag\": \"$release_tag\"," \
    '  "bundleIdentifier": "io.github.jianshicodes.PetHalo",' \
    '  "minimumMacOS": "14.0",' \
    '  "architectures": ["arm64", "x86_64"],' \
    "  \"signing\": \"$signing_state\"," \
    "  \"notarization\": \"$notarization_state\"," \
    "  \"sourceCommit\": \"$source_commit\"" \
    '}' >"$release_manifest"

(
    cd "$release_output_root"
    readonly public_release_assets=(
        "$(basename "$release_archive")"
        "$(basename "$release_manifest")"
        "$(basename "$release_notes")"
    )
    shasum -a 256 "${public_release_assets[@]}" >"$(basename "$release_checksums")"
)

echo "Release checksums: $(basename "$release_checksums")"
grep -F "  $(basename "$release_archive")" "$release_checksums"
