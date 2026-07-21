#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"

release_require_command codesign
release_require_app
[[ -n "${DEVELOPER_ID_APPLICATION:-}" ]] \
    || release_fail "DEVELOPER_ID_APPLICATION must name a Developer ID Application identity"

/usr/bin/xattr -cr "$release_app"
/usr/bin/codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$release_app/Contents/Frameworks/PetHaloCore.framework"
/usr/bin/codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$release_app"
/usr/bin/codesign --verify --deep --strict "$release_app"

echo "Release signing: Developer ID Application verified"
