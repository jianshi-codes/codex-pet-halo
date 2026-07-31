# Current State

- Milestone: M9 — Public Beta Release Readiness
- Status: **PARTIAL — SOURCE RELEASE READY, SIGNED BINARY BLOCKED**
- Published release: `v0.1.0-beta.3`, product version `0.1.0`, bundle build `3`
- Published source: `e8480a0443783e05dd871f5c248157633a84d9c5`
- Release classification: public, non-draft, non-prerelease, latest; unsigned
  and not notarized
- Post-release branch: `codex/beta3-release-closeout`
- Next unused identity: `v0.1.0-beta.4`, product version `0.1.0`, bundle build
  `4`; both the remote tag and GitHub Release were confirmed absent on
  2026-07-31
- Repository: public at `jianshi-codes/codex-pet-halo`

## Beta 4 preparation state

- Candidate identity: `v0.1.0-beta.4`, product version `0.1.0`, bundle build
  `4`, unsigned and not notarized.
- The current source fix is
  `4dbf55c6c13580f54010d4c5f4c0cb8e030ce977` on `main` and `origin/main`.
  It restores symmetric activity-card direction handling for the current Codex
  Desktop without changing Pet selection, midpoint tracking, or the saved
  visual-center offset.
- Current Codex Desktop `26.727.40816 (6067)` exposes the Pet core, a wider
  Pet-spanning container, narrow voice/resize controls, and one or more activity
  cards as separate Accessibility windows. The candidate excludes the
  Pet-spanning container and narrow controls, resolves same-side activity
  stacks, and retains the prior opening for mixed-side ambiguity.
- The user confirmed final direct visual acceptance on 2026-07-31 with the Pet
  at both the top and bottom of the screen: activity cards occupied the matching
  Halo opening and the saved Pet center remained unchanged.
- Deterministic validation on the source fix passed 115 M7 tests. The release
  preparation branch passed the full
  check: 73 core Swift tests with one intended local-only skip, 124 application
  Swift tests, and 45 Python tests.
- Installed CLI `0.146.0-alpha.9.2` generated 349 temporary JSON schema files.
  Production-used initialization and Account Usage shapes matched; the observed
  account/rate differences affected only fields Pet Halo does not decode. The
  sanitized provisional M2 smoke passed required account, Weekly, Account Usage,
  JSON-RPC, and clean-shutdown capabilities.
- The user explicitly accepted the direct manual evidence and requested that
  release preparation not repeat the older M3/M4/Pet/M8 smoke sequence in this
  or future releases. The public-exposure audit passed; the local unsigned
  candidate and GitHub validation workflow remain pending. No Beta 4 tag or
  GitHub Release exists.

## Published Beta 3 evidence

- PR #17 merged the current Desktop Pet targeting, Hide/Wake center restoration,
  and truthful Weekly-only Pet Ring behavior at
  `b95e268eb0a0769ff23c077fa45035bf4ab947f1`. PR #18 merged the unsigned
  publication path at the released source commit
  `e8480a0443783e05dd871f5c248157633a84d9c5`.
