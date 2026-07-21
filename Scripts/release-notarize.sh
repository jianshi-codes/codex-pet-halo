#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"

release_require_command jq
release_require_command xcrun
release_require_app
release_require_archive
/usr/bin/codesign --verify --deep --strict "$release_app"

notary_credentials=()
if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    notary_credentials+=(--keychain-profile "$NOTARYTOOL_PROFILE")
    if [[ -n "${NOTARYTOOL_KEYCHAIN:-}" ]]; then
        notary_credentials+=(--keychain "$NOTARYTOOL_KEYCHAIN")
    fi
elif [[ -n "${APPLE_NOTARY_KEY_PATH:-}" \
    && -n "${APPLE_NOTARY_KEY_ID:-}" \
    && -n "${APPLE_NOTARY_ISSUER_ID:-}" ]]; then
    notary_credentials+=(
        --key "$APPLE_NOTARY_KEY_PATH"
        --key-id "$APPLE_NOTARY_KEY_ID"
        --issuer "$APPLE_NOTARY_ISSUER_ID"
    )
else
    release_fail "configure a notarytool Keychain profile or App Store Connect API key environment"
fi

notary_temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/pet-halo-notary.XXXXXX")"
chmod 700 "$notary_temp_dir"
notary_result="$notary_temp_dir/result.json"
cleanup() {
    rm -rf "$notary_temp_dir"
}
trap cleanup EXIT

/usr/bin/xcrun notarytool submit "$release_archive" \
    "${notary_credentials[@]}" \
    --wait \
    --output-format json >"$notary_result"
chmod 600 "$notary_result"
[[ "$(jq -r '.status // empty' "$notary_result")" == "Accepted" ]] \
    || release_fail "Apple notarization was not accepted"

/usr/bin/xcrun stapler staple "$release_app" >/dev/null
/usr/bin/xcrun stapler validate "$release_app" >/dev/null
"$release_repository_root/Scripts/release-archive.sh" >/dev/null
"$release_repository_root/Scripts/release-checksum.sh" >/dev/null
RELEASE_MODE=notarized "$release_repository_root/Scripts/release-verify.sh" >/dev/null

echo "Release notarization: Apple accepted and ticket stapled"
