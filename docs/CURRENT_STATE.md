# Current State

- Milestone: M9 — Public Beta Release Readiness
- Status: **PARTIAL — SOURCE RELEASE READY, SIGNED BINARY BLOCKED**
- Closeout branch: `docs/beta2-release-closeout`
- Active maintenance branch: `codex/fix-pet-target-ambiguity`, Draft PR #17
- Product/UI on the active branch: current Desktop multi-surface Pet selection,
  immediate saved-center restoration after Hide/Wake, Beta 2 Ring geometry with
  Today and unverified Live Activity removed, and an intentionally empty inner
  context slot; this behavior is not part of the published Beta 2 artifact
- Published release: `v0.1.0-beta.2`, product version `0.1.0`, bundle build `2`
- Next candidate identity: `v0.1.0-beta.3`, product version `0.1.0`, bundle build
  `3`; the tag and GitHub Release were confirmed unused on 2026-07-25 but have
  not been created
- Repository: public at `jianshi-codes/codex-pet-halo`
- Artifact: unsigned Universal ZIP; Developer ID signing and Apple notarization are not complete

## Published Beta 2 evidence

- PR #14 and PR #15 are merged into `main`; the annotated `v0.1.0-beta.2` tag peels to reviewed source commit `4e14938e06b50162a810cdaa5b195357e5239342`.
- GitHub published `Pet Halo 0.1.0 Beta 2 — Unsigned Developer Preview` at `2026-07-21T08:43:44Z`: <https://github.com/jianshi-codes/codex-pet-halo/releases/tag/v0.1.0-beta.2>.
- The live REST API reports target `main`, `draft: false`, `prerelease: false`; the `/releases/latest` endpoint resolves to Beta 2, so it is the latest Release.
- The complete public asset set and API-reported sizes are:
  - `Pet-Halo-0.1.0-beta.2-unsigned-universal.zip` — 1,382,813 bytes;
  - `release-manifest.json` — 336 bytes;
  - `RELEASE_NOTES.md` — 1,852 bytes;
  - `SHA256SUMS` — 282 bytes.
- A fresh public download contains exactly those four assets. `shasum -a 256 -c SHA256SUMS` passes for the ZIP, manifest, and release notes.
- The manifest records product `Pet Halo`, version `0.1.0`, build `2`, tag `v0.1.0-beta.2`, bundle identifier `io.github.jianshicodes.PetHalo`, minimum macOS `14.0`, `arm64` and `x86_64`, `signing: unsigned`, `notarization: not-submitted`, and a `sourceCommit` equal to the peeled tag commit.
- The extracted application reports `CFBundleShortVersionString = 0.1.0`, `CFBundleVersion = 2`, `CFBundleIdentifier = io.github.jianshicodes.PetHalo`, and `LSMinimumSystemVersion = 14.0`; `lipo -archs` reports both `x86_64` and `arm64`.
- Downloaded `RELEASE_NOTES.md` is byte-identical to `docs/release-notes/v0.1.0-beta.2.md` at the published tag.
- Beta 1, its tag, its four published assets, and its release notes remain unchanged.

## CLI compatibility state

- CLI `0.145.0-alpha.18` remains the exact reviewed baseline. Exact registry entries carry the schema and production-semantic review evidence.
- Newer versions at or above `0.145.0-alpha.18` and below `1.0.0` may run provisionally. Provisional sessions must pass initialize/initialized, account behavior, rate-limit decoding, and a usable exact 10,080-minute Weekly window at runtime.
- The optional 5h window and Account Usage remain capability-gated and may be absent;
  missing data is not estimated. Account Usage remains available only to fallback cards,
  not the Pet Ring.
- Malformed, too-old, explicitly denied, 1.x, and runtime-incompatible versions fail closed. Required provisional runtime failure closes the owned child and disables automatic reconnect until manual Refresh or application restart.
- Installed CLI `0.145.0-alpha.27` passed the sanitized provisional real smoke, including required Weekly percentage/reset decoding and clean owned-child shutdown. Optional 5h was absent and Account Usage was available on the validation host.
- Installed CLI `0.146.0-alpha.3.1` passed the same sanitized provisional
  read-only smoke on 2026-07-25: handshake, JSON-RPC envelopes, account/rate
  reads, valid Weekly percentage/reset decoding, optional 5h omission, available
  Account Usage, and clean shutdown.
- Provisional runtime success is session evidence only; it is not formal schema-review evidence and does not add the installed version to the reviewed registry.

## Retained validation state

- `make check`: PASS on the active release-preparation working tree on
  2026-07-25, including generated-project drift, boundary/privacy scans, Debug
  and Universal Release builds, 73 core Swift tests with one local-only smoke
  skipped, 121 application Swift tests, and 43 deterministic Python tests.
- M2 smoke: PASS — current CLI `0.146.0-alpha.3.1` passed the required
  provisional read-only capabilities and completed clean owned-child
  launch/shutdown.
- M3 smoke: PASS.
- M4 smoke: deterministic PASS; the standard-window target was unavailable during the retained live probe.
- Unified M5–M7 gate: PASS — 110 deterministic tests plus one direct movement/Tuck Away/Wake/Quit flow.
- M8 smoke: deterministic PASS.
- Unsigned release archive verification and extracted launch/quit: PASS.
- Equivalent isolated-host unsigned launch/quit: PASS; signed/notarized clean-machine acceptance remains incomplete.
- `make public-exposure-audit`: PASS — all reachable Git blobs inspected with one exact synthetic fixture allowance.
- Fresh published Beta 2 download, checksums, manifest source commit, bundle metadata, Universal architectures, and release-note identity: PASS.
- Draft PR #17 CI: PASS on the implementation plus refreshed current-source
  Preview head before this release-preparation update; the final documentation
  head requires a fresh CI pass.

## Remaining release gate

- Source and unsigned Beta 2 publication: complete.
- PR #17 remains Draft and unmerged; Beta 3 must start from its reviewed, clean
  merge commit on `main`.
- `public-beta` does not currently exist, so required reviewers and release
  secrets are not configured behind the workflow environment.
- The Beta 3 candidate notes and unused identity do not create or
  authorize a tag, GitHub Release, signing operation, notarization submission,
  or publication.
- Developer ID signing: not complete.
- Apple notarization: not complete.
- Stapling and Gatekeeper signed verification: not complete.
- Signed clean-machine acceptance: not complete.

Any future signed publication must use a new tag and build number. Neither Beta 1 nor Beta 2 may be overwritten, retagged, reclassified, or presented as signed/notarized.
