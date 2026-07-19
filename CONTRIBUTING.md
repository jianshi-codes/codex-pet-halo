# Contributing

M0 protocol feasibility, M1 application skeleton, M2 CodexBridge, and M3 Halo Window are complete. Contributions must remain within the M3 boundary until a later milestone receives separate authorization.

## Development rules

1. Keep changes small and milestone-scoped.
2. Never copy credentials, authentication headers, full account records, thread content, local absolute paths, or unsanitized app-server payloads into the repository.
3. Treat `project.yml` as the Xcode project source of truth. Use XcodeGen 2.46.0 and do not hand-edit the generated project.
4. Generate protocol bindings from the locally installed Codex CLI. Do not hand-edit generated schema files.
5. Keep all protocol work read-only: do not call `thread/start`, `turn/start`, account mutation, or any other mutation method.
6. Do not make production Swift code depend on the M0 probe, schemas, or fixtures.
7. Do not read or depend on Codex internal SQLite databases.
8. Keep the Halo non-activating, click-through, account-identity-free, and driven by component freshness rather than aggregate timestamps.
9. Do not implement Codex/Pet discovery, Accessibility inspection, screen capture, calibration, saved placement, window following, final artwork, motion/themes, or later milestone behavior during M3.

## Validation

```sh
make check
```

Use `make m2-tests` for deterministic fake-transport coverage and `make m3-tests` for presentation, accessibility, panel, and coordinator coverage. `make m2-smoke` and `make m3-smoke` are explicit local authenticated checks, are not CI commands, and print only sanitized status.

Describe the Codex CLI version used to generate schemas and redact all captured protocol fixtures before committing them.
