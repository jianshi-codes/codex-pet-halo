# Release Runbook

This runbook is the deterministic operator contract for a future Pet Halo Beta.
It is written so Codex can execute the mechanical work end to end while stopping
at authority, credential, Apple, GitHub-environment, and clean-machine gates.

The current candidate inputs are:

| Input | Value |
| --- | --- |
| Product version | `0.1.0` |
| Bundle build | `3` |
| Tag | `v0.1.0-beta.3` |
| Distribution | `unsigned` |
| Release notes | `docs/release-notes/v0.1.0-beta.3.md` |
| Signed artifact | `Pet-Halo-0.1.0-beta.3-universal.zip` |
| Local unsigned evidence | `Pet-Halo-0.1.0-beta.3-unsigned-universal.zip` |

Every execution must re-read these values from the reviewed source. Do not reuse
this table after a release closeout advances the next candidate identity.

## Authority and immutable boundaries

- Preparing, validating, and building a local unsigned candidate do not
  authorize merge, signing, notarization, tag creation, or publication.
- Run the credentialed `publish=true` workflow only after the user explicitly
  authorizes publication for the exact source commit and release identity.
- GitHub environment approval, Developer ID credentials, and an Apple
  `Accepted` result are external facts. Codex must never invent, bypass, or
  infer them.
- Never overwrite, retag, reclassify, delete, or upload with `--clobber` to an
  existing release identity. A partial publication is an incident and stops
  automation.
- Keep release notes immutable once their tag is published. Correct a published
  artifact or note only with a new version.
- Never print credential values, identity names, Keychain contents, raw protocol
  payloads, account data, private paths, or unsanitized Accessibility evidence.

## State machine

Codex must record one state at a time:

1. `PREPARED` — candidate source and notes exist; no release state created.
2. `VALIDATED` — local gates, unsigned artifact, and `publish=false` workflow pass.
3. `APPROVED` — exact source/tag/distribution publication authority and every
   gate required by that distribution are present.
4. `PUBLISHED` — workflow created the new tag and prerelease.
5. `VERIFIED` — downloaded public assets, tag/source identity, signatures,
   notarization, checksums, launch, and clean-machine acceptance pass.
6. `DOCS_PR_OPEN` — post-release truth is committed to a separate Draft PR.

Any failed requirement leaves the process at its last completed state and stops.

## R0 — Start a release task

Inputs required from the user:

- exact product version, build number, and tag;
- exact distribution mode: `unsigned` or `signed-notarized`;
- whether the requested endpoint is validation only or publication;
- the intended source branch/commit;
- confirmation that the selected trust level is intentional;
- authorization for any GitHub settings or credential changes.

Record the scope, prohibited actions, stop condition, and current Draft/merge
state before running commands. If publication is not explicitly authorized, the
maximum endpoint is `VALIDATED`.

## R1 — Establish reviewed source

Use a dedicated release task and a clean checkout:

```sh
git fetch origin
git switch main
git pull --ff-only origin main
git status --short --branch
git rev-parse HEAD
```

Requirements:

- the feature/fix PR is reviewed, CI-green, and merged;
- local `main` exactly matches `origin/main`;
- the worktree is clean;
- the selected commit and release inputs are recorded;
- `project.yml` remains the Xcode source of truth.

Do not release directly from a feature branch or from a commit that changed
after approval.

## R2 — Prove the identity is unused

Run both checks and treat any result other than the documented “not found” state
as a blocker:

```sh
git ls-remote --exit-code --refs origin refs/tags/v0.1.0-beta.3
gh release view v0.1.0-beta.3 --json tagName,name,isDraft,isPrerelease,url
```

For an unused identity, `git ls-remote --exit-code` returns status `2` and
`gh release view` returns not found. Recheck before the validation workflow and
again immediately before publication.

## R3 — Synchronize candidate truth

Before validation, inspect and update together:

- `CHANGELOG.md` under `Unreleased`;
- `docs/release-notes/<tag>.md`;
- `docs/CURRENT_STATE.md`;
- `docs/COMPATIBILITY.md`;
- `docs/PRIVACY.md`;
- `docs/PROJECT_PLAN.md`;
- `docs/RELEASE_CHECKLIST.md`;
- `docs/GITHUB_SETTINGS.md`;
- `README.md`;
- release defaults and release-readiness tests.

