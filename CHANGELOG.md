# Changelog

Pet Halo follows the versioning policy in [`docs/VERSIONING.md`](docs/VERSIONING.md).

## [Unreleased]

### Added

- Public Beta compatibility review and safe failure messages.
- Reproducible unsigned Release build, ZIP, manifest, checksum, verification, Developer ID signing, and notarization command surfaces.
- User-first onboarding, release/security documentation, and sanitized public issue templates.
- Manually gated Beta release workflow with pinned actions and no ordinary-push publication.
- Reviewed support for Codex Desktop `26.715.52143 (5591)` and a single non-duplicated M5–M7 Pet-following gate.

### Security

- Release artifacts exclude schemas, fixtures, smoke tools, reports, logs, debug assets, and machine-specific paths.
- Signing and notarization credentials are external-only and never stored in the repository.

## [0.1.0-beta.1] - Unreleased

First planned Public Beta. Core Pet Ring, Usage semantics, Pet/window/free-floating target hierarchy, appearance/accessibility polish, and original project branding are frozen from M8.
