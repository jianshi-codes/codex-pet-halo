# Public Exposure Audit

Pet Halo separates deterministic source/history inspection from GitHub-hosted metadata review. The repository is public, so both remain ongoing release and maintenance controls rather than a pending visibility-change gate.

## Deterministic Git-history scan

Run from a complete clone with all branches and tags available:

```sh
make public-exposure-audit
```

The command enumerates every blob reachable from `git rev-list --objects --all` and scans blob contents without checking out historical files. It fails on:

- user-specific `/Users/<name>/...` paths;
- credentials, authorization headers, and common access-token forms;
- PEM private keys/certificates and tracked signing-material file types;
- literal release credential assignments;
- email addresses and concrete account identifiers;
- archive/package file extensions and common archive magic bytes.

Findings report only a category, abbreviated object ID, and repository path; secret content is never printed. The sole allowance is the exact synthetic value formed by `person` + `@example.com` in `Tests/test_normalization.py`, where it tests recursive redaction. Moving or changing that value fails the audit.

This scan covers reachable Git blobs, including material deleted from the current tree. It does not inspect GitHub databases, logs, artifacts, secrets, variables, Pages deployments, or other hosted state.

## Ongoing GitHub-hosted metadata and log audit

Record an auditor, date, and sanitized PASS/FAIL result before each release and after material repository-configuration changes:

- [ ] Open and closed PR bodies contain no private path, credential, identity, private screenshot, raw payload, or conversation content.
- [ ] PR comments, inline reviews, and submitted reviews are safe for public access.
- [ ] Issues, issue comments, discussions, and discussion replies are safe.
- [ ] Actions run logs have been checked for secrets, identities, private paths, raw payloads, signing output, and environment leakage.
- [ ] Actions artifacts have been inventoried and inspected; unnecessary artifacts are removed through an explicitly authorized maintenance action.
- [ ] Repository and organization Actions variables are intentionally public; encrypted secrets remain appropriate and are not copied into variables.
- [ ] Every environment, including `public-beta`, has intended protection, reviewers, variables, and secrets.
- [ ] Every Release, release asset, and reachable tag is safe and expected.
- [ ] GitHub Pages is not configured, or all published Pages content and deployment history are safe.
- [ ] Security advisories, deploy keys, webhooks, integrations, and environment protection rules have been reviewed for public-repository suitability.

Do not copy sensitive findings into a PR or issue. Deletion of runs, artifacts, Releases, tags, or history requires separate explicit authorization and is outside the deterministic audit.

## Current closeout boundary

The 2026-07-21 post-publication configuration snapshot is recorded in `docs/GITHUB_SETTINGS.md`. A passing source scan does not prove hosted-state safety, and the settings snapshot does not replace periodic hosted-content review.
