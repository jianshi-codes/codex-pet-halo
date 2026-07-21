# Current State

- Milestone: M9 — Public Beta Release Readiness
- Status: **PARTIAL — SOURCE RELEASE READY, SIGNED BINARY BLOCKED**
- Branch: `m9/public-beta-readiness`
- Product/UI: frozen at the accepted M8 behavior
- Candidate: `v0.1.0-beta.1` with bundle version `0.1.0 (1)`
- Publication: prohibited in this Draft PR; no tag, GitHub Release, public artifact, or visibility change

## Current evidence

- CLI `0.145.0-alpha.18` remains the only supported protocol version. Current regenerated individual schemas are identical to retained evidence and the canonical aggregate hash matches.
- The production registry now requires explicit review of initialize, account, rate limits, Usage, notifications, and JSON-RPC envelopes; decoding success alone cannot enable a version.
- Desktop `26.715.31925 (5551)` remains supported. Current Desktop `26.715.52143 (5591)` passed the consolidated Route A and complete Pet-following gate.
- User-facing bridge, following, and Pet failure states are concise and omit raw errors, payloads, identity, paths, and process details.
- User-first README, public contribution/security policy, Code of Conduct, changelog, issue forms, versioning/release documentation, and privacy boundaries are implemented.
- Source and every reachable Git blob pass the deterministic public-exposure audit. GitHub-hosted metadata/log/artifact review remains a separate manual visibility-change hold point.
- Unsigned Release build, deterministic archive naming, manifest, SHA-256, extraction verification, and isolated clean-preferences launch/shutdown smoke pass. Release binaries contain no user-specific path and exclude schemas, fixtures, smoke/report assets, logs, and debug material.
- Developer ID/notarization scripts and a manually gated pinned-action GitHub prerelease workflow are implemented. CI exports the imported certificate SHA-1 fingerprint and binds every codesign call to its temporary Keychain; credentialed execution has not occurred because this host has no valid signing identity.

## Validation state

M5–M7 use one non-duplicated validation surface. `make pet-following-gate`
runs the deterministic M7 superset once, then performs one live
move → Tuck Away → Wake → Quit flow while collecting Route A, center-lock,
Ring, fallback, recovery, non-activation, and owned-child shutdown evidence.
Its `pet-following-tests` and `pet-following-smoke` components remain separately
callable for focused reruns.
The retained `make m7-tests` and `make m7-smoke` names are compatibility aliases;
the duplicate M5/M6 commands were removed.

- `make test`: PASS — 54 Core tests (one designed local-only skip) and 119 App tests.
- M2 smoke: PASS — current read-only CLI bridge, default-hidden accessory app, and clean owned-child shutdown.
- M3 smoke: PASS.
- M4 smoke: deterministic PASS; current live standard-window target was unavailable during the probe.
- Unified M5–M7 gate: PASS — 110 deterministic tests plus one direct movement/Tuck Away/Wake/Quit flow.
- M8 smoke: deterministic PASS.
- Unsigned release archive verification and extracted launch/quit: PASS.
- Equivalent isolated-host unsigned launch/quit: PASS; signed/notarized clean-machine acceptance is blocked by external Developer ID credentials.
- `make public-exposure-audit`: PASS — all reachable Git blobs, including deleted history, inspected with one exact synthetic fixture allowance.

## Stop conditions

Complete the manual GitHub-hosted metadata/log/artifact checklist before changing repository visibility. Do not report binary Public Beta readiness without credentialed Developer ID signing, Apple `Accepted`, stapling, Gatekeeper verification, and exact signed-artifact clean-machine acceptance. Do not publish from the M9 Draft PR.
