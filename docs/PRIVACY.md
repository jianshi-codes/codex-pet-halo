# Privacy

Pet Halo is designed to expose only the minimum local usage state needed for its display.

The M6 application launches one owned local `codex app-server --stdio` child and requests only account availability, rate-limit windows, and Account Usage. It keeps normalized Usage and UI presentation state in memory and stores none of it. It makes no direct network request and includes no analytics, telemetry, crash upload, or cloud service.

## Data boundaries

Production M6 may display read-only account availability, rate-limit windows, Account Usage summaries/daily buckets, and the owned connection state from the Codex app-server protocol. It does not display account identity, Context, raw errors, or raw protocol data. It must not refresh credentials, log in or out, purchase/reset credits, execute tasks, mutate threads, inspect conversation content, read Codex internal SQLite databases, or modify Codex Desktop or Codex Pet.

Following is off by default. After an explicit user command, M6 may use Accessibility inside the exact `com.openai.codex` application. The M4 fallback identifies the standard window; the preferred target identifies a unique near-square `AXWindow/AXDialog` logical frame. A unique wide nearby dialog may supply only an ephemeral above/below hint; ambiguity removes that hint without invalidating Pet. Production reads only the application window list, role/subrole, minimized/hidden state, position, and size and observes geometry/window lifecycle notifications. It never reads window titles, accessibility labels, descriptions, identifiers, values, document text, conversation content, prompts, or responses. It does not capture the screen, use OCR, or request Screen Recording or Apple Events permission.

M6 persists only these namespaced local UI preferences:

- `io.github.jianshicodes.PetHalo.windowFollowing.enabled`: Boolean user choice;
- `io.github.jianshicodes.PetHalo.windowFollowing.anchor.v1`: M4 JSON containing `version`, normalized window `x/y`, and point-offset `width/height`;
- `io.github.jianshicodes.PetHalo.petFollowing.anchor.v1`: JSON fine-tuned override containing `version`, normalized Pet `x/y`, and point-offset `width/height`.

Decoded values must be finite, normalized coordinates must remain in `0...1`, offsets are capped at 10,000 points, and unsupported versions are ignored. Existing valid Pet anchors migrate as fine-tuned overrides. Use Automatic Pet Placement erases only the Pet override and never the M4 fallback anchor. Automatic coordinates, selected side, activity geometry, PID, AX element, title, identifier, geometry snapshot, screen index, executable path, account field, and Usage value are never persisted.

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

Committed fixtures are recursively redacted. A fixture is evidence of payload structure, not a replay of a user's account or thread. M6 discovery and smoke output also omit coordinates, PIDs, titles, identifiers, paths, raw AX trees/failures, and Usage values. User-supplied screenshots used during discovery are not committed or consumed by production.
