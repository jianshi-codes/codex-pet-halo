# Security Policy

## Supported release

Security support begins with the `0.1.0` Public Beta line. Until a signed and notarized Beta is published, the repository source is the only authoritative release material.

## Reporting a vulnerability

Use GitHub Security Advisories to report a suspected security or privacy issue privately once the repository is public. Do not open a public issue for credentials, authentication behavior, account-data exposure, unsafe Accessibility access, signing/notarization defects, or a supply-chain concern.

Do not include live tokens, authorization headers, cookies, account identity, conversation content, raw protocol payloads, raw Accessibility trees/errors, private screenshots, executable paths, or user-specific absolute paths. Use synthetic or recursively redacted evidence.

Maintainers should acknowledge a report without confirming impact prematurely, reproduce it with sanitized data, and disclose a fix only after affected artifacts and release notes are ready.

## Security boundary

- Pet Halo uses an owned local Codex app-server and a closed read-only method allowlist.
- Unsupported CLI versions fail before child-process launch.
- Generated schemas are retained evidence, not production resources.
- Codex internal databases, credentials, prompts, responses, and conversation content are out of scope and prohibited.
- Accessibility is exact-process geometry/structure only and is explicitly enabled by the user.
- The app has no telemetry, analytics, crash upload, updater, cloud service, Screen Recording, OCR, or Apple Events entitlement.
- Release credentials belong only in Keychain, environment variables, or GitHub encrypted secrets. They must never be committed or printed.

The app-server protocol and Codex Pet Accessibility surface are experimental compatibility boundaries. Treat changes to either as security-sensitive and fail closed until reviewed.