Historical milestone reports and published release notes remain immutable.
Account Usage, Pet Ring metrics, version support, signing state, and release
status must reflect actual code/evidence rather than planned behavior.

Create or update a Draft preparation PR. Run checks and obtain review before
merging it. Do not combine the post-release closeout claims described in R9 with
prepublication preparation.

## R4 — Local validation and unsigned evidence

From the reviewed clean source, run:

```sh
make m8-tests
make check
make m2-smoke
make m3-smoke
make m4-smoke
make pet-following-gate
make m8-smoke
make public-exposure-audit
make release-unsigned-preview \
  MARKETING_VERSION=0.1.0 \
  BUILD_NUMBER=3 \
  RELEASE_TAG=v0.1.0-beta.3
```

Keep deterministic tests, live smoke, user interaction, and clean-machine
evidence as separate rows. A smoke test that could not observe its required
interaction is not a pass.

The unsigned command must produce, under `dist/v0.1.0-beta.3/`, only:

- the local unsigned Universal ZIP;
- `release-manifest.json`;
- `RELEASE_NOTES.md`;
- `SHA256SUMS`;
- the private staging directory used by the scripts.

Verify the manifest version/build/tag/source commit, `arm64` and `x86_64`,
minimum macOS, packaged-file allowlist, checksum set, `signing: unsigned`, and
`notarization: not-submitted`. Do not upload the unsigned candidate.

## R5 — GitHub validation workflow (`publish=false`)

The manual workflow must run from the same reviewed `main` commit:

```sh
gh workflow run release.yml \
  --ref main \
  -f marketing_version=0.1.0 \
  -f build_number=3 \
  -f release_tag=v0.1.0-beta.3 \
  -f distribution=unsigned \
  -f publish=false
```

Wait for the dispatched run and require the `Validate unsigned source release`
job to pass. Confirm no tag or GitHub Release was created. Record the run URL,
source SHA, inputs, and conclusion without copying sensitive logs.

Completion of R1–R5 reaches `VALIDATED`; it does not authorize R6.

## R6 — Distribution gate

For every publication:

- repository rules require the intended review/check policy;
- the exact `main` SHA still matches the `VALIDATED` SHA;
- a clean-machine acceptance host and operator are ready;
- the user explicitly authorizes `publish=true` for the exact distribution mode;
- release notes and artifact names state the actual trust level.

For `unsigned`, confirm the user accepts an **Unsigned Developer Preview**,
`signing: unsigned`, `notarization: not-submitted`, and possible Gatekeeper
blocking. This path requires no Developer ID or Apple credentials and must never
claim Apple trust.

For `signed-notarized`, also require:

- `public-beta` exists and has required reviewers;
- release secrets exist only as encrypted environment/repository secrets;
- no secret value is copied into a variable, file, chat, PR, or log;
- Developer ID, Keychain, and notary inputs match the workflow contract.

If the selected mode's requirements are unavailable, report `VALIDATED —
PUBLICATION BLOCKED` and stop. Creating/configuring an environment or secrets is
a separate GitHub administration action and requires explicit authority.

## R7 — Publish the selected distribution

Recheck the unused identity, source SHA, and release-note path immediately before
dispatch.

For an unsigned developer preview:

```sh
gh workflow run release.yml \
  --ref main \
  -f marketing_version=0.1.0 \
  -f build_number=3 \
  -f release_tag=v0.1.0-beta.3 \
  -f distribution=unsigned \
  -f publish=true
```

Require the unsigned publish job to rebuild and verify the unsigned Universal
ZIP, create a prerelease at the approved source SHA, and publish exactly the
unsigned ZIP, manifest, release notes, and checksums.

For a signed and notarized prerelease:

```sh
gh workflow run release.yml \
  --ref main \
  -f marketing_version=0.1.0 \
  -f build_number=3 \
  -f release_tag=v0.1.0-beta.3 \
  -f distribution=signed-notarized \
  -f publish=true
