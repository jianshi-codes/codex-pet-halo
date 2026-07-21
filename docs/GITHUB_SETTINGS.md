# GitHub Repository Settings

Observed on 2026-07-21 with `gh repo view` and GitHub REST API calls against `jianshi-codes/codex-pet-halo`. “Observed” means the API confirmed the state; “Recommended” is a manual action and is not claimed as enabled.

## Observed state

| Area | API-confirmed state |
| --- | --- |
| Visibility | Public |
| Description | `Unofficial macOS usage halo for Codex Pet.` |
| Topics | `accessibility`, `codex`, `codex-pet`, `macos`, `menu-bar-app`, `swift`, `usage-tracker` |
| Issues | Enabled |
| Default branch | `main` |
| Classic branch protection | Direct branch-protection endpoint returned 404 (`Branch not protected`) |
| Repository ruleset | Active `main-branch-protection` ruleset targets the default branch with no bypass actors |
| Ruleset history safety | Deletion and non-fast-forward updates are blocked; this prevents branch deletion and force-push through the active ruleset |
| Pull requests | One approving review required; merge and squash are allowed |
| Required checks | Strictly up-to-date `macOS application` and `Protocol evidence` |
| Actions | Enabled; all actions allowed |
| Actions default token | `read`; workflows cannot approve pull-request reviews |
| Fork contributor approval | First-time contributors require approval |
| Fork workflow API | Private-repository fork-workflow endpoint is not applicable to this public repository (HTTP 422) |
| Issue-form labels | `bug` and `compatibility` both exist |
| Private vulnerability reporting | Disabled |
| Environments | None returned; `public-beta` does not currently exist |
| Pages | No Pages site returned (HTTP 404) |
| Tags | `v0.1.0-beta.1` at `4fe6f0e4926a1acd6a8e6faaf1a34be430eaddc1` |
| Releases | One published Release: `v0.1.0-beta.1`; target `main`; non-draft, non-prerelease, latest |

The `compatibility` label, final description, and missing topics were added during this closeout. The existing `bug` label was preserved.

## Recommended manual settings

- Retain the active ruleset so `main` cannot be force-pushed or deleted, pull requests and one approval remain required, and `macOS application` plus `Protocol evidence` remain strict required checks.
- Retain read-only default Actions token permissions.
- Create the `public-beta` environment and protect it with required reviewers before adding or using release secrets. The workflow references this environment, but the API currently reports no environments.
- Keep release secrets out of fork pull-request execution. GitHub does not expose secret values through this audit, and the private-repository fork-workflow settings endpoint does not apply to this public repository; review workflow triggers and environment protection before credentialed use.
- Enable private vulnerability reporting so the Security Policy and security contact link lead to an available private reporting path.
- Keep Pages unconfigured unless a separately reviewed Pages publication is intended.

No branch-protection/ruleset, environment, vulnerability-reporting, Pages, visibility, tag, or Release setting was changed automatically in this closeout.
