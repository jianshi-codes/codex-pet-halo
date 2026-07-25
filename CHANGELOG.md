# Changelog

Pet Halo follows the versioning policy in [`docs/VERSIONING.md`](docs/VERSIONING.md).

## [Unreleased]

No changes yet.

## [0.1.0-beta.3] - 2026-07-25

### Changed

- Updated Pet target selection for the current Codex Desktop multi-surface
  topology while continuing to fail closed when the largest eligible Pet targets
  are tied.
- Restored the saved visual-center placement immediately after Hide/Wake instead
  of waiting for the first new task activity.
- Removed Today tokens and unverified geometry-derived Live Activity from the Pet
  Ring. Weekly and the optional exact 5h window remain; the inner slot is reserved
  for a future exact Context Remaining source.
- Refreshed the public README Preview to show the current Weekly-only Pet Ring.

### Release

- Published tag `v0.1.0-beta.3` from reviewed source commit
  `e8480a0443783e05dd871f5c248157633a84d9c5` and the public GitHub Release.
- Published the unsigned Universal
  `Pet-Halo-0.1.0-beta.3-unsigned-universal.zip`, `release-manifest.json`,
  `RELEASE_NOTES.md`, and `SHA256SUMS` assets.
- Fresh public download verification passed for every checksum and GitHub asset
  digest; the manifest source commit matches the tag.
- The release uses product version `0.1.0`, bundle build `3`,
  `signing: unsigned`, and `notarization: not-submitted`.

## [0.1.0-beta.2] - 2026-07-21

### Added

- Weekly Ring capsules display the verified Weekly reset date in the user's local timezone when Codex provides one.
- A safe menu diagnostic distinguishes reviewed, provisional, blocked, and runtime-incompatible CLI states.

### Changed

- Added bounded provisional forward compatibility for newer supported pre-1.0 Codex CLI versions.
- Required initialize, account, rate-limit, and usable Weekly runtime capability validation for provisional sessions.
- Made runtime-incompatible handling terminal without an automatic reconnect loop.
- Preserved manual Refresh and application-restart retries after a runtime-incompatible result.

### Release

- Published tag `v0.1.0-beta.2` and the public GitHub Release on 2026-07-21.
- Published the unsigned Universal `Pet-Halo-0.1.0-beta.2-unsigned-universal.zip`, `release-manifest.json`, `RELEASE_NOTES.md`, and `SHA256SUMS` assets.
- Fresh public download verification passed for all checksum entries, and manifest `sourceCommit` matched the peeled tag commit `4e14938e06b50162a810cdaa5b195357e5239342`.
- The release uses product version `0.1.0`, bundle build `2`, `signing: unsigned`, and `notarization: not-submitted`.

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
