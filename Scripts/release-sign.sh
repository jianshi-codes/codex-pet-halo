#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"

release_require_command codesign
release_require_app
[[ -n "${DEVELOPER_ID_APPLICATION:-}" ]] \
    || release_fail "DEVELOPER_ID_APPLICATION must identify a Developer ID Application certificate"

codesign_keychain_args=()
if [[ -n "${RELEASE_KEYCHAIN_PATH:-}" ]]; then
    [[ -f "$RELEASE_KEYCHAIN_PATH" ]] \
        || release_fail "RELEASE_KEYCHAIN_PATH must reference an available Keychain file"
    codesign_keychain_args+=(--keychain "$RELEASE_KEYCHAIN_PATH")
fi

/usr/bin/xattr -cr "$release_app"
/usr/bin/codesign \
    "${codesign_keychain_args[@]}" \
    --force \
    --options runtime \
    --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$release_app/Contents/Frameworks/PetHaloCore.framework"
/usr/bin/codesign \
    "${codesign_keychain_args[@]}" \
    --force \
    --options runtime \
    --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$release_app"
/usr/bin/codesign "${codesign_keychain_args[@]}" --verify --deep --strict "$release_app"

echo "Release signing: Developer ID Application verified"
