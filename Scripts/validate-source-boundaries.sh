#!/bin/bash
set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

if rg -n 'Tools/ProtocolProbe|Tests/Fixtures/CodexProtocol' project.yml PetHalo Config; then
    echo "error: production target references M0 evidence" >&2
    exit 1
fi

if rg -n 'codex app-server|thread/start|turn/start|account/(read|usage|rateLimits)|\.sqlite|NSPanel' PetHalo Config; then
    echo "error: production source contains a post-M1 capability" >&2
    exit 1
fi

if rg -n 'com\.apple\.security\.|NSAppleEventsUsageDescription|NSAccessibilityUsageDescription|NSScreenCaptureUsageDescription' Config project.yml; then
    echo "error: M1 must not enable sensitive entitlements or permissions" >&2
    exit 1
fi

echo "Production source boundaries validated"
