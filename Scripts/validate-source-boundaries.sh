#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

if rg -n 'Tools/ProtocolProbe|Tests/Fixtures/CodexProtocol' project.yml PetHalo PetHaloCore Config; then
    echo "error: production target references M0 evidence" >&2
    exit 1
fi

if rg -n 'import (SwiftUI|AppKit)' PetHaloCore; then
    echo "error: PetHaloCore imports a UI framework" >&2
    exit 1
fi

if rg -n 'thread/|turn/|account/(login|logout|rateLimitResetCredit|workspaceMessages|sendAddCredits)|feedback/upload|command/exec|process/spawn|\.sqlite|NSPanel' PetHalo PetHaloCore Config; then
    echo "error: production source contains a forbidden M2 capability" >&2
    exit 1
fi

if rg -n '(/bin/(ba|z|)sh|bash[[:space:]]+-c|zsh[[:space:]]+-c)' PetHalo PetHaloCore; then
    echo "error: production source invokes a shell" >&2
    exit 1
fi

allowed_account_methods='"account/read"|"account/rateLimits/read"|"account/usage/read"|"account/rateLimits/updated"|"account/updated"'
if rg -n '"account/[^" ]+"' PetHalo PetHaloCore | rg -v "$allowed_account_methods"; then
    echo "error: production source contains an account method outside the read-only allowlist" >&2
    exit 1
fi

if rg -n 'Logger.*(stdout|stderr|payload|JSON)|logger\.(debug|info|notice|warning|error|fault).*localizedDescription' PetHalo PetHaloCore; then
    echo "error: production diagnostics may expose raw data" >&2
    exit 1
fi

if rg -n 'com\.apple\.security\.|NSAppleEventsUsageDescription|NSAccessibilityUsageDescription|NSScreenCaptureUsageDescription' Config project.yml; then
    echo "error: M2 must not enable sensitive entitlements or permissions" >&2
    exit 1
fi

echo "Production source boundaries validated"
