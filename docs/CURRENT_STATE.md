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
- CLI `0.145.0-alpha.18` remains the exact reviewed baseline. Current regenerated individual schemas are identical to retained evidence and the canonical aggregate hash matches.
- Newer CLI versions from the reviewed floor through pre-1.0 may run provisionally after required runtime capability validation. The production registry remains reviewed-only; provisional success does not create schema or semantic-review evidence.
- Installed CLI `0.145.0-alpha.27` passes the provisional runtime path, including required Weekly percentage/reset decoding and clean owned-child shutdown; optional 5h is absent and Account Usage is available on the validation host.
- Malformed, too-old, explicitly denied, and 1.x versions remain blocked before child launch. Required provisional protocol breakage closes the owned child and suppresses automatic reconnect until user Refresh or restart.
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
- M2 smoke: PASS — CLI `0.145.0-alpha.27` selected provisional, passed required read-only runtime capabilities, launched the accessory app, and completed clean owned-child shutdown.
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
