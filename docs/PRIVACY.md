# Privacy

Pet Halo is designed to expose only the minimum local usage state needed for its display.

The M2 application launches one owned local `codex app-server --stdio` child and requests only account availability, rate-limit windows, and Account Usage. It keeps normalized Usage state in memory for the process lifetime and stores none of it. It makes no direct network request and includes no analytics, telemetry, crash upload, or cloud service.

## Data boundaries

Production M2 may inspect read-only account availability, rate-limit windows, Account Usage summaries/daily buckets, and the owned connection state through the Codex app-server protocol. It must not refresh credentials, log in or out, purchase/reset credits, execute tasks, mutate threads, inspect conversation content, read Codex internal SQLite databases, or modify Codex Desktop or Codex Pet.

The Python protocol probe, generated schemas, redacted fixtures, and deterministic fake server are test/evidence assets only. Bundle validation rejects them from the application.

JSONL input is capped at 4 MiB per message and transport buffering is bounded. Standard error is drained and discarded. Diagnostics contain only fixed lifecycle text, safe enum reasons, and reconnect attempt numbers; raw JSON, process output, executable paths, environment values, remote error messages, account fields, and Usage values are never logged.

Account identity is neither decoded into the domain model nor retained. `account/updated`, authentication loss, stop, and every newly established app-server connection clear all account-scoped rate-limit and Usage data before publication. This deliberately prefers temporary unavailability over leaking values across accounts when continuity cannot be proven. Real-smoke logs use an owner-only securely created temporary directory and are deleted on exit.

## Never stored

- ChatGPT or Codex access tokens;
- authorization headers or cookies;
- email addresses or full account profiles;
- stable account identifiers;
- thread content, prompts, or responses;
- local home directories, project absolute paths, or other user-identifying data.

Committed fixtures are recursively redacted. A fixture is evidence of payload structure, not a replay of a user's account or thread.
