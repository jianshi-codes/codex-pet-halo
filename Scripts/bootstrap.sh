#!/bin/bash
set -euo pipefail

readonly expected_xcodegen_version="2.46.0"
readonly required_commands=(python3 swift xcodebuild xcodegen)

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: the Pet Halo macOS application requires macOS" >&2
    exit 1
fi

for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "error: missing required command: $command_name" >&2
        if [[ "$command_name" == "xcodegen" ]]; then
            echo "Install XcodeGen ${expected_xcodegen_version} explicitly, then rerun make bootstrap." >&2
            echo "Homebrew command when that version is current: brew install xcodegen" >&2
        fi
        exit 1
    fi
done

actual_xcodegen_version="$(xcodegen --version | awk '{print $2}')"
if [[ "$actual_xcodegen_version" != "$expected_xcodegen_version" ]]; then
    echo "error: XcodeGen ${expected_xcodegen_version} is required; found ${actual_xcodegen_version}" >&2
    echo "Use the pinned upstream release: https://github.com/yonaskolb/XcodeGen/releases/tag/${expected_xcodegen_version}" >&2
    exit 1
fi

echo "Prerequisites available: XcodeGen ${actual_xcodegen_version}"
xcodebuild -version
swift --version
python3 --version
