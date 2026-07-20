# Privacy

Pet Halo is designed to expose only the minimum local usage state needed for its display.

The M4 application launches one owned local `codex app-server --stdio` child and requests only account availability, rate-limit windows, and Account Usage. It keeps normalized Usage and UI presentation state in memory and stores none of it. It makes no direct network request and includes no analytics, telemetry, crash upload, or cloud service.

## Data boundaries

Production M4 may display read-only account availability, rate-limit windows, Account Usage summaries/daily buckets, and the owned connection state from the Codex app-server protocol. It does not display account identity, Context, raw errors, or raw protocol data. It must not refresh credentials, log in or out, purchase/reset credits, execute tasks, mutate threads, inspect conversation content, read Codex internal SQLite databases, or modify Codex Desktop or Codex Pet.

Window following is off by default. After an explicit user command, M4 may use Accessibility to identify an eligible standard window belonging to the exact `com.openai.codex` application, read only role/subrole, minimized state, position, and size, and observe geometry/window lifecycle notifications. It never reads window titles, accessibility labels, values, document text, conversation content, prompts, or responses. It does not capture the screen, use OCR, or request Screen Recording or Apple Events permission.

M4 persists only these namespaced local UI preferences:

- `io.github.jianshicodes.PetHalo.windowFollowing.enabled`: Boolean user choice;
- `io.github.jianshicodes.PetHalo.windowFollowing.anchor.v1`: JSON containing `version`, normalized `x/y`, and point-offset `width/height`.

Decoded values must be finite, normalized coordinates must remain in `0...1`, offsets are capped at 10,000 points, and unsupported versions are ignored. No PID, AX element, window title, geometry snapshot, screen index, executable path, account field, or Usage value is persisted.

The Python protocol probe, generated schemas, redacted fixtures, deterministic fake server, smoke reports, and debug harness material are test/evidence assets only. Bundle validation rejects them from the application.

JSONL input is capped at 4 MiB per message and transport buffering is bounded. Standard error is drained and discarded. Diagnostics contain only fixed lifecycle text, safe enum reasons, and reconnect attempt numbers; raw JSON, process output, executable paths, environment values, remote error messages, account fields, and Usage values are never logged.

Account identity is neither decoded into the domain model nor retained. `account/updated`, authentication loss, stop, and every newly established app-server connection clear all account-scoped rate-limit and Usage data before publication. This deliberately prefers temporary unavailability over leaking values across accounts when continuity cannot be proven. Real-smoke logs use an owner-only securely created temporary directory and are deleted on exit.

## Never stored

- ChatGPT or Codex access tokens;
- authorization headers or cookies;
- email addresses or full account profiles;
- stable account identifiers;
- thread content, prompts, or responses;
- local home directories, project absolute paths, or other user-identifying data.

Committed fixtures are recursively redacted. A fixture is evidence of payload structure, not a replay of a user's account or thread. M4 smoke output also omits coordinates, PIDs, titles, paths, raw AX failures, and Usage values.