```

Wait for completion. For the signed path, require evidence that:

- the protected `public-beta` environment approved the job;
- exactly one Developer ID identity fingerprint was selected;
- signing and hardened runtime verification passed;
- Apple returned `Accepted`;
- stapling and notarized verification passed;
- temporary Keychain and API-key files were removed;
- `gh release create` produced a prerelease at the approved source SHA;
- only the signed Universal ZIP, manifest, release notes, and checksums were
  published.

For either path, do not claim `PUBLISHED` from a workflow dispatch alone.

## R8 — Public postflight and clean-machine acceptance

Download into a new temporary directory; never verify against local build output:

```sh
release_tmp="$(mktemp -d "${TMPDIR:-/tmp}/pet-halo-release-postflight.XXXXXX")"
gh release download v0.1.0-beta.3 --dir "$release_tmp"
(
  cd "$release_tmp"
  shasum -a 256 -c SHA256SUMS
)
```

Verify:

- the release is non-draft, prerelease, and targets the approved commit;
- the tag resolves/peels to the manifest `sourceCommit`;
- asset names and count are exact;
- manifest version/build/tag/identifier/minimum macOS/architectures are exact;
- the extracted executable is Universal;
- the downloaded `RELEASE_NOTES.md` is byte-identical to the tagged source;
- launch/quit and owned-child cleanup pass.

For `signed-notarized`, additionally require:

- `codesign --verify --deep --strict` passes with Developer ID;
- `spctl --assess --type execute` passes;
- `xcrun stapler validate` passes.

For `unsigned`, require that strict Developer ID verification does not pass,
manifest states `signing: unsigned` and `notarization: not-submitted`, and the
release is visibly labeled **Unsigned Developer Preview**.

Then perform clean-machine acceptance using only sanitized PASS/FAIL results:
first launch, Gatekeeper, bundle metadata/architectures/icons, CLI states,
Accessibility denied/granted, Pet visible/tucked away, Hide/Wake center,
light/dark, Reduce Motion, quit/relaunch, shutdown, and uninstall.

Any postflight failure stops the process. Do not delete, retag, clobber, or
silently replace published state.

## R9 — Post-release documentation Draft PR

Only after R8 passes, create a separate branch and Draft PR. Update current truth:

1. `README.md`
   - point Download badge/link and installation assets to the new release;
   - describe the actual signed/notarized state;
   - keep warnings accurate;
   - advance the build-from-source example to the next unused candidate.
2. `CHANGELOG.md`
   - move the shipped `Unreleased` entries into a dated release section;
   - reset `Unreleased` to `No changes yet.`
3. `docs/CURRENT_STATE.md`
   - record tag, source SHA, publication timestamp, release classification,
     asset names/sizes, manifest values, verification, and clean-machine result.
4. `docs/RELEASE_CHECKLIST.md`
   - check only gates with direct evidence;
   - retain incomplete or blocked signing/clean-machine items if any.
5. `docs/GITHUB_SETTINGS.md`
   - refresh tag/Release/environment observations from the API.
6. `docs/COMPATIBILITY.md`
   - distinguish reviewed versions, provisional session evidence, and the
     Desktop versions actually included in the new release.
7. Version defaults
   - set `project.yml` build number to the newly published build;
   - advance `Scripts/release-common.sh` to the next unused build/tag so a later
     local release command cannot reuse the published identity.
8. Tests
   - add/finalize published-release assertions;
   - freeze the tagged release-note hash;
   - retain immutable Beta 1/Beta 2 evidence;
   - assert the next candidate does not reuse a published identity.

Run:

```sh
make m8-tests
make check
make public-exposure-audit
git diff --check
```

Commit, push, open a Draft PR, and wait for required CI. Do not merge the
post-release documentation PR without its own review/authorization.

## R10 — Closeout handoff

The final handoff must report:

- exact release state and URL;
- approved/tagged source SHA;
- artifact names, checksums, signing/notarization/Gatekeeper results;
- clean-machine result;
- workflow and postflight evidence;
- post-release Draft PR URL and CI state;
- remaining risks or blocked external actions;
- confirmation that no prior release identity was changed.

Mark the release complete only when `VERIFIED` and the post-release documentation
truth is safely handed off. `DOCS_PR_OPEN` is not the same as merged closeout.
