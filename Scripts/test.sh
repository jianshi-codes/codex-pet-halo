#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly derived_data_path="${DERIVED_DATA_PATH:-$repository_root/DerivedData/Tests}"
cd "$repository_root"

./Scripts/generate.sh
xcodebuild \
    -project PetHalo.xcodeproj \
    -scheme PetHalo \
    -configuration Debug \
    -derivedDataPath "$derived_data_path" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    test
