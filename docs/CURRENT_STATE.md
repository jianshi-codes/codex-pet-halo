# Current State

- Milestone: M9 — Public Beta Release Readiness
- Status: **PARTIAL — SOURCE RELEASE READY, SIGNED BINARY BLOCKED**
- Published release: `v0.1.0-beta.5`, product version `0.1.0`, bundle build `5`
- Published source: `aa59c89cc5ce1789cb180ef2f6358d39bfae7161`
- Release classification: public, non-draft prerelease; unsigned and not
  notarized. Beta 4 is currently Latest.
- Post-release branch: `codex/beta5-release-closeout`
- Next unused identity: `v0.1.0-beta.6`, product version `0.1.0`, bundle build
  `6`; availability must be checked before preparation or publication
- Repository: public at `jianshi-codes/codex-pet-halo`

## Published Beta 5 evidence — 2026-08-30

- PR #22 merged the Beta 5 preparation into `main`; the reviewed source is
  `aa59c89cc5ce1789cb180ef2f6358d39bfae7161`.
- Validation-only workflow
  [33263985584](https://github.com/jianshi-codes/codex-pet-halo/actions/runs/33263985584)
  passed without creating release state.
- Publication workflow
  [33264153248](https://github.com/jianshi-codes/codex-pet-halo/actions/runs/33264153248)
  passed. The unsigned publish job completed and the signed/notarized job was
  skipped.
- GitHub published
  [Pet Halo 0.1.0 Beta 5 — Unsigned Developer Preview](https://github.com/jianshi-codes/codex-pet-halo/releases/tag/v0.1.0-beta.5)
  at `2026-08-29T16:55:13Z` as a non-draft prerelease. The `/releases/latest`
  endpoint resolves to Beta 4.
- The tag resolves to the reviewed source commit
  `aa59c89cc5ce1789cb180ef2f6358d39bfae7161`. The complete public asset set is:
  - `Pet-Halo-0.1.0-beta.5-unsigned-universal.zip` — 1,352,907 bytes,
    SHA-256 `297ecd8c36ea078fc7d043f3872c97d7ac4a636e6a71324359febcacb237bc57`;
  - `release-manifest.json` — 336 bytes,
    SHA-256 `0626a8fcedd247eef735319ef34151fe28722a46515d388fa24095f115dfa4a2`;
  - `RELEASE_NOTES.md` — 2,729 bytes,
    SHA-256 `c242d7aed34048477abe91a51df19d624c7b0ccb02daa92c168922d07d1b998e`;
  - `SHA256SUMS` — 282 bytes,
    SHA-256 `0169d8b8b266867680111492c00f1a72c54ed5c8de75f01068d0a199682b0e7f`.
- A fresh public download contained exactly those four files. Every checksum
  entry and GitHub API asset digest matched.
- The manifest and extracted bundle match version `0.1.0`, build `5`, bundle
  identifier `io.github.jianshicodes.PetHalo`, minimum macOS `14.0`, and
  Universal `x86_64 arm64` architectures. The manifest records
  `signing: unsigned` and `notarization: not-submitted`; strict code-signing
  verification does not pass.
- Downloaded `RELEASE_NOTES.md` is byte-identical to the tagged
  `docs/release-notes/v0.1.0-beta.5.md`.
- The public downloaded artifact launched, created its owned local app-server,
  quit normally, and left no owned process.
- Developer ID signing, Apple notarization, stapling, Gatekeeper signed
  verification, and signed clean-machine acceptance remain incomplete.

## Published Beta 4 evidence

- PR #20 merged the release preparation into `main`; tag
  `v0.1.0-beta.4` resolves directly to reviewed source
  `beb0c2c925d04fccf650205a611a1a20d22ead75`.
- The source fix restores symmetric activity-card direction handling for Codex
  Desktop `26.727.40816 (6067)` without changing Pet selection, midpoint
  tracking, or the saved visual-center offset. The user confirmed direct final
  acceptance with the Pet at both the top and bottom of the screen.
- Validation-only workflow
  [30612303612](https://github.com/jianshi-codes/codex-pet-halo/actions/runs/30612303612)
  passed at the released SHA without creating release state.
- The ordinary `main` CI run
  [30612184013](https://github.com/jianshi-codes/codex-pet-halo/actions/runs/30612184013)
  had one initial debounce-test timing failure; its failed-job rerun passed at
  the same SHA. No product or test change was made for that isolated result.
- Publication workflow
  [30612707366](https://github.com/jianshi-codes/codex-pet-halo/actions/runs/30612707366)
  passed at the same SHA. The unsigned publish job completed and the
  Developer ID/notarization job was skipped.
- GitHub published
  [Pet Halo 0.1.0 Beta 4 — Unsigned Developer Preview](https://github.com/jianshi-codes/codex-pet-halo/releases/tag/v0.1.0-beta.4)
  at `2026-07-31T07:29:22Z`.
- The live API reports `draft: false`, `prerelease: true`, and target/source
  `beb0c2c925d04fccf650205a611a1a20d22ead75`. At Beta 4 closeout time the
  Latest endpoint resolved to Beta 3; it now resolves to Beta 4 after Beta 5
  publication.
- The complete public asset set is:
  - `Pet-Halo-0.1.0-beta.4-unsigned-universal.zip` — 1,344,136 bytes,
    SHA-256 `1eb6406b419b2a93df39b786714983b8df2e35c0ab8e0e36f5a48be8ed6cd212`;
  - `release-manifest.json` — 336 bytes,
    SHA-256 `0a123b31a72a625c52a8b2ba2981bc346d7cb86999a170db79bc94720ea0952f`;
  - `RELEASE_NOTES.md` — 2,199 bytes,
    SHA-256 `68ef056d7f4573a43f1fba4e343b91620e04e4621a0789e9a89b0ed9f368b869`;
  - `SHA256SUMS` — 282 bytes,
    SHA-256 `b78ea1ec010a0df8f88c0121b458a958aed243c8f0ab732ebfb75d262a487c5e`.
- A fresh public download contained exactly those four files. Every
  `SHA256SUMS` entry and GitHub API asset digest matched.
- The manifest and extracted bundle match version `0.1.0`, build `4`, bundle
  identifier `io.github.jianshicodes.PetHalo`, minimum macOS `14.0`, and
  Universal `x86_64 arm64` architectures. The manifest records
  `signing: unsigned` and `notarization: not-submitted`; strict code-signing
  verification reports that the code is not signed.
- Downloaded `RELEASE_NOTES.md` is byte-identical to the tagged
  `docs/release-notes/v0.1.0-beta.4.md`.
- Per the user's accepted direct UI evidence and release-process instruction,
  no duplicate interactive or launch smoke was run during closeout.
- Beta 1, Beta 2, and Beta 3 tags, assets, and release notes were not modified.

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
- Installed CLI `0.146.0-alpha.9.2` passed the same bounded provisional
  capability path on 2026-07-31. Its temporary schema comparison did not change
  the exact reviewed registry.
- Desktop `26.721.41059 (5848)` current multi-surface targeting, direct
  Hide/Wake center restoration, and truthful inner-slot behavior are included
  in Beta 3.
- Desktop `26.727.40816 (6067)` Pet-spanning-container exclusion, narrow-control
  exclusion, same-side activity-stack resolution, and user-confirmed two-sided
  Halo opening behavior are included in Beta 4.
- Optional 5h and Account Usage remain capability-gated. Account Usage is
  available only in fallback cards, not the Pet Ring. Missing data is never
  estimated.

## Final validation state

- The Beta 4 source fix passed 115 M7 tests. Release preparation passed the
  full check with 73 core Swift tests including one intended local-only skip,
  124 application Swift tests, and 45 Python tests.
- The merged `main` CI had one initial debounce timing failure; the failed-job
  rerun passed at the exact released SHA. Both validation-only and publication
  workflows independently passed their release validation.
- The user confirmed the final above/below Halo opening behavior and preserved
  Pet center directly on Codex Desktop `26.727.40816 (6067)`.
- `make public-exposure-audit` passed in both release workflows.
- Local and fresh public-download checksum, digest, manifest, bundle, Universal
  architecture, unsigned-state, and release-note identity verification passed.
- No duplicate interaction or launch smoke was run after the user's explicit
  acceptance; no clean-machine acceptance is claimed.

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

Any future publication must use a new tag and build number. Beta 1, Beta 2,
Beta 3, and Beta 4 may not be overwritten, retagged, reclassified as
signed/notarized, or silently replaced.
