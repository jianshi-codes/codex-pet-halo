# Current State

- Milestone: M9 — Public Beta Release Readiness
- Status: **PARTIAL — SOURCE RELEASE READY, SIGNED BINARY BLOCKED**
- Closeout branch: `docs/public-release-closeout`
- Product/UI: frozen at the accepted M8 behavior
- Published release: `v0.1.0-beta.1`, bundle version `0.1.0 (1)`, published 2026-07-21
- Repository: public at `jianshi-codes/codex-pet-halo`
- Artifact: unsigned Universal ZIP; Developer ID signing and Apple notarization are not complete

## Current evidence

- PRs #8, #9, #10, and #11 are merged into `main`.
- CLI `0.145.0-alpha.18` remains the only supported protocol version. Current regenerated individual schemas are identical to retained evidence and the canonical aggregate hash matches.
- The production registry requires explicit review of initialize, account, rate limits, Usage, notifications, and JSON-RPC envelopes; decoding success alone cannot enable a version.
- Desktop `26.715.31925 (5551)` and `26.715.52143 (5591)` have the compatibility evidence recorded in `docs/COMPATIBILITY.md`.
- User-facing bridge, following, and Pet failure states are concise and omit raw errors, payloads, identity, paths, and process details.
- Source and every reachable Git blob pass the deterministic public-exposure audit. The repository is public; hosted metadata remains an ongoing operator audit surface documented in `docs/PUBLIC_EXPOSURE_AUDIT.md`.
- The published `Pet-Halo-0.1.0-beta.1-unsigned-universal.zip`, `release-manifest.json`, `RELEASE_NOTES.md`, and `SHA256SUMS` are downloadable. A fresh-directory `shasum -a 256 -c SHA256SUMS` verification passes.
- The published tag resolves to manifest `sourceCommit` `4fe6f0e4926a1acd6a8e6faaf1a34be430eaddc1`; the manifest states `signing: unsigned` and `notarization: not-submitted`.
- Developer ID/notarization scripts and a manually gated pinned-action future Beta workflow exist. Credentialed signing has not passed because no valid signing identity was available for Beta 1.
- Automatic Pet attachment has no normalized Pet positional anchor. The current preferences retain only the M4 Codex-window anchor and the bounded M7 Ring visual-center offset.

## Validation state

M5–M7 use one non-duplicated validation surface. `make pet-following-gate`
runs the deterministic M7 superset once, then performs one live
move → Tuck Away → Wake → Quit flow while collecting Route A, center-lock,
Ring, fallback, recovery, non-activation, and owned-child shutdown evidence.
Its `pet-following-tests` and `pet-following-smoke` components remain separately
callable for focused reruns. The retained `make m7-tests` and `make m7-smoke`
names are compatibility aliases; the duplicate M5/M6 commands were removed.

- `make test`: PASS — 54 Core tests (one designed local-only skip) and 119 App tests at M9 implementation closeout.
- M2 smoke: PASS — current read-only CLI bridge, default-hidden accessory app, and clean owned-child shutdown.
- M3 smoke: PASS.
- M4 smoke: deterministic PASS; current live standard-window target was unavailable during the probe.
- Unified M5–M7 gate: PASS — 110 deterministic tests plus one direct movement/Tuck Away/Wake/Quit flow.
- M8 smoke: deterministic PASS.
- Unsigned release archive verification and extracted launch/quit: PASS.
- Equivalent isolated-host unsigned launch/quit: PASS; signed/notarized clean-machine acceptance remains blocked by external Developer ID credentials.
- `make public-exposure-audit`: PASS — all reachable Git blobs inspected with one exact synthetic fixture allowance.
- Published Release checksum verification: PASS — ZIP, manifest, and release notes match `SHA256SUMS`.

## Remaining release gate

Source and unsigned publication succeeded. Binary release readiness still requires a new release identity, credentialed Developer ID signing, Apple `Accepted`, stapling, Gatekeeper verification, and exact signed-artifact clean-machine acceptance. Beta 1 must not be overwritten, retagged, or presented as signed/notarized.
