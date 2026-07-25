# Public Beta Release Checklist

This checklist records release state. Execute the ordered automation and
post-release closeout through the [Release runbook](RELEASE_RUNBOOK.md). Never
overwrite, retag, or upload with `--clobber` to an existing release identity.

## Published Beta 1 record — 2026-07-21

- [x] PRs #8, #9, #10, and #11 merged into `main`.
- [x] Repository made public and tag `v0.1.0-beta.1` created at reviewed commit `4fe6f0e4926a1acd6a8e6faaf1a34be430eaddc1`.
- [x] GitHub Release `Pet Halo 0.1.0 Beta 1 — Unsigned Developer Preview` published.
- [x] Unsigned Universal ZIP, manifest, release notes, and checksums published.
- [x] Manifest records `signing: unsigned` and `notarization: not-submitted`.
- [x] All four assets downloaded into a fresh directory; `shasum -a 256 -c SHA256SUMS` passed.
- [ ] Developer ID signing, Apple notarization, stapling, Gatekeeper verification, and signed clean-machine acceptance — not completed for Beta 1.

## Published Beta 2 record — 2026-07-21

- [x] PR #14 and PR #15 merged into `main`.
- [x] Annotated tag `v0.1.0-beta.2` created from reviewed `main`; it peels to source commit `4e14938e06b50162a810cdaa5b195357e5239342`.
- [x] GitHub Release `Pet Halo 0.1.0 Beta 2 — Unsigned Developer Preview` published at `2026-07-21T08:43:44Z`.
- [x] Manifest `sourceCommit` matches the peeled tag commit and records product version `0.1.0`, bundle build `2`.
- [x] Complete four-asset set published: `Pet-Halo-0.1.0-beta.2-unsigned-universal.zip`, `SHA256SUMS`, `release-manifest.json`, and `RELEASE_NOTES.md`.
- [x] All four assets downloaded from the public Release into a fresh directory with no missing or unexpected files.
- [x] `shasum -a 256 -c SHA256SUMS` passed for the ZIP, manifest, and release notes.
- [x] Extracted executable contains both `arm64` and `x86_64`; bundle version, build, identifier, and minimum macOS match the manifest.
- [x] Manifest records `signing: unsigned` and `notarization: not-submitted`.
- [x] Installed CLI `0.145.0-alpha.27` passed the sanitized provisional real bridge validation, including required Weekly runtime capability checks.
- [x] Release owned-child launch/shutdown smoke completed with clean child termination.
- [ ] Developer ID signing, Apple notarization, stapling, Gatekeeper signed verification, and signed clean-machine acceptance — not completed for Beta 2.

## Published Beta 3 record — 2026-07-25

- [x] PR #17 and PR #18 merged into `main`.
- [x] Final clean `main` and `origin/main` both resolved to
  `e8480a0443783e05dd871f5c248157633a84d9c5`.
- [x] `make check`, M2–M4 smoke, 112-test unified Pet-following gate, M8 smoke,
  public-exposure audit, and local unsigned preview verification completed.
- [x] The user confirmed the direct Move, Tuck Away, Wake, Quit, center, and
  Ring observation flow on the final source.
