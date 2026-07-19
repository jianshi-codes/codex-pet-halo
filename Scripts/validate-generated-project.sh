#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

./Scripts/generate.sh

project_status="$(git status --porcelain --untracked-files=all -- PetHalo.xcodeproj)"
if [[ -n "$project_status" ]]; then
    echo "error: generated Xcode project differs from the committed project:" >&2
    printf '%s\n' "$project_status" >&2
    exit 1
fi

echo "Generated Xcode project matches committed tree"
