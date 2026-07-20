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
| Interaction | Compact is click-through; expanded accepts pointer/scroll events while remaining non-activating and unable to become key or main; both are controlled by the menu bar |
| Sizes | Compact 176×176 points; expanded 360×520 points |
| Initial position | Upper-right of one available screen's visible frame, fixed 24-point inset |
| Presentation | SwiftUI hosted inside the panel; system materials, colors, and text styles |
| Accessibility | Deterministic textual states and reset values; Reduce Transparency and Differentiate Without Color |
| State ownership | `ApplicationCoordinator` is the single bridge stream consumer and panel owner |

The M3 mapper consumes only the stable M2 domain. Weekly/five-hour presentation follows rate-limit component freshness, while Account Usage follows its independent component freshness. Remaining percentage is not inverted again. Five-hour appears only for an available exact 300-minute capability. Context and account identity are omitted.

The M3 panel itself does not discover or inspect Codex. M4 and M5 own the separately gated target-following compatibility layers. M6 owns final artwork and visual themes.

## M4 window-following contract

| Component | M4 contract |
| --- | --- |
| Application discovery | `NSRunningApplication.runningApplications(withBundleIdentifier:)` for exact `com.openai.codex` only; one exact candidate wins, or one active candidate among multiples |
| Permission | Accessibility trust checked without prompting at startup; the prompt option is used only after `Enable Window Following` |
| Window selection | focused eligible standard window, then main eligible standard window, then exactly one eligible visible non-minimized standard window; otherwise fallback |
| AX data | window list, focused/main references, role, subrole, minimized, position, and size only |
| AX events | moved, resized, focused/main change, created, destroyed; workspace launch/termination/activation is exact-bundle filtered |
| Coordinates | AX global top-left/Y-down converted once to AppKit global Y-up using the primary display frame; point values are not scaled as pixels |
| Placement | version-1 normalized point inside the Codex window plus a fixed point offset to the Halo upper-right reference |
| Displays | anchor-point screen selection, complete visible-frame containment, nearest remaining display fallback, no persisted screen index |
| Interaction | calibration temporarily accepts drag events; the panel remains `.nonactivatingPanel` and cannot become key or main |

Synthetic tests cover a main display at `(0,0)`, a negative-X left display, a negative-Y lower display, mixed sizes, boundary-crossing windows, screen removal, and an oversized Halo. The implementation currently targets macOS 14 or later. Direct validation passed explicit Accessibility permission, calibration, physical move/resize, focus and interaction behavior, multi-display containment, permission fallback/recovery, Codex termination/relaunch recovery, Pet Halo restart, and clean shutdown as recorded in the M4 report.

## M5 Pet-target contract

| Component | M5 contract |
| --- | --- |
| Route | `ROUTE_A — PET_ACCESSIBILITY_WINDOW` on the validated Codex Desktop build |
| Process boundary | Reuse exact `com.openai.codex` selection; no generic process or window-server scan |
| Pet selection | visible, non-minimized, finite positive near-square `AXWindow/AXDialog`; half-point overlap collapse; exactly one logical frame or fail closed |
| AX data | application window list, role, subrole, minimized, hidden, position, and size only |
| AX events | Pet moved, resized, destroyed, and application window created |
| Burst handling | 80 ms callback coalescing; 160 ms stability recheck for non-atomic overlapping layers |
| Placement | separate version-1 normalized Pet point plus fixed point offset to the Halo logical reference |
| Hierarchy | Pet target, then calibrated M4 Codex window, then M3 free-floating |
| Recovery | preserve Pet anchor; retry Pet discovery every five seconds while fallback is active; stale generations ignored |
| Interaction | existing non-activating panel, compact click-through, expanded scrolling, and display containment remain unchanged |

Direct discovery observed the Pet core move independently while the standard Codex window stayed stationary, disappear on Tuck Away, and return on Wake. Activity UI could move above or below Pet and expose separate controls, so neither relative position nor button count is used. Two overlapping core surfaces can update non-atomically; persistent ambiguity activates fallback rather than guessing.

The official [Codex Pets documentation](https://learn.chatgpt.com/docs/pets.md) does not define an Accessibility compatibility contract. M5 is consequently validated against the recorded Codex Desktop build and must fail closed when future builds change the observed role/subrole, geometry layering, or notification behavior.

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
