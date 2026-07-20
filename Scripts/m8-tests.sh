#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly derived_data_path="${DERIVED_DATA_PATH:-$repository_root/DerivedData/M8Tests}"
cd "$repository_root"

./Scripts/generate.sh
python3 Tests/test_m8_assets.py
xcodebuild \
    -project PetHalo.xcodeproj \
    -scheme PetHalo \
    -configuration Debug \
    -derivedDataPath "$derived_data_path" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    -only-testing:PetHaloTests/ApplicationCoordinatorTests \
    -only-testing:PetHaloTests/HaloAccessibilityTests \
    -only-testing:PetHaloTests/HaloPanelTests \
    -only-testing:PetHaloTests/PetRingPolishTests \
    -only-testing:PetHaloTests/PetRingPresentationMapperTests \
    -only-testing:PetHaloTests/PetTargetModelsTests \
    -only-testing:PetHaloTests/WindowFollowingModelsTests \
    -only-testing:PetHaloTests/WindowFollowingServiceTests \
    -only-testing:PetHaloTests/WindowFollowingSystemTests \
    test
