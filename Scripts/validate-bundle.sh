#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly configuration="${CONFIGURATION:-Debug}"
readonly derived_data_path="${DERIVED_DATA_PATH:-$repository_root/DerivedData}"
readonly app_bundle="$derived_data_path/Build/Products/$configuration/Pet Halo.app"
readonly info_plist="$app_bundle/Contents/Info.plist"

if [[ ! -d "$app_bundle" ]]; then
    echo "error: application bundle not found: $app_bundle" >&2
    exit 1
fi

assert_plist_value() {
    local key="$1"
    local expected="$2"
    local actual
    actual="$(/usr/libexec/PlistBuddy -c "Print :$key" "$info_plist")"
    if [[ "$actual" != "$expected" ]]; then
        echo "error: $key expected '$expected', found '$actual'" >&2
        exit 1
    fi
}

assert_plist_value CFBundleIdentifier io.github.jianshicodes.PetHalo
assert_plist_value CFBundleShortVersionString 0.1.0
assert_plist_value CFBundleVersion 1
assert_plist_value LSUIElement true
assert_plist_value LSMinimumSystemVersion 14.0

if find "$app_bundle" -type f \( \
    -name '*fixture*' -o \
    -name '*.json' -o \
    -name '*.ts' -o \
    -path '*/Schemas/*' -o \
    -path '*/CodexProtocol/*' \
\) | grep -q .; then
    echo "error: application bundle contains M0 schemas or fixtures" >&2
    exit 1
fi

echo "$configuration application bundle validated"
