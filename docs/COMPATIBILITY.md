# Compatibility

## M0 validation host

| Component | Observed version |
| --- | --- |
| macOS | 26.5.2 (Build 25F84), arm64 |
| Xcode | 26.4.1 (17E202) |
| Swift | 6.3.1 |
| Codex CLI | 0.145.0-alpha.18 |
| Codex Desktop bundle | `com.openai.codex`, 26.715.31925 (5551) |
| Git | 2.53.0 |
| GitHub CLI | 2.87.3 |

This table records one M0 host, not a compatibility guarantee. The app-server protocol is experimental. Generated schema bundles are versioned by CLI version, and unknown fields must remain forward-compatible while missing required semantics produce an unavailable state.

## Protocol matrix for Codex CLI 0.145.0-alpha.18

| Capability | Generated shape | Runtime result |
| --- | --- | --- |
| `account/read` | `GetAccountParams` → `GetAccountResponse` | PASS on independent stdio; identity fields redacted |
| `account/rateLimits/read` | legacy `rateLimits` plus nullable `rateLimitsByLimitId` | PASS on independent stdio; two buckets returned |
| `account/rateLimits/updated` | sparse `{ rateLimits: RateLimitSnapshot }` | Present in schema; not observed during M0 window |
| `account/usage/read` | summary plus nullable daily buckets | PASS on independent stdio; metrics redacted in fixture |
| `thread/loaded/list` | thread-id array plus cursor | PASS on independent stdio; zero loaded threads as expected for a new process |
| `thread/status/changed` | thread id plus tagged status | Present in schema; shared runtime not reachable |
| `thread/tokenUsage/updated` | thread id, turn id, total/last token usage, nullable context window | Present in schema; real-time runtime behavior not verified |

`RateLimitWindow` is exactly `{ usedPercent, windowDurationMins, resetsAt }` in this generated version. Pet Halo identifies five-hour and weekly windows only as 300 and 10080 minutes respectively; `primary` and `secondary` are treated as storage slots, not semantic names.

## Transport matrix

| Transport | Discovery | Result | Suitable use |
| --- | --- | --- | --- |
| Independent stdio | `codex app-server --stdio` | PASS | Account and rate-limit fallback only |
| Managed shared control socket | `codex app-server proxy` default discovery | BLOCKED: socket absent | Candidate production transport only after a supported shared server is available |
| Explicit socket path | operator-provided `proxy --sock` | Not tested; no evidenced Desktop socket path | Never infer or hardcode |
| Codex internal SQLite | none | Prohibited | Never use |

The official `codex doctor --json` `app_server.status` check reported `background server is not running` in ephemeral mode. Read-only socket inspection showed the running Desktop app and its Codex child communicating through unnamed Unix socketpairs, not an attachable path advertised by the CLI. Other IPC sockets were not assumed to be app-server transports.

The aggregate v2 JSON schema is not byte-deterministic in this CLI build because its `definitions` object order changes between runs. A second generation produced the same canonical sorted-JSON SHA-256 and identical individual JSON/TypeScript files. Consumers must treat JSON object ordering as insignificant.
