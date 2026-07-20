# Pet Halo Agent Guide

## Purpose

Pet Halo is an independent, unofficial macOS companion for Codex. The current application is a native menu-bar/accessory app with a transparent usage Halo that does not modify Codex Desktop or Codex Pet.

## Milestone boundaries

- Work only within the milestone explicitly authorized by the user.
- M1 contains the application skeleton, lifecycle boundary, menu-bar shell, tests, build tooling, CI, and documentation.
- M2 contains the stable Usage domain, read-only owned CodexBridge, JSON-RPC/process lifecycle, refresh/reconnect policy, tests, build tooling, CI, and documentation.
- M3 contains the non-activating click-through Halo panel, compact/expanded Usage presentation, accessibility, tests, smoke tooling, CI, and documentation.
- M4 — Codex Window Following & Fallback — is complete with PASS. It follows the Codex standard window, not the independently movable Pet, and remains the permanent window-level fallback above free-floating mode.
- M5 contains discovery-first Pet Target Discovery & Pet-relative Following. Investigate, in order, a separate Codex-owned Accessibility window or panel, a stable Accessibility child element, and only if Accessibility discovery is impossible a separately authorized visual-detection route that may require Screen Recording.
- M6 contains final branding, motion, themes, low-usage states, and game-like visual design.
- M7 contains compatibility hardening, packaging, privacy audits, release documentation, and release readiness.
- Do not begin M5, Screen Recording, visual detection, screenshots/OCR, final artwork, motion/themes, or later milestone work without separate authorization.

## Build and test

```sh
make bootstrap
make generate
make build
make test
make m0-tests
make m2-tests
make m2-smoke
make m3-tests
make m3-smoke
make m4-tests
make m4-smoke
make check
```

`project.yml` is the editable Xcode project source of truth. Do not hand-edit `PetHalo.xcodeproj/project.pbxproj`; regenerate it with `make generate` and commit the result.

## Protocol schemas

- `Tools/ProtocolProbe` and `Tests/Fixtures/CodexProtocol` are retained M0 evidence only.
- Generate protocol schemas only from the locally installed Codex CLI and never hand-edit generated schema files.
- Production Swift code and application resources must not depend on or bundle the probe, generated schemas, or fixtures.

## Privacy and safety

- Never commit credentials, authorization headers, account identifiers, email addresses, thread content, unsanitized protocol payloads, or user-specific absolute paths.
- Do not read or depend on Codex internal databases.
- Do not add analytics, telemetry, crash uploads, network requests, cloud services, or sensitive entitlements without a separately authorized milestone and privacy review.
- Missing or unsupported data must never be estimated.
