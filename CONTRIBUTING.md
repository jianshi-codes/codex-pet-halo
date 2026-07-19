# Contributing

M0 protocol feasibility is complete and M1 application-skeleton implementation is authorized. Contributions must remain within the active M1 boundary until a later milestone receives separate authorization.

## Development rules

1. Keep changes small and milestone-scoped.
2. Never copy credentials, authentication headers, full account records, thread content, local absolute paths, or unsanitized app-server payloads into the repository.
3. Treat `project.yml` as the Xcode project source of truth. Use XcodeGen 2.46.0 and do not hand-edit the generated project.
4. Generate protocol bindings from the locally installed Codex CLI. Do not hand-edit generated schema files.
5. Keep the M0 probe read-only: do not call `thread/start`, `turn/start`, or any mutation method.
6. Do not make production Swift code depend on the M0 probe, schemas, or fixtures.
7. Do not read or depend on Codex internal SQLite databases.
8. Do not implement CodexBridge, Usage models, Halo windows, window tracking, or later milestone behavior during M1.

## Validation

```sh
make check
```

Describe the Codex CLI version used to generate schemas and redact all captured protocol fixtures before committing them.
