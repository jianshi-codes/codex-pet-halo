# Contributing

M0 through M3 are complete. M4 Window Following is implemented and awaits direct Accessibility/manual movement validation. Contributions must remain within the M4 boundary until a later milestone receives separate authorization.

## Development rules

1. Keep changes small and milestone-scoped.
2. Never copy credentials, authentication headers, full account records, thread content, local absolute paths, or unsanitized app-server payloads into the repository.
3. Treat `project.yml` as the Xcode project source of truth. Use XcodeGen 2.46.0 and do not hand-edit the generated project.
4. Generate protocol bindings from the locally installed Codex CLI. Do not hand-edit generated schema files.
5. Keep all protocol work read-only: do not call `thread/start`, `turn/start`, account mutation, or any other mutation method.
6. Do not make production Swift code depend on the M0 probe, schemas, or fixtures.
7. Do not read or depend on Codex internal SQLite databases.
8. Keep the Halo non-activating, compact click-through outside calibration, account-identity-free, and driven by component freshness rather than aggregate timestamps.
9. M4 Accessibility access is restricted to the exact Codex bundle and reviewed window role/subrole, minimized, position, and size attributes plus lifecycle/geometry notifications. Never inspect titles, labels, values, document text, prompts, or responses.
10. Do not add screenshots, ScreenCaptureKit, OCR, automatic Pet recognition, Apple Events, private IPC, final artwork, animation, themes, or later milestone behavior during M4.

## Validation

```sh
make check
```

Use `make m4-tests` for deterministic process/window selection, geometry, anchor, calibration, fallback, observer, panel, and coordinator coverage. `make m2-smoke`, `make m3-smoke`, and `make m4-smoke` are local-only checks and print sanitized status.

Describe the Codex CLI version used to generate schemas and redact all captured protocol fixtures before committing them.
