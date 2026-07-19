# ADR 0001: M0 uses only generated schemas and read-only app-server calls

- Status: Accepted
- Date: 2026-07-20

## Decision

M0 will generate JSON Schema and TypeScript bindings from the installed Codex CLI and will probe only read-only app-server methods. Generated files are not edited. Codex internal SQLite storage, Desktop modification, Pet modification, task execution, and thread mutation are outside the project boundary.

## Consequences

Protocol or transport gaps become explicit unavailable states. M0 may be PARTIAL or BLOCKED rather than substituting remembered payload shapes, online examples, or estimated values.
