#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

if grep -EnR 'Tools/ProtocolProbe|Tests/Fixtures/CodexProtocol' project.yml PetHalo PetHaloCore Config; then
    echo "error: production target references M0 evidence" >&2
    exit 1
fi

if grep -EnR 'import (SwiftUI|AppKit)' PetHaloCore; then
    echo "error: PetHaloCore imports a UI framework" >&2
    exit 1
fi

if grep -EnR 'thread/|turn/|account/(login|logout|rateLimitResetCredit|workspaceMessages|sendAddCredits)|feedback/upload|command/exec|process/spawn|\.sqlite' PetHalo PetHaloCore Config; then
    echo "error: production source contains a forbidden capability" >&2
    exit 1
fi

if grep -EnR 'AXUIElement|AXObserver|AXIsProcessTrusted|NSWorkspace|NSRunningApplication\.runningApplications' PetHalo PetHaloCore \
    | grep -Ev '^PetHalo/WindowFollowing/(SystemWindowFollowing|SystemPetTargetDiscovery)\.swift:'; then
    echo "error: Accessibility or exact application discovery escaped the reviewed boundaries" >&2
    exit 1
fi

if grep -EnR 'UserDefaults([.(]|[[:space:]])' PetHalo PetHaloCore \
    | grep -Ev '^PetHalo/WindowFollowing/WindowFollowingPreferences\.swift:'; then
    echo "error: preferences escaped the reviewed M6 boundary" >&2
    exit 1
fi

if grep -EnR 'CGWindowListCopyWindowInfo|ScreenCaptureKit|SCShareableContent|CGDisplayStream|VNRecognizeTextRequest' PetHalo PetHaloCore; then
    echo "error: production source contains screen capture, broad window enumeration, or OCR" >&2
    exit 1
fi

if grep -En 'kAX(Title|Description|Value|Help|Identifier|SelectedText|VisibleCharacterRange|Children)Attribute' \
    PetHalo/WindowFollowing/SystemWindowFollowing.swift \
    PetHalo/WindowFollowing/SystemPetTargetDiscovery.swift; then
    echo "error: Accessibility boundaries contain text or content inspection" >&2
    exit 1
fi

if grep -EnR 'write\(to:|createFile\(atPath:|FileHandle\(forWritingTo:|NSKeyedArchiver' PetHalo PetHaloCore; then
    echo "error: production source contains a persistent storage write seam" >&2
    exit 1
fi

if find PetHalo -type f \( \
    -iname '*.png' -o \
    -iname '*.jpg' -o \
    -iname '*.jpeg' -o \
    -iname '*.gif' -o \
    -iname '*.webp' -o \
    -iname '*.svg' -o \
    -iname '*.pdf' \
\) | grep -q .; then
    echo "error: M6 production source must not contain final artwork assets" >&2
    exit 1
fi

if grep -EnR '(/bin/(bash|zsh|sh)|bash[[:space:]]+-c|zsh[[:space:]]+-c)' PetHalo PetHaloCore; then
    echo "error: production source invokes a shell" >&2
    exit 1
fi

allowed_account_methods='"account/read"|"account/rateLimits/read"|"account/usage/read"|"account/rateLimits/updated"|"account/updated"'
if grep -EnR '"account/[^" ]+"' PetHalo PetHaloCore | grep -Ev "$allowed_account_methods"; then
    echo "error: production source contains an account method outside the read-only allowlist" >&2
    exit 1
fi

if grep -EnR 'Logger.*(stdout|stderr|payload|JSON)|logger\.(debug|info|notice|warning|error|fault).*localizedDescription' PetHalo PetHaloCore; then
    echo "error: production diagnostics may expose raw data" >&2
    exit 1
fi

if grep -EnR 'com\.apple\.security\.|NSAppleEventsUsageDescription|NSScreenCaptureUsageDescription' Config project.yml; then
    echo "error: production must not enable unrelated sensitive entitlements or permissions" >&2
    exit 1
fi

echo "Production source boundaries validated"