- The validation-only workflow
  [run 30162649808](https://github.com/jianshi-codes/codex-pet-halo/actions/runs/30162649808)
  passed at the released SHA without creating a tag or Release.
- The publication workflow
  [run 30162751853](https://github.com/jianshi-codes/codex-pet-halo/actions/runs/30162751853)
  passed at the same SHA. The unsigned publish job completed and the
  Developer ID/notarization job was skipped.
- GitHub published
  [Pet Halo 0.1.0 Beta 3 — Unsigned Developer Preview](https://github.com/jianshi-codes/codex-pet-halo/releases/tag/v0.1.0-beta.3)
  at `2026-07-25T15:03:26Z`.
- The live API reports target/source
  `e8480a0443783e05dd871f5c248157633a84d9c5`, `draft: false`, and
  `prerelease: false`. The user intentionally changed the release classification
  after publication, and the `/releases/latest` endpoint resolves to Beta 3.
- The complete public asset set is:
  - `Pet-Halo-0.1.0-beta.3-unsigned-universal.zip` — 1,343,373 bytes,
    SHA-256 `f57f97f51b6c0334faac1501456a7a6be2cefdd1ceb24ae04a3422407bd0ca54`;
  - `release-manifest.json` — 336 bytes,
    SHA-256 `a45d23a8665cfd48b5b8ee311f803adf4df72f15a9b95c5cecb840fa75d76416`;
  - `RELEASE_NOTES.md` — 2,041 bytes,
    SHA-256 `124e068996746f4e3b4a86193ff5e54a12df549e427f81f2b8ead4639271fa4e`;
  - `SHA256SUMS` — 282 bytes,
    SHA-256 `33a25f1d966c85be649e203b1bd3df17fbc8c28ab7bc2a887dbc74a80956644e`.
- A fresh public download contained exactly those four files. Every
  `SHA256SUMS` entry and every GitHub API asset digest matched.
- The manifest records product `Pet Halo`, version `0.1.0`, build `3`, tag
  `v0.1.0-beta.3`, bundle identifier `io.github.jianshicodes.PetHalo`, minimum
  macOS `14.0`, `arm64` and `x86_64`, `signing: unsigned`,
  `notarization: not-submitted`, and the released source commit.
- The extracted public application reports the same version/build/identifier
  and minimum macOS. `lipo -archs` reports `x86_64 arm64`; strict
  `codesign --verify --deep --strict` reports that the code is not signed.
- Downloaded `RELEASE_NOTES.md` is byte-identical to the tagged
  `docs/release-notes/v0.1.0-beta.3.md`.
- The public artifact launched, created its owned local Codex app-server, quit
  normally, and left neither process running.
- Beta 1 and Beta 2 tags, assets, and release notes were not modified.

## CLI and Desktop compatibility state

- CLI `0.145.0-alpha.18` remains the exact reviewed baseline. Newer versions at
  or above that version and below `1.0.0` may run provisionally only after
  required runtime capability validation.
- Installed CLI `0.146.0-alpha.3.1` passed the sanitized provisional read-only
  smoke on 2026-07-25: handshake, JSON-RPC envelopes, account/rate reads,
  valid Weekly percentage/reset decoding, optional 5h omission, available
  Account Usage, and clean shutdown. This is session evidence, not formal schema
  review.
- Desktop `26.721.41059 (5848)` current multi-surface targeting, direct
  Hide/Wake center restoration, and truthful inner-slot behavior are included
  in Beta 3.
- Optional 5h and Account Usage remain capability-gated. Account Usage is
  available only in fallback cards, not the Pet Ring. Missing data is never
  estimated.

## Final validation state

- `make check`: PASS on released `main`, including generated-project and
  boundary/privacy checks, Debug and Universal Release builds, 73 core Swift
  tests with one intended local-only skip, 121 application Swift tests, and 44
  Python tests.
- M2 and M3 smoke: PASS with installed CLI `0.146.0-alpha.3.1`.
- M4 deterministic smoke: PASS; physical calibration/movement remains separate
  observer evidence.
- Unified Pet-following gate: 112 deterministic tests passed. The user
  confirmed the final Move, Tuck Away, Wake, Quit, center, and Ring observation
  flow on 2026-07-25.
- M8 smoke: deterministic PASS.
- `make public-exposure-audit`: PASS across 1,768 reachable Git blobs with one
  exact synthetic fixture allowance.
- Local unsigned archive verification and isolated clean-preferences
  launch/quit: PASS.
- Fresh public-download checksum, digest, manifest, bundle, Universal
  architecture, release-note identity, launch, and owned-child shutdown:
  PASS.

## Remaining trust gate

- Developer ID signing: not complete.
- Apple notarization and stapling: not complete.
- Gatekeeper signed verification: not applicable to this unsigned artifact and
  not claimed.
- Signed clean-machine acceptance: not complete. The local isolated
  clean-preferences launch is not presented as a separate clean-machine test.
- The `public-beta` environment and signing/notarization credentials remain
  unnecessary for the published unsigned path and unavailable for a future
  signed path.

Any future publication must use a new tag and build number. Beta 1, Beta 2, and
Beta 3 may not be overwritten, retagged, reclassified as signed/notarized, or
silently replaced.
