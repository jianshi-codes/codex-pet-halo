#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly snapshot_dir="$(mktemp -d "${TMPDIR:-/tmp}/pet-halo-project-snapshot.XXXXXX")"
cleanup() {
    rm -rf "$snapshot_dir"
}
trap cleanup EXIT
cd "$repository_root"

cp -R PetHalo.xcodeproj "$snapshot_dir/PetHalo.xcodeproj"
./Scripts/generate.sh

if ! diff -qr "$snapshot_dir/PetHalo.xcodeproj" PetHalo.xcodeproj >/dev/null; then
    echo "error: generated Xcode project differs from the checked working tree" >&2
    exit 1
fi

trap - EXIT
cleanup
echo "Generated Xcode project matches checked working tree"
