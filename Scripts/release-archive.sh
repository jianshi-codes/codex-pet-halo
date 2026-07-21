#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"

release_require_command ditto
release_require_app
mkdir -p "$release_output_root"
rm -f "$release_archive"

COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --keepParent "$release_app" "$release_archive"

echo "Release archive: $(basename "$release_archive")"
