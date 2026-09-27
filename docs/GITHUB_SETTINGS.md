# GitHub Repository Settings

Repository settings were observed on 2026-07-21 with `gh repo view` and GitHub
REST API calls against `jianshi-codes/codex-pet-halo`. Tag, Release, and Latest
state were refreshed after the Beta 8 publication on 2026-09-27, before R10
promotion. The active ruleset and empty environment list were also rechecked
on 2026-09-27; the remaining settings observations are from
2026-07-31. “Observed” means the API confirmed
the state; “Recommended” is a manual action and is not claimed as enabled.

## Observed state

| Area | API-confirmed state |
| --- | --- |
| Visibility | Public |
| Description | `Transparent Usage ring around Codex Pet` |
| Topics | `accessibility`, `codex`, `codex-pet`, `macos`, `menu-bar-app`, `swift`, `usage-tracker` |
| Issues | Enabled |
| Default branch | `main` |
| Classic branch protection | Direct branch-protection endpoint returned 404 (`Branch not protected`) |
| Repository ruleset | Active `main-branch-protection` ruleset targets the default branch; one `RepositoryRole` bypass actor (ID `5`) is configured and the current administrator can bypass |
| Ruleset history safety | Deletion and non-fast-forward updates are blocked; this prevents branch deletion and force-push through the active ruleset |
| Pull requests | One approving review required; merge and squash are allowed |
| Required checks | Strictly up-to-date `macOS application` and `Protocol evidence` |
| Actions | Enabled; all actions allowed |
| Actions default token | `read`; workflows cannot approve pull-request reviews |
| Fork contributor approval | First-time contributors require approval |
| Fork workflow API | Private-repository fork-workflow endpoint is not applicable to this public repository (HTTP 422) |
| Issue labels | `bug`, `compatibility`, `dependencies`, `documentation`, `duplicate`, `enhancement`, `github_actions`, `good first issue`, `help wanted`, `invalid`, `question`, and `wontfix` |
| Private vulnerability reporting | Disabled |
| Environments | None returned; `public-beta` does not currently exist |
| Pages | No Pages site returned (HTTP 404) |
| Tags | `v0.1.0-beta.8` resolves directly to `8ea5000ce07ef6507ad95983aff6701138ffc25c`; earlier tags remain unchanged |
| Releases at publication | `v0.1.0-beta.8`: target/source `8ea5000ce07ef6507ad95983aff6701138ffc25c`, published `2026-09-27T13:36:27Z`, non-draft unsigned prerelease with four assets; `/releases/latest` returned `v0.1.0-beta.7` before R10 promotion |
| Next identity | `v0.1.0-beta.9` / build `9` is the next candidate; `git ls-remote` and `gh release view` both reported it absent on 2026-09-27 |

The complete observed label list includes the `bug` and `compatibility` labels required by the issue forms.

Beta 7 was initially published as a non-draft unsigned prerelease while
`v0.1.0-beta.6` remained Latest. Its later non-prerelease/Latest state was a fresh
2026-09-27 metadata observation before Beta 8 promotion; it is not clean-machine acceptance
evidence. Historical tag `v0.1.0-beta.7` resolves directly to
`d8feb391f0144d23c4136c73782c6d750c6842b8` and was published at
`2026-09-16T13:07:43Z`.

The user explicitly authorized Beta 8 Latest promotion after the separate
post-release documentation merge, with independent clean-machine acceptance
recorded as not run. PR #30 was administrator-merged after both required checks
passed, bypassing the approving reviewer under the user's explicit instruction.
The same authorization covers the post-release documentation merge; the ruleset
itself remains unchanged.

## Recommended manual settings

- Retain the active ruleset so `main` cannot be force-pushed or deleted, pull requests and one approval remain required, and `macOS application` plus `Protocol evidence` remain strict required checks.
- Retain read-only default Actions token permissions.
- Create the `public-beta` environment and protect it with required reviewers before adding or using release secrets. The workflow references this environment, but the API currently reports no environments.
- Keep release secrets out of fork pull-request execution. GitHub does not expose secret values through this audit, and the private-repository fork-workflow settings endpoint does not apply to this public repository; review workflow triggers and environment protection before credentialed use.
- Enable private vulnerability reporting so the Security Policy and security contact link lead to an available private reporting path.
- Keep Pages unconfigured unless a separately reviewed Pages publication is intended.

The 2026-07-25 refresh confirmed zero environments, including no `public-beta`.
The active ruleset details above were not re-audited in that narrower refresh.
The Beta 8 publication workflow created the new tag and four-asset unsigned
prerelease. No
branch-protection/ruleset, environment, vulnerability-reporting, Pages, or
visibility setting was changed during this release.
