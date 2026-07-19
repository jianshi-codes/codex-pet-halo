#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly configuration="${CONFIGURATION:-Debug}"
readonly derived_data_path="${DERIVED_DATA_PATH:-$repository_root/DerivedData}"
readonly app_bundle="$derived_data_path/Build/Products/$configuration/Pet Halo.app"
readonly info_plist="$app_bundle/Contents/Info.plist"
readonly executable="$app_bundle/Contents/MacOS/Pet Halo"

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

if [[ "$configuration" == "Release" ]]; then
    if ! executable_architectures="$(lipo -archs "$executable")"; then
        echo "error: unable to inspect Release executable architectures: $executable" >&2
        exit 1
    fi

    for required_architecture in arm64 x86_64; do
        if [[ " $executable_architectures " != *" $required_architecture "* ]]; then
            echo "error: Release executable must contain arm64 and x86_64; found: $executable_architectures" >&2
            exit 1
        fi
    done
    echo "Release executable architectures: $executable_architectures"
fi

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
