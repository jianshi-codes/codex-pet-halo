# Public Exposure Audit

Pet Halo separates source/history inspection from GitHub-hosted metadata review.
Both must be complete before repository visibility changes.

## Deterministic Git-history scan

Run from a complete clone with all branches and tags available:

```sh
make public-exposure-audit
```

The command enumerates every blob reachable from `git rev-list --objects --all`
and scans blob contents without checking out historical files. It fails on:

- user-specific `/Users/<name>/...` paths;
- credentials, authorization headers, and common access-token forms;
- PEM private keys/certificates and tracked signing-material file types;
- literal release credential assignments;
- email addresses and concrete account identifiers;
- archive/package file extensions and common archive magic bytes.

Findings report only a category, abbreviated object ID, and repository path;
secret content is never printed. The sole allowance is the exact synthetic
value formed by `person` + `@example.com` in `Tests/test_normalization.py`, where
it tests recursive redaction. Moving or changing that value fails the audit.

This scan covers reachable Git blobs, including material deleted from the
current tree. It does not inspect GitHub databases, logs, artifacts, secrets,
variables, Pages deployments, or other hosted state.

## Manual GitHub-hosted metadata and log audit

Record an auditor, date, and sanitized PASS/FAIL result for every item:

- [ ] Every open and closed PR body contains no private path, credential,
      identity, private screenshot, raw payload, or conversation content.
- [ ] Every PR comment, inline review, and submitted review is safe to expose.
- [ ] Every issue, issue comment, discussion, and discussion reply is safe.
- [ ] Every Actions run log has been checked for secrets, identities, private
      paths, raw payloads, signing output, and environment leakage.
- [ ] Every Actions artifact has been inventoried and inspected or deleted.
- [ ] Repository and organization Actions variables are intentionally public;
      encrypted secrets remain appropriate and are not copied into variables.
- [ ] Every environment, including `public-beta`, has intended protection,
      reviewers, variables, and secrets.
- [ ] Every old Release, release asset, and reachable tag is safe and expected.
- [ ] GitHub Pages is disabled, or all published Pages content and deployment
      history are safe to expose.
- [ ] Security advisories, deploy keys, webhooks, integrations, and environment
      protection rules have been reviewed for public-repository suitability.

Questionable old Actions runs and artifacts must be deleted before the
repository becomes public. Deletion and any retained exceptions must be
recorded without copying sensitive content into a PR or issue.

## Readiness boundary

A passing deterministic scan establishes source and reachable-history public
readiness. The manual GitHub-hosted audit remains a separate visibility-change
hold point because that state is not stored in Git and cannot be proven by the
local command.
