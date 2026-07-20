#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly derived_data_path="${DERIVED_DATA_PATH:-$repository_root/DerivedData/M8Smoke}"
cd "$repository_root"

DERIVED_DATA_PATH="$derived_data_path" ./Scripts/m8-tests.sh >/dev/null
CONFIGURATION=Debug DERIVED_DATA_PATH="$derived_data_path" ./Scripts/build.sh >/dev/null
CONFIGURATION=Debug DERIVED_DATA_PATH="$derived_data_path" ./Scripts/validate-bundle.sh

echo "Light/dark and accessibility appearance policies: deterministic pass"
echo "Appearance-aware capsule identity contrast: deterministic pass"
echo "Visible-frame edge containment and negative displays: deterministic pass"
echo "Dialog opening and capsule-side separation: deterministic pass"
echo "Reduce Motion direct following and normal follower: deterministic pass"
echo "Optional metric and large-text layouts: deterministic pass"
echo "Original AppIcon and template menu-bar asset configuration: deterministic pass"
echo "Finder, Dock, menu-bar, system-setting, and live Pet behavior: observer confirmation required"
