# Contributing to Pet Halo

Thank you for helping improve Pet Halo. The core product and release UI are frozen for the Public Beta milestone: contributions should focus on compatibility, correctness, privacy, accessibility, tests, documentation, packaging, and release readiness.

## Before opening a change

1. Search existing issues and compatibility reports.
2. Keep one change focused on one observable problem.
3. For protocol work, generate schemas from your installed Codex CLI and review production semantics. Do not infer support from successful decoding.
4. For Accessibility work, stay within exact `com.openai.codex` geometry/structure attributes. Do not add titles, content inspection, screenshots, Screen Recording, or OCR.
5. Never include credentials, account identity, raw protocol payloads, private conversations, private screenshots, raw Accessibility errors, executable paths, or user-specific paths.

## Development setup

Pet Halo requires macOS 14+, Swift 6, Xcode, and XcodeGen 2.46.0. `project.yml` is the source of truth; do not hand-edit `PetHalo.xcodeproj/project.pbxproj`.

```sh
make bootstrap
make generate
make check
```

Use the focused milestone test target for the area you changed. M5–M7 changes use the single `make pet-following-gate`; it runs the deterministic superset once and one complete live interaction. Real smoke commands are local-only and must report sanitized outcomes. Separate automated checks from direct manual observations in the PR.

## Pull requests

- Explain the user/developer outcome and why the change is needed.
- List exact validation commands and any manual evidence.
- Keep release PRs Draft until required review and CI are complete.
- Do not publish tags, Releases, or artifacts from a feature PR.
- Update user documentation when behavior changes.
- Confirm no unrelated changes, secrets, PII, private screenshots, or raw payloads are included.

See [Versioning](docs/VERSIONING.md), [Release checklist](docs/RELEASE_CHECKLIST.md), [Security](SECURITY.md), and the [Code of Conduct](CODE_OF_CONDUCT.md).
