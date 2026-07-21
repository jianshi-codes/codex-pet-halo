# M9 — Public Beta Release Readiness

## Scope

M9 hardens compatibility, public onboarding, safe failure messages, reproducible ZIP packaging, external-only Developer ID/notarization operations, public repository templates, release automation, privacy/legal evidence, and clean-machine acceptance. It does not change the Pet Ring, Usage metrics, target discovery, fallback hierarchy, or add an updater.

PR #10 merged the M9 implementation on 2026-07-21. PR #11 merged the unsigned publication preparation the same day. The repository is public and Beta 1 is published; this document now distinguishes that source/unsigned success from the still-blocked signed-binary gate.

## Current compatibility evidence

- Local CLI: `0.145.0-alpha.18`; the only currently accepted CLI version.
- Current regenerated schemas: all individual files identical; aggregate canonical SHA-256 identical.
- Production semantic registry: initialize, account, rate-limit read/update, Account Usage, and JSON-RPC envelopes are all required.
- Current Desktop: `26.715.52143 (5591)`; the consolidated Route A and complete Pet-following gate passed.

## Published release evidence

GitHub Release `v0.1.0-beta.1` was published on 2026-07-21 with title `Pet Halo 0.1.0 Beta 1 — Unsigned Developer Preview`. It is non-draft, currently non-prerelease, and is the repository's latest release; the closeout preserved those classifications.

The GitHub Release target is `main`. Its tag resolves to `4fe6f0e4926a1acd6a8e6faaf1a34be430eaddc1`, exactly matching `release-manifest.json` `sourceCommit`. The manifest states `signing: unsigned` and `notarization: not-submitted`.

The complete asset set is:

| Asset | Size |
| --- | ---: |
| `Pet-Halo-0.1.0-beta.1-unsigned-universal.zip` | 1,331,364 bytes |
| `release-manifest.json` | 336 bytes |
| `RELEASE_NOTES.md` | 1,678 bytes |
| `SHA256SUMS` | 282 bytes |

`RELEASE_NOTES.md` was reconstructed byte-for-byte from the published tag because it was initially absent from the asset list. Its SHA-256 matched the already-published `SHA256SUMS`, so that exact file was uploaded without clobbering any asset. A fresh download of all assets passes `shasum -a 256 -c SHA256SUMS`.

The source tree provides explicit build, archive, checksum, signing, notarization, verification, and launch-smoke commands. The published unsigned ZIP is a convenience artifact, not an Apple-trusted binary. A signed/notarized future Beta requires a new release identity, an external Developer ID Application certificate, notarization credentials, an Apple `Accepted` response, stapling/Gatekeeper verification, and clean-machine acceptance.

The future release workflow resolves the imported Developer ID Application certificate to its exact SHA-1 fingerprint and binds each codesign invocation to the temporary release Keychain. It now requires explicit build/tag inputs and rejects a tag or GitHub Release that already exists before validation and again before signing. This wiring is source-tested but has not been run with real credentials.

## Public repository evidence

Source and reachable-history public readiness is covered by `make public-exposure-audit`, which inspects every reachable Git blob. The repository is now public. GitHub-hosted PR/comment/review content, issues/discussions, Actions logs and artifacts, variables, environments, Releases/tags, and Pages remain an ongoing operator audit surface because they are not Git blobs. The observed repository configuration and manual recommendations are recorded in `docs/GITHUB_SETTINGS.md`.

M9 also consolidates the overlapping M5–M7 validation into the single `make pet-following-gate` entry point. It runs the deterministic M7 superset once, then starts the app once and collects Route A uniqueness/stationary-window, center-lock, Pet Ring, Tuck Away fallback, Wake recovery, non-activation, and shutdown evidence without repeating tests or the same user interaction three times.

## Sanitized acceptance record

| Check | Outcome |
| --- | --- |
| Baseline `make check` | PASS |
| Baseline M8 smoke | PASS |
| Current CLI schema/semantic review | PASS |
| Reachable Git-history public-exposure audit | PASS — all reachable blobs; one exact synthetic fixture allowance |
| Unified M5–M7 Pet-following gate | PASS — 110 deterministic tests and one complete live interaction |
| Unsigned reproducible package | PASS — Release Universal ZIP, manifest, checksum, extraction, and launch/shutdown |
| Published source/unsigned release | PASS — public tag, Release, four assets, source-commit match, and fresh checksum verification |
| Repository configuration audit | PARTIAL — main ruleset and read-only Actions token confirmed; protected `public-beta` and private vulnerability reporting remain manual gaps |
| Developer ID signing/notarization | BLOCKED — zero valid local identities; no Apple submission attempted |
| Clean-machine acceptance | PARTIAL — isolated clean-preferences unsigned launch/quit passed; signed candidate unavailable |

## Gate

`PARTIAL — SOURCE RELEASE READY, SIGNED BINARY BLOCKED`

Source and unsigned publication are complete. The signed binary remains externally blocked on a valid Developer ID Application identity, notarytool credentials, credentialed workflow execution, Apple `Accepted`, stapling, Gatekeeper, and exact signed-artifact clean-machine acceptance. No signing or notarization PASS is claimed. Any future signed publication must use a new release identity such as Beta 2 and must not replace or retag Beta 1.
