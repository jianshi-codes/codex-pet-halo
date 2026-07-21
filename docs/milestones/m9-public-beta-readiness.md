# M9 — Public Beta Release Readiness

## Scope

M9 hardens compatibility, public onboarding, safe failure messages, reproducible ZIP packaging, external-only Developer ID/notarization operations, public repository templates, release automation, privacy/legal evidence, and clean-machine acceptance. It does not change the Pet Ring, Usage metrics, target discovery, fallback hierarchy, or add an updater.

## Current compatibility evidence

- Local CLI: `0.145.0-alpha.18`; already supported and retained.
- Current regenerated schemas: all individual files identical; aggregate canonical SHA-256 identical.
- Production semantic registry: initialize, account, rate-limit read/update, Account Usage, and JSON-RPC envelopes are all required.
- Current Desktop: `26.715.52143 (5591)`; the consolidated Route A and complete Pet-following gate passed.

## Release evidence

The source tree provides explicit build, archive, checksum, signing, notarization, verification, and launch-smoke commands. Unsigned output is a development artifact. A signed/notarized Public Beta requires an external Developer ID Application certificate, notarization credentials, an Apple `Accepted` response, stapling/Gatekeeper verification, and clean-machine acceptance.

M9 also consolidates the overlapping M5–M7 validation into the single
`make pet-following-gate` entry point. It runs the deterministic M7 superset
once, then starts the app once and collects Route A uniqueness/stationary-window,
center-lock, Pet Ring, Tuck Away fallback, Wake recovery, non-activation, and
shutdown evidence without repeating tests or the same user interaction three times.

## Sanitized acceptance record

| Check | Outcome |
| --- | --- |
| Baseline `make check` | PASS |
| Baseline M8 smoke | PASS |
| Baseline M7 live smoke | INCOMPLETE — Pet was tucked away; no compatibility claim |
| Current CLI schema/semantic review | PASS |
| Unified M5–M7 Pet-following gate | PASS — 110 deterministic tests and one complete live interaction |
| Unsigned reproducible package | PASS — Release Universal ZIP, manifest, checksum, extraction, and launch/shutdown |
| Developer ID signing/notarization | BLOCKED — zero valid local identities; no Apple submission attempted |
| Clean-machine acceptance | PARTIAL — isolated clean-preferences unsigned launch/quit passed; signed candidate unavailable |

## Gate

`PARTIAL — SOURCE RELEASE READY, SIGNED BINARY BLOCKED`

The sole external blocker is a valid Developer ID Application identity plus
notarytool credentials and the resulting Apple-accepted, stapled candidate.
No signing or notarization PASS is claimed, and M9 does not publish a tag,
GitHub Release, public artifact, or repository visibility change.
