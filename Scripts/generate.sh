#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

./Scripts/bootstrap.sh >/dev/null
xcodegen generate --spec project.yml
