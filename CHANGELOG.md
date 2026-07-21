# Changelog

Pet Halo follows the versioning policy in [`docs/VERSIONING.md`](docs/VERSIONING.md).

## [Unreleased]

### Added

- Weekly Ring capsules display the verified Weekly reset date in the user's local timezone when Codex provides one.
- A safe menu diagnostic distinguishes reviewed, provisional, blocked, and runtime-incompatible CLI states.

### Changed

- Replaced the exact-version-only startup allowlist with bounded provisional compatibility for supported pre-1.0 Codex CLI versions, guarded by required runtime capability validation and a known-incompatible denylist.
- Provisional protocol incompatibility now closes the owned app-server and pauses automatic reconnect while preserving user Refresh and restart retries.

## [0.1.0-beta.1] - 2026-07-21

### Added

- Public Beta compatibility review, fail-closed CLI acceptance, and safe failure messages.
- Core Pet Ring, Usage semantics, Pet/window/free-floating target hierarchy, appearance/accessibility polish, and original project branding completed through merged PRs #8 and #9.
- Reproducible unsigned Universal ZIP, manifest, checksum, verification, Developer ID signing, and notarization command surfaces delivered through merged PRs #10 and #11.
- User-first onboarding, release/security documentation, sanitized public issue templates, and a manually gated pinned-action Beta workflow.
- Reviewed support for Codex Desktop `26.715.52143 (5591)` and a single non-duplicated M5–M7 Pet-following gate.

### Release

- Published the public repository, tag `v0.1.0-beta.1`, and unsigned Universal artifact `Pet-Halo-0.1.0-beta.1-unsigned-universal.zip`.
- Published `SHA256SUMS`, `release-manifest.json`, and the checksum-matched `RELEASE_NOTES.md` alongside the ZIP.
- The Beta 1 ZIP is unsigned and not notarized; signed Developer ID and Apple notarization readiness remain blocked.

### Security

- Release artifacts exclude schemas, fixtures, smoke tools, reports, logs, debug assets, and machine-specific paths.
- Signing and notarization credentials are external-only and never stored in the repository.
