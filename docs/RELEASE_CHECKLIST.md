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
- [ ] Developer ID signing — not completed for Beta 2.
- [ ] Apple notarization — not completed for Beta 2.
- [ ] Stapling — not completed for Beta 2.
- [ ] Gatekeeper signed verification — not completed for Beta 2.
- [ ] Signed clean-machine acceptance — not completed for Beta 2.

## Beta 3 candidate preparation — 2026-07-25

The candidate identity is product version `0.1.0`, bundle build `3`, and tag
`v0.1.0-beta.3`. Preparation is read-only with respect to GitHub publication:
no tag or Release has been created.

- [x] `git ls-remote` returned the documented unused-tag result for
  `v0.1.0-beta.3`.
- [x] `gh release view v0.1.0-beta.3` returned not found.
- [x] `docs/release-notes/v0.1.0-beta.3.md` exists at the path consumed by the
  release scripts.
- [x] Release script defaults no longer reuse the immutable Beta 2 identity.
- [ ] Draft PR #17 receives required review and merges to `main`.
- [ ] Final `main` commit passes all source, compatibility, smoke, exposure, and
  unsigned artifact gates below.
- [ ] Create the `public-beta` environment and configure required reviewers
  before adding or using release secrets. The API still reports that this
  environment does not exist.
- [ ] Obtain explicit authorization before signing, notarizing, creating the
  tag, or publishing the GitHub prerelease.

## Source and compatibility for a future Beta

- [x] Prepare the next unused identity as `v0.1.0-beta.3` and build `3`.
- [ ] Start from a reviewed, clean `main` commit.
- [ ] Confirm the exact CLI and Desktop versions in `docs/COMPATIBILITY.md`.
- [ ] Regenerate current CLI schemas into a temporary directory and review every production semantic.
- [ ] Run `make check`, M2–M4 smoke, the single `make pet-following-gate`, and M8 smoke.
- [ ] Run `make public-exposure-audit` from a full clone containing every branch and tag.
- [ ] Complete the ongoing [GitHub-hosted metadata and log audit](PUBLIC_EXPOSURE_AUDIT.md#ongoing-github-hosted-metadata-and-log-audit).
- [ ] Reconfirm immediately before release that `git ls-remote` and
  `gh release view` both show the requested identity is unused; the 2026-07-25
  preparation observation is not sufficient for publication.

## Unsigned preview build

```sh
make release-unsigned-preview MARKETING_VERSION=0.1.0 BUILD_NUMBER=3 RELEASE_TAG=v0.1.0-beta.3
```

- [ ] Verify the bundle is Release and universal `arm64 x86_64`.
- [ ] Verify versions, identifier, minimum macOS, icons, and packaged-file allowlist.
- [ ] Verify the `Pet-Halo-0.1.0-beta.3-unsigned-universal.zip` name, manifest states `unsigned` / `not-submitted`, release notes, and SHA-256.

## Developer ID and notarization

Provide a `Developer ID Application` identity through local Keychain in `DEVELOPER_ID_APPLICATION`. A CI release exports the exact certificate SHA-1 fingerprint and sets `RELEASE_KEYCHAIN_PATH` to the temporary Keychain; local signing may omit that variable and use the normal Keychain search list. Provide notarization credentials through a `notarytool` Keychain profile (`NOTARYTOOL_PROFILE`, optional `NOTARYTOOL_KEYCHAIN`) or API-key environment variables (`APPLE_NOTARY_KEY_PATH`, `APPLE_NOTARY_KEY_ID`, `APPLE_NOTARY_ISSUER_ID`). Never place these values in the repository or command output.

```sh
make release-sign MARKETING_VERSION=0.1.0 BUILD_NUMBER=3 RELEASE_TAG=v0.1.0-beta.3
make release-archive MARKETING_VERSION=0.1.0 BUILD_NUMBER=3 RELEASE_TAG=v0.1.0-beta.3
make release-notarize MARKETING_VERSION=0.1.0 BUILD_NUMBER=3 RELEASE_TAG=v0.1.0-beta.3
make release-verify MARKETING_VERSION=0.1.0 BUILD_NUMBER=3 RELEASE_TAG=v0.1.0-beta.3 RELEASE_MODE=notarized
```

- [ ] Record actual Apple `Accepted` confirmation; never infer it from submission.
- [ ] Confirm credentialed signing used the imported certificate fingerprint and temporary Keychain path without printing either identity names or Keychain contents.
- [ ] Verify stapling, `codesign`, `spctl`, archive checksum, and extracted artifact.
- [ ] Confirm credentials and temporary keychains/API keys were removed.

## Clean-machine acceptance

On a clean macOS user account or equivalent isolated host, verify and record only sanitized PASS/FAIL outcomes for first launch, Gatekeeper, version/identifier/architectures/icons, missing/supported/unsupported CLI, Accessibility denied then granted, Pet visible/tucked away, visual-center adjustment, light/dark, Reduce Motion, quit/relaunch, complete shutdown, and uninstall. Never attach private screenshots or raw protocol/Accessibility data.

## Future publication hold point

Beta 1 and Beta 2 are immutable publication identities: never overwrite, retag, reclassify, or upload to either with `--clobber`. A future signed release must use a new tag and build number.

- [ ] Confirm the `public-beta` environment exists and has required reviewers
  before providing release secrets; it was absent at the 2026-07-25 preparation
  check.
- [ ] Recheck README, LICENSE, SECURITY, CONTRIBUTING, Code of Conduct, issue forms, and release notes.
- [ ] First run the manual workflow from reviewed `main` with product version
  `0.1.0`, build `3`, tag `v0.1.0-beta.3`, and `publish=false`; retain the
  validation result without creating release state.
- [ ] Only after the validation run, credentials, environment approval,
  clean-machine plan, and explicit publication authorization are ready, rerun
  from the same reviewed `main` commit with `publish=true`.
- [ ] Confirm the workflow rejects any existing tag or GitHub Release before signing and publication.
- [ ] Confirm the new signed GitHub Release is a prerelease and contains only the signed/notarized ZIP, `SHA256SUMS`, release notes, and manifest.
- [ ] Download the published files and repeat checksum, codesign, notarization, stapling, and Gatekeeper verification.
