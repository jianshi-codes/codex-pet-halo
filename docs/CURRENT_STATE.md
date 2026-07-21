# Current State

- Milestone: M9 — Public Beta Release Readiness
- Status: **PARTIAL — SOURCE RELEASE READY, SIGNED BINARY BLOCKED**
- Closeout branch: `docs/beta2-release-closeout`
- Product/UI: frozen at the accepted M8 behavior
- Published release: `v0.1.0-beta.2`, product version `0.1.0`, bundle build `2`
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
- The optional 5h window and Account Usage/Today remain capability-gated and may be absent; missing data is not estimated.
- Malformed, too-old, explicitly denied, 1.x, and runtime-incompatible versions fail closed. Required provisional runtime failure closes the owned child and disables automatic reconnect until manual Refresh or application restart.
- Installed CLI `0.145.0-alpha.27` passed the sanitized provisional real smoke, including required Weekly percentage/reset decoding and clean owned-child shutdown. Optional 5h was absent and Account Usage was available on the validation host.
- Provisional runtime success is session evidence only; it is not formal schema-review evidence and does not add the installed version to the reviewed registry.

## Retained validation state

- `make check`: PASS at Beta 2 release closeout, including generated-project drift, boundary/privacy scans, Debug and Universal Release builds, Swift tests, and deterministic Python tests.
- M2 smoke: PASS — CLI `0.145.0-alpha.27` passed the required provisional read-only capabilities and completed clean release-owned-child launch/shutdown.
- M3 smoke: PASS.
- M4 smoke: deterministic PASS; the standard-window target was unavailable during the retained live probe.
- Unified M5–M7 gate: PASS — 110 deterministic tests plus one direct movement/Tuck Away/Wake/Quit flow.
- M8 smoke: deterministic PASS.
- Unsigned release archive verification and extracted launch/quit: PASS.
- Equivalent isolated-host unsigned launch/quit: PASS; signed/notarized clean-machine acceptance remains incomplete.
- `make public-exposure-audit`: PASS — all reachable Git blobs inspected with one exact synthetic fixture allowance.
- Fresh published Beta 2 download, checksums, manifest source commit, bundle metadata, Universal architectures, and release-note identity: PASS.

## Remaining release gate

- Source and unsigned Beta 2 publication: complete.
- Developer ID signing: not complete.
- Apple notarization: not complete.
- Stapling and Gatekeeper signed verification: not complete.
- Signed clean-machine acceptance: not complete.

Any future signed publication must use a new tag and build number. Neither Beta 1 nor Beta 2 may be overwritten, retagged, reclassified, or presented as signed/notarized.
