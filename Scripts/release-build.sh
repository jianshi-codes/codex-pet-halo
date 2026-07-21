#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"

release_require_command xcodebuild
release_require_command xcodegen
release_require_command lipo
release_require_command strip
release_require_clean_source

release_safe_reset_directory "$release_derived_data"
release_safe_reset_directory "$release_output_root/stage"

cd "$release_repository_root"
./Scripts/generate.sh >/dev/null
xcodebuild \
    -project PetHalo.xcodeproj \
    -scheme PetHalo \
    -configuration Release \
    -derivedDataPath "$release_derived_data" \
    -destination 'generic/platform=macOS' \
    ARCHS='arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$release_marketing_version" \
    CURRENT_PROJECT_VERSION="$release_build_number" \
    ENABLE_HARDENED_RUNTIME=YES \
    ENABLE_CODE_COVERAGE=NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    clean build >/dev/null

/usr/bin/ditto --noextattr --noqtn \
    "$release_derived_data/Build/Products/Release/Pet Halo.app" \
    "$release_app"

/usr/bin/strip -S \
    "$release_app/Contents/Frameworks/PetHaloCore.framework/Versions/A/PetHaloCore" \
    "$release_app/Contents/MacOS/Pet Halo"

EXPECTED_MARKETING_VERSION="$release_marketing_version" \
EXPECTED_BUILD_NUMBER="$release_build_number" \
CONFIGURATION=Release \
DERIVED_DATA_PATH="$release_derived_data" \
    ./Scripts/validate-bundle.sh >/dev/null

echo "Release build: unsigned universal application ready"
