# Contributing

M0 protocol feasibility is complete. Until M1 receives separate implementation authorization, contributions remain limited to M0 evidence, compatibility, privacy, probe, fixture, and documentation maintenance.

## Development rules

1. Keep changes small and milestone-scoped.
2. Never copy credentials, authentication headers, full account records, thread content, local absolute paths, or unsanitized app-server payloads into the repository.
3. Generate protocol bindings from the locally installed Codex CLI. Do not hand-edit generated schema files.
4. Keep the probe read-only: do not call `thread/start`, `turn/start`, or any mutation method.
5. Do not read or depend on Codex internal SQLite databases.
6. Add tests for parsing, normalization, timeout, and disconnect behavior.

## Validation

```sh
python3 -m unittest discover -s Tests -p 'test_*.py'
python3 -m compileall -q Tools/ProtocolProbe Tests
git diff --check
```

Describe the Codex CLI version used to generate schemas and redact all captured protocol fixtures before committing them.
