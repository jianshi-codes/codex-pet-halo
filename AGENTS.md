# Pet Halo Agent Guide

## Purpose

Pet Halo is an independent, unofficial macOS companion for Codex. The current application is a native menu-bar/accessory app with a transparent usage Halo that does not modify Codex Desktop or Codex Pet.

## Milestone boundaries

- Work only within the milestone explicitly authorized by the user.
- M1 contains the application skeleton, lifecycle boundary, menu-bar shell, tests, build tooling, CI, and documentation.
- M2 contains the stable Usage domain, read-only owned CodexBridge, JSON-RPC/process lifecycle, refresh/reconnect policy, tests, build tooling, CI, and documentation.
- M3 contains the non-activating click-through Halo panel, compact/expanded Usage presentation, accessibility, tests, smoke tooling, CI, and documentation.
- M4 — Codex Window Following & Fallback — is complete with PASS. It follows the Codex standard window, not the independently movable Pet, and remains the permanent window-level fallback above free-floating mode.
- M5 — Pet Target Discovery & Pet-relative Following — is complete through Route A. It prefers the unique geometric Pet AX window target, preserves M4 and M3 fallbacks, and provides optional manual calibration with a separate Pet-relative anchor.
- M6 — Automatic Pet Attachment & Adaptive Placement — is implemented and makes first-use Pet attachment automatic with the Halo panel center locked to the Pet center while preserving optional fine-tuning.
- M7 — Original Halo Visual Design — replaces the demo card with the final semicircular Halo, percentage label, semantic status treatment, themes, and motion.
- M8 — Hardening & Release Readiness — contains compatibility hardening, packaging, privacy audits, release documentation, and release readiness.
- Do not begin Screen Recording, visual detection, screenshots/OCR, final artwork, motion, themes, release work, or later milestone work without separate authorization.

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
make m5-tests
make m5-smoke
make m6-tests
make m6-smoke
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
