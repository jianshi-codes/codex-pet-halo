#!/bin/bash
set -euo pipefail

readonly release_repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly release_marketing_version="${MARKETING_VERSION:-0.1.0}"
readonly release_build_number="${BUILD_NUMBER:-1}"
readonly release_tag="${RELEASE_TAG:-v0.1.0-beta.1}"
readonly release_label="${release_tag#v}"
readonly release_output_root="${RELEASE_OUTPUT_ROOT:-$release_repository_root/dist/$release_tag}"
readonly release_derived_data="${RELEASE_DERIVED_DATA:-$release_repository_root/DerivedData/PublicBeta}"
readonly release_app="$release_output_root/stage/Pet Halo.app"
readonly release_archive="$release_output_root/Pet-Halo-$release_label-universal.zip"
readonly release_manifest="$release_output_root/release-manifest.json"
readonly release_notes_source="$release_repository_root/docs/release-notes/$release_tag.md"
readonly release_notes="$release_output_root/RELEASE_NOTES.md"
readonly release_checksums="$release_output_root/SHA256SUMS"

release_fail() {
    echo "error: $1" >&2
    exit 1
}

release_validate_inputs() {
    [[ "$release_marketing_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
        || release_fail "MARKETING_VERSION must use Apple numeric form, such as 0.1.0"
    [[ "$release_build_number" =~ ^[1-9][0-9]*$ ]] \
        || release_fail "BUILD_NUMBER must be a positive integer"
    [[ "$release_tag" =~ ^v${release_marketing_version}-beta\.[1-9][0-9]*$ ]] \
        || release_fail "RELEASE_TAG must match v<MARKETING_VERSION>-beta.<number>"
    case "$release_output_root" in
        "$release_repository_root"/dist/*) ;;
        *) release_fail "RELEASE_OUTPUT_ROOT must remain inside the repository dist directory" ;;
    esac
}

release_require_command() {
    command -v "$1" >/dev/null 2>&1 || release_fail "required command is unavailable: $1"
}

release_require_clean_source() {
    if [[ "${RELEASE_ALLOW_DIRTY:-0}" == "1" ]]; then
        echo "Release source check: development override"
        return
    fi
    [[ -z "$(git -C "$release_repository_root" status --porcelain --untracked-files=all)" ]] \
        || release_fail "release builds require a clean source tree"
    echo "Release source check: clean"
}

release_require_app() {
    [[ -d "$release_app" ]] || release_fail "release application is unavailable; run make release-build first"
}

release_require_archive() {
    [[ -f "$release_archive" ]] || release_fail "release archive is unavailable; run make release-archive first"
}

release_safe_reset_directory() {
    local target="$1"
    case "$target" in
        "$release_repository_root"/dist/*|"$release_repository_root"/DerivedData/*) ;;
        *) release_fail "refusing to reset a directory outside release output roots" ;;
    esac
    rm -rf "$target"
    mkdir -p "$target"
}

release_validate_inputs