- [x] Validation-only workflow
  [30162649808](https://github.com/jianshi-codes/codex-pet-halo/actions/runs/30162649808)
  passed without creating release state.
- [x] Publication workflow
  [30162751853](https://github.com/jianshi-codes/codex-pet-halo/actions/runs/30162751853)
  passed at the same source SHA; the unsigned job completed and the
  signed/notarized job was skipped.
- [x] Tag `v0.1.0-beta.3` resolves to
  `e8480a0443783e05dd871f5c248157633a84d9c5`.
- [x] GitHub Release
  `Pet Halo 0.1.0 Beta 3 — Unsigned Developer Preview` published at
  `2026-07-25T15:03:26Z`.
- [x] The user intentionally classified the final Release as non-draft,
  non-prerelease, and latest.
- [x] Exactly four assets were published:
  `Pet-Halo-0.1.0-beta.3-unsigned-universal.zip`, `SHA256SUMS`,
  `release-manifest.json`, and `RELEASE_NOTES.md`.
- [x] A fresh public download matched every checksum and GitHub asset digest.
- [x] Manifest and extracted bundle match version `0.1.0`, build `3`, tag,
  source SHA, identifier, macOS 14 minimum, and Universal architectures.
- [x] Manifest states `signing: unsigned` and
  `notarization: not-submitted`; strict code-signing verification confirms the
  executable is not signed.
- [x] Downloaded release notes are byte-identical to tagged source.
- [x] The public artifact launched, created its owned local app-server, quit
  normally, and left no owned process.
- [ ] Developer ID signing — not completed for Beta 3.
- [ ] Apple notarization and stapling — not completed for Beta 3.
- [ ] Gatekeeper signed verification — not applicable and not claimed.
- [ ] Signed clean-machine acceptance — not completed for Beta 3; local isolated
  clean-preferences launch is recorded separately.

## Source and compatibility for a future Beta

- [x] Reserve the next unused identity as `v0.1.0-beta.4` and build `4`;
  `git ls-remote` and `gh release view` both reported it absent on 2026-07-25.
- [ ] Start from a reviewed, clean `main` commit.
- [ ] Confirm exact CLI and Desktop versions in `docs/COMPATIBILITY.md`.
- [ ] Generate current CLI schemas into a temporary directory and review every
  production semantic required by the new source.
- [ ] Run `make check`, M2–M4 smoke, the single
  `make pet-following-gate`, and M8 smoke.
- [ ] Run `make public-exposure-audit` from a full clone containing every branch
  and tag.
- [ ] Reconfirm immediately before release that the selected tag and Release are
  unused; the 2026-07-25 Beta 4 observation is not publication evidence.

## Unsigned preview build

```sh
make release-unsigned-preview MARKETING_VERSION=0.1.0 BUILD_NUMBER=4 RELEASE_TAG=v0.1.0-beta.4
```

- [ ] Verify Release configuration and Universal `arm64 x86_64`.
- [ ] Verify versions, identifier, minimum macOS, icons, and packaged-file allowlist.
- [ ] Verify `Pet-Halo-0.1.0-beta.4-unsigned-universal.zip`, manifest
  `unsigned` / `not-submitted`, release notes, and SHA-256.

## Developer ID and notarization

Provide credentials only through the external Keychain/environment contract in
the runbook. Never place identities, secrets, Keychain contents, or notarization
credentials in repository files or command output.

```sh
make release-sign MARKETING_VERSION=0.1.0 BUILD_NUMBER=4 RELEASE_TAG=v0.1.0-beta.4
make release-archive MARKETING_VERSION=0.1.0 BUILD_NUMBER=4 RELEASE_TAG=v0.1.0-beta.4
make release-notarize MARKETING_VERSION=0.1.0 BUILD_NUMBER=4 RELEASE_TAG=v0.1.0-beta.4
make release-verify MARKETING_VERSION=0.1.0 BUILD_NUMBER=4 RELEASE_TAG=v0.1.0-beta.4 RELEASE_MODE=notarized
```

- [ ] Record an actual Apple `Accepted` result; never infer it from submission.
- [ ] Verify stapling, `codesign`, `spctl`, archive checksum, and the extracted artifact.
- [ ] Confirm temporary credentials and Keychains were removed.

## Clean-machine acceptance

On a separate clean macOS host, record only sanitized PASS/FAIL outcomes for
first launch, Gatekeeper, bundle metadata/architectures/icons, CLI states,
Accessibility denied/granted, Pet visible/tucked away, Hide/Wake center,
light/dark, Reduce Motion, quit/relaunch, shutdown, and uninstall. A local
clean-preferences launch is useful evidence but is not a clean machine.

## Future publication hold point

Beta 1, Beta 2, and Beta 3 are immutable publication identities: never
overwrite, retag, reclassify as signed/notarized, or upload to them with
`--clobber`. A future release must use a new tag and build number.

- [ ] Recheck README, LICENSE, SECURITY, CONTRIBUTING, Code of Conduct, issue
  forms, release notes, and current compatibility evidence.
- [ ] Run the manual workflow from reviewed `main` with the exact future
  identity and `publish=false`.
- [ ] Obtain explicit authorization for the exact source, identity, distribution,
  and `publish=true` endpoint.
- [ ] For `signed-notarized`, require protected `public-beta` environment
  approval, credentials, Apple `Accepted`, stapling, Gatekeeper verification,
  and a clean-machine plan.
- [ ] Confirm the new Release contains only its intended ZIP, `SHA256SUMS`,
  `release-manifest.json`, and `RELEASE_NOTES.md`.
- [ ] Download the public files into a new directory and repeat every
  distribution-appropriate postflight check.
