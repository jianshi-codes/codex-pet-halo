#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

./Scripts/bootstrap.sh
./Scripts/generate.sh
if ! git diff --quiet -- PetHalo.xcodeproj; then
    echo "error: generated Xcode project differs from the committed project" >&2
    exit 1
fi
./Scripts/validate-source-boundaries.sh
./Scripts/privacy-scan.sh
CONFIGURATION=Debug ./Scripts/build.sh
CONFIGURATION=Debug ./Scripts/validate-bundle.sh
CONFIGURATION=Release ./Scripts/build.sh
CONFIGURATION=Release ./Scripts/validate-bundle.sh
./Scripts/test.sh
./Scripts/m0-tests.sh
git diff --check
