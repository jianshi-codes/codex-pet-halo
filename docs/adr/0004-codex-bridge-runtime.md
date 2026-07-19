# ADR 0004: Own a fail-closed read-only CodexBridge runtime

- Status: Accepted
- Date: 2026-07-20

## Context

M0 established that an independently launched Codex app-server can provide the account-scoped data needed by the future product. M2 must turn that evidence into a production Swift boundary without binding the application to experimental JSON field names, allowing mutation methods, exposing identity, or making optional Context support a prerequisite.

The app-server protocol is experimental and versioned with the Codex CLI. The child process is long-lived, its stdout is newline-delimited JSON-RPC, its notifications can be sparse, and failures must not strand pending requests or orphan a process. A permissive generic transport API or schema-blind decoder would make later protocol drift unsafe.

## Decision

- Add one UI-independent Swift 6 framework, `PetHaloCore`, and keep the application dependent only on its high-level `CodexUsageServing` boundary.
- Discover Codex from an injected URL, absolute inherited `PATH` entries, justified Homebrew prefixes, or installed Codex/ChatGPT application resources. Ignore relative `PATH` entries, resolve and validate candidates without a shell, never log the selected path, and run both version inspection and app-server launch with direct `Foundation.Process` argument arrays. Bound version inspection to 5 seconds and 4 KiB stdout; discard stderr and await termination/SIGKILL cleanup on timeout or cancellation.
- Accept only explicitly reviewed versions in `CodexCompatibilityRegistry`. M2 supports exactly `0.145.0-alpha.18`; unsupported or unparseable versions fail before process launch.
- Own one `codex app-server --stdio` child. Use stdout only for protocol JSONL, drain and discard stderr, close pipes deterministically, propagate exit to pending requests, and use bounded graceful termination followed by a final forced termination only when required. JSON-RPC shutdown is an exactly-once awaitable barrier, and replacement launch cannot precede prior transport cleanup.
- Frame JSONL incrementally with a 4 MiB maximum message and bounded delivery queue. Reject invalid UTF-8, invalid JSON, and delivery overflow rather than accumulating or silently dropping protocol messages.
- Keep JSON-RPC request IDs monotonic, writes serialized, pending requests concurrent, and responses order-independent. Timeouts, cancellation, disconnect, duplicate responses, and unknown response IDs have explicit behavior.
- Expose only closed request/notification enums. The production allowlist is `initialize`, `initialized`, `account/read`, `account/rateLimits/read`, and `account/usage/read`; account reads always set `refreshToken: false`. Observe only `account/rateLimits/updated` and `account/updated` as invalidation hints.
- Convert minimal forward-compatible DTOs into stable `Equatable` and `Sendable` Usage models. Preserve every bucket and source slot, select the general bucket only by exact `codex` ID, and recognize weekly/five-hour windows only by exact duration. Discard account identity fields during decoding.
- Give every start/reconnect attempt an immutable epoch. Revalidate it after each suspension; stop invalidates, cancels, and awaits the attempt so obsolete work cannot publish, launch, reconnect, or overwrite stopped state.
- Perform initial sequential reads, refresh rate limits every 60 seconds and Account Usage every 15 minutes on monotonic absolute schedules, and expose a manual refresh seam. Coalesce non-overlapping refreshes with ordered rate-only/full-account scopes and run one strongest queued follow-up.
- Persist rate-limit and Account Usage freshness independently in the stable domain and derive aggregate freshness from only the components available in the snapshot. Any included stale component keeps the aggregate stale; an optional unavailable component does not degrade otherwise-current data.
- Preserve retained same-account Usage and its safe failure reason as stale across unrelated rate-only refreshes. Clear that failure only after Usage succeeds or account-scoped state is cleared. `UsageSnapshot.collectedAt` and `lastSuccessfulRefresh` describe the newest successful component mutation, not the collection time of every component; component freshness is authoritative for individual recency.
- Debounce sparse notifications for 250 milliseconds and refetch complete snapshots. A rate-limit update marks only retained rate data stale; an account update immediately clears all account-scoped data and requires a full account refresh. Because account identity is discarded, a new app-server connection clears old account data instead of assuming continuity.
- Reconnect unexpected failures through one bounded task using 1, 2, 4, 8, 16, 30, and 60 second steps plus limited injected jitter. Reset after a stable connection, and cancel all scheduling before intentional shutdown.
- Log only fixed lifecycle text, safe enum reasons, and retry attempt numbers. Never log raw JSON, stdout/stderr, remote messages, paths, environment values, account identity, Usage values, credentials, or content. Persist nothing.
- Keep generated schemas, M0 probes, fixtures, and the fake app-server outside production dependencies and the application bundle.

## Deferred decisions

Shared Codex Desktop attachment, thread selection, Context data, prompts, tasks, account mutation, and internal database access remain outside M2. The owned account-data process deliberately publishes Context as unsupported.

The Halo window, percentage and Usage presentation, `NSPanel`, process/window observation, permissions, positioning, and window following remain M3 or later work. M2 adds only a technical Bridge connection-state line to the existing menu.

## Consequences

The application receives stable capability and component-freshness state and owns an awaitable lifecycle without knowing JSON-RPC or process details. Protocol drift fails closed and adding a CLI version requires an explicit schema/DTO review. Optional data can degrade independently while the bridge remains connected, and stale retained Usage cannot be mistaken for data refreshed by a newer rate-only read.

This design adds process supervision, timing, and compatibility maintenance, but deterministic clocks, random sources, fake processes, and focused source/bundle checks make those responsibilities testable without Codex installation or authentication in CI.
