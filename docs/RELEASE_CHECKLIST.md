# Public Beta Release Checklist

This checklist is an operator procedure. M9 does not publish a tag, GitHub Release, or public artifact.

## Source and compatibility

- [ ] Start from a reviewed, clean `main` commit.
- [ ] Confirm the exact CLI and Desktop versions in `docs/COMPATIBILITY.md`.
- [ ] Regenerate current CLI schemas into a temporary directory and review every production semantic.
- [ ] Run `make check`, M2–M4 smoke, the single `make pet-following-gate`, and M8 smoke.
- [ ] Confirm the repository privacy/secret scan is clean.

## Unsigned candidate

```sh
make release-build MARKETING_VERSION=0.1.0 BUILD_NUMBER=1 RELEASE_TAG=v0.1.0-beta.1
make release-archive MARKETING_VERSION=0.1.0 BUILD_NUMBER=1 RELEASE_TAG=v0.1.0-beta.1
make release-checksum MARKETING_VERSION=0.1.0 BUILD_NUMBER=1 RELEASE_TAG=v0.1.0-beta.1
make release-verify MARKETING_VERSION=0.1.0 BUILD_NUMBER=1 RELEASE_TAG=v0.1.0-beta.1 RELEASE_MODE=unsigned
```

- [ ] Verify the bundle is Release and universal `arm64 x86_64`.
- [ ] Verify versions, identifier, minimum macOS, icons, and packaged-file allowlist.
- [ ] Verify the deterministic ZIP name, manifest, release notes, and SHA-256.

## Developer ID and notarization

Provide a `Developer ID Application` identity through local Keychain in `DEVELOPER_ID_APPLICATION`. Provide notarization credentials through a `notarytool` Keychain profile (`NOTARYTOOL_PROFILE`, optional `NOTARYTOOL_KEYCHAIN`) or API-key environment variables (`APPLE_NOTARY_KEY_PATH`, `APPLE_NOTARY_KEY_ID`, `APPLE_NOTARY_ISSUER_ID`). Never place these values in the repository or command output.

```sh
make release-sign MARKETING_VERSION=0.1.0 BUILD_NUMBER=1 RELEASE_TAG=v0.1.0-beta.1
make release-archive MARKETING_VERSION=0.1.0 BUILD_NUMBER=1 RELEASE_TAG=v0.1.0-beta.1
make release-notarize MARKETING_VERSION=0.1.0 BUILD_NUMBER=1 RELEASE_TAG=v0.1.0-beta.1
make release-verify MARKETING_VERSION=0.1.0 BUILD_NUMBER=1 RELEASE_TAG=v0.1.0-beta.1 RELEASE_MODE=notarized
```

- [ ] Record actual Apple `Accepted` confirmation; never infer it from submission.
- [ ] Verify stapling, `codesign`, `spctl`, archive checksum, and extracted artifact.
- [ ] Confirm credentials and temporary keychains/API keys were removed.

## Clean-machine acceptance

On a clean macOS user account or equivalent isolated host, verify and record only sanitized PASS/FAIL outcomes for first launch, Gatekeeper, version/identifier/architectures/icons, missing/supported/unsupported CLI, Accessibility denied then granted, Pet visible/tucked away, visual-center adjustment, light/dark, Reduce Motion, quit/relaunch, complete shutdown, and uninstall. Never attach private screenshots or raw protocol/Accessibility data.

## Publication hold point

- [ ] Obtain explicit authorization to make the repository public.
- [ ] Recheck README, LICENSE, SECURITY, CONTRIBUTING, Code of Conduct, issue forms, and release notes.
- [ ] Create annotated tag `v0.1.0-beta.1` only from the accepted commit.
- [ ] Run the manual release workflow with the protected `public-beta` environment and `publish=true`.
- [ ] Confirm the GitHub Release is a prerelease and contains only the ZIP, `SHA256SUMS`, release notes, and optional manifest.
- [ ] Download the published files and repeat checksum and notarized verification.
