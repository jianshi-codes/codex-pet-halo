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

## M1 application foundation

| Component | M1 contract |
| --- | --- |
| Minimum deployment target | macOS 14.0 |
| Swift language mode | Swift 6 |
| UI and lifecycle | SwiftUI `MenuBarExtra` with AppKit application delegate/coordinator |
| Project generation | XcodeGen 2.46.0 from `project.yml` |
| Generated project | Committed and checked for regeneration drift in CI |
| Runtime dependencies | Apple frameworks only; no third-party packages |
| Signing | Disabled for command-line and CI validation; distribution decisions deferred |
| Sandbox | Not enabled in M1; future child-process/window-observation implications require a separate decision |

Local M1 builds were validated with Xcode 26.4.1 (17E202) and Swift 6.3.1. The project deployment target, not that validation host version, defines the intended minimum OS.

## M2 runtime gate

Production runtime compatibility is intentionally fail-closed. `CodexCompatibilityRegistry` currently accepts exactly `0.145.0-alpha.18`; any other or unparseable version produces an unavailable state before a child process is launched. Adding a version requires regenerated local schemas, DTO comparison, fixture/test review, and an explicit registry entry.

The executable locator accepts an injected URL for tests, absolute executable entries from inherited `PATH`, standard Homebrew prefixes, and the resource directories of installed Codex or ChatGPT applications. Relative entries such as `.` and `relative/bin` are ignored. Candidates are resolved and checked as executable files. Version detection and app-server launch use `Foundation.Process` directly with argument arrays and working directory `/`; no shell command is constructed. The version probe defaults to 5 seconds and 4 KiB stdout, discards stderr, and confirms child exit after termination or SIGKILL before returning.

The production method allowlist is limited to `initialize`, `initialized`, `account/read` with `refreshToken: false`, `account/rateLimits/read`, and `account/usage/read`. The bridge observes only `account/rateLimits/updated` and `account/updated`; payloads are invalidation hints only. Rate-limit updates request a complete rate snapshot. Account updates clear cached account data and request account, rate-limit, and Usage snapshots. New app-server connections also clear old account data because identity continuity cannot be established.

The public M2 domain exposes rate-limit and Account Usage freshness separately. Aggregate freshness is current only when every available component in the snapshot is current. Retained Usage stays explicitly stale, with its safe failure reason, across successful rate-only reads and becomes current only after a successful Usage read. `UsageSnapshot.collectedAt` and `lastSuccessfulRefresh` identify the newest successful component mutation; they are not per-component collection timestamps and must not be used alone to infer Account Usage recency.

## M3 presentation contract

| Component | M3 contract |
| --- | --- |
| Window | One AppKit borderless `.nonactivatingPanel`; cannot become key or main |
| Level and Spaces | Floating, all-Spaces, full-screen auxiliary, ignored by normal cycling |
| Interaction | Compact and expanded are click-through and controlled by the menu bar |
| Sizes | Compact 176×176 points; expanded 360×520 points |
| Initial position | Upper-right of one available screen's visible frame, fixed 24-point inset |
| Presentation | SwiftUI hosted inside the panel; system materials, colors, and text styles |
| Accessibility | Deterministic textual states and reset values; Reduce Transparency and Differentiate Without Color |
| State ownership | `ApplicationCoordinator` is the single bridge stream consumer and panel owner |

The M3 mapper consumes only the stable M2 domain. Weekly/five-hour presentation follows rate-limit component freshness, while Account Usage follows its independent component freshness. Remaining percentage is not inverted again. Five-hour appears only for an available exact 300-minute capability. Context and account identity are omitted.

The panel does not discover or inspect Codex, enumerate product windows, request Accessibility or Screen Recording permission, or use saved placement. M4 owns any future calibration/window-following compatibility work; M5 owns final artwork and visual themes.

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

## MVP capability levels

| Level | Capability | Current status | Display behavior |
| --- | --- | --- | --- |
| Core | Weekly Codex rate-limit window | PASS | Primary halo with remaining percentage and reset time |
| Core | Halo-owned app-server connection | PASS | Connected/disconnected/timeout state indicator |
| Core | Account usage summary and daily buckets | PASS | Expanded view; identity fields are never displayed |
| Optional | Five-hour rate-limit window | Absent in the real response | Omit the segment; detect a future 300-minute window automatically |
| Optional | Shared thread Context | Not verified | Omit or mark unavailable; never estimate |
| Optional | Target-thread selection | Not verified | Required only when Context becomes available |
| Optional | Rate-limit push update | Schema only | MVP may refetch the read snapshot; sparse pushes cannot replace it |

For multiple rate-limit buckets, preserve every bucket. The exact `codex` bucket may be used as the general Codex primary halo when present; model-specific or other buckets belong in secondary/expanded presentation. Never choose a bucket by map order.

## Transport matrix

| Transport | Discovery | Result | Suitable use |
| --- | --- | --- | --- |
| Independent stdio | `codex app-server --stdio` | PASS | **Recommended MVP transport** for account, limits, usage, and owned connection state |
| Managed shared control socket | `codex app-server proxy` default discovery | Unavailable: socket absent | Optional future source for shared Desktop thread data |
| Explicit socket path | operator-provided `proxy --sock` | Not tested; no evidenced Desktop socket path | Never infer or hardcode |
| Codex internal SQLite | none | Prohibited | Never use |

The official `codex doctor --json` `app_server.status` check reported `background server is not running` in ephemeral mode. Read-only socket inspection showed the running Desktop app and its Codex child communicating through unnamed Unix socketpairs, not an attachable path advertised by the CLI. Other IPC sockets were not assumed to be app-server transports. This limits optional shared Context only; it does not block the owned stdio MVP.

The aggregate v2 JSON schema is not byte-deterministic in this CLI build because its `definitions` object order changes between runs. A second generation produced the same canonical sorted-JSON SHA-256 and identical individual JSON/TypeScript files. Consumers must treat JSON object ordering as insignificant.

Generated M0 schemas and TypeScript remain retained evidence only. `PetHaloCore` owns minimal forward-compatible DTOs, ignores unknown response fields, and is not linked to or packaged with the probe, schemas, fixtures, or test fake server.
