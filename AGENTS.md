# Pet Halo Agent Guide

## Purpose

Pet Halo is an independent, unofficial macOS companion for Codex. The current application is a native menu-bar/accessory shell that will eventually host a transparent usage halo without modifying Codex Desktop or Codex Pet.

## Milestone boundaries

- Work only within the milestone explicitly authorized by the user.
- M1 contains the application skeleton, lifecycle boundary, menu-bar shell, tests, build tooling, CI, and documentation.
- M2 contains the stable Usage domain, read-only owned CodexBridge, JSON-RPC/process lifecycle, refresh/reconnect policy, tests, build tooling, CI, and documentation.
- Do not begin Halo windows, Usage presentation, window tracking, or later milestone work without separate authorization.

## Build and test

```sh
make bootstrap
make generate
make build
make test
make m0-tests
make m2-tests
make m2-smoke
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
