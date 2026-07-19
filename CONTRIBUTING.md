# Contributing

M0 protocol feasibility, M1 application skeleton, and M2 CodexBridge are complete. Contributions must remain within the M2 boundary until a later milestone receives separate authorization.

## Development rules

1. Keep changes small and milestone-scoped.
2. Never copy credentials, authentication headers, full account records, thread content, local absolute paths, or unsanitized app-server payloads into the repository.
3. Treat `project.yml` as the Xcode project source of truth. Use XcodeGen 2.46.0 and do not hand-edit the generated project.
4. Generate protocol bindings from the locally installed Codex CLI. Do not hand-edit generated schema files.
5. Keep all protocol work read-only: do not call `thread/start`, `turn/start`, account mutation, or any other mutation method.
6. Do not make production Swift code depend on the M0 probe, schemas, or fixtures.
7. Do not read or depend on Codex internal SQLite databases.
8. Do not implement Halo windows, Usage presentation, window tracking, or later milestone behavior during M2.

## Validation

```sh
make check
```

Use `make m2-tests` for deterministic fake-transport coverage. Use `make m2-smoke` only for an explicit local authenticated read-only runtime check; it is not a CI command and prints only a sanitized capability summary.

Describe the Codex CLI version used to generate schemas and redact all captured protocol fixtures before committing them.
