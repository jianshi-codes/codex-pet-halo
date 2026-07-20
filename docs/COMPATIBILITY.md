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

The M3 panel itself does not discover or inspect Codex. M4 through M6 own the separately gated target-following and placement compatibility layers. M7 owns the functional Pet ring and basic Usage presentation, M8 owns release UI/accessibility polish, and M9 owns public-beta release readiness.

## M7 target-aware presentation contract

| Component | M7 contract |
| --- | --- |
| Surface state | Pet selects `petRing`; Codex-window/free-floating select `compactCard` or `expandedCard` |
| Ring geometry | Fixed `448×252` transparent panel centered on the Pet; unchanged independent 104/94/84-point radii, 6-point vector strokes, and 162-point transparent center; added horizontal canvas holds external labels |
| Visual center | AX midpoint plus one persisted fixed `dx/dy`; every arc and absolute-position label shares the panel midpoint |
| Pet interaction | Normally click-through and temporarily draggable only during explicit `Adjust Ring Center`; always shadowless, non-activating, and unable to become key or main |
| Card fallback | Compact/Expanded, Account Usage, scrolling, and non-activation remain unchanged outside Pet |
| Weekly | Domain `remainingPercent` with rate-limit component freshness |
| Five-hour | Present only for an available exact 300-minute capability |
| Today tokens | Current-day tokens divided by nonzero historical peak; omit missing inputs, clamp arc progress at 100%, preserve actual token text |
| Semantic policy | Remaining: healthy ≥50%, warning 20–49%, critical <20%; Today: healthy ≤50%, warning 51–80%, critical >80% |
| Orientation | Fixed 260-degree partial arcs; activity above the calibrated visual Pet center opens top, activity below opens bottom, no activity uses the default, ambiguous retains prior after debounce |
| Accessibility | Every ring owns its label/value; stale also uses opacity/dash/text and an explicit stale accessibility state |

`ApplicationCoordinator` remains the single owner of target, Usage, and presentation state. It records both the fallback card choice and non-Pet reference before entering Pet. On Pet loss, a delivered M4 reference is retained; otherwise the pre-Pet free-floating reference is restored before the card is resized. A direct Compact/Expanded command cannot change the Pet Ring, and `360×520` can never be applied at the Pet midpoint.

Activity orientation is derived only after the near-square Pet core has been selected and cannot change discovery, tracking, placement, offset, or fallback. A unique wide `AXSystemDialog` is the preferred current activity hint, with a unique wide `AXDialog` retained as a compatibility fallback; the vertical comparison includes the saved visual-center offset so Auto matches the rendered Pet rather than the padded raw AX midpoint. Pet movement uses one latest-value display-linked direct follower without queued `NSWindow` animations. During an active movement burst it re-reads only the coincident selected core frames and stops after four unchanged refreshes; this fast path cannot enumerate candidates or change selection.

## M8 release UI compatibility contract

| Component | M8 contract |
| --- | --- |
| System appearance | SwiftUI/system colors update live for light/dark, Increase Contrast, Differentiate Without Color, and Reduce Transparency; there is no theme system |
| Identity colors | Dot palette remains Weekly `#5865F2`, 5h `#00B8D9`, Today `#A855F7`; appearance-aware related key text has a tested practical contrast floor; numeric values use system label text |
| Freshness/status | Stale remains dashed and visibly glyph-marked; unavailable uses `N/A`, a missing arc, and a glyph; semantic status colors remain system green/orange/red and Differentiate Without Color adds a shape glyph |
| Edge placement | The already-centered panel and selected display `visibleFrame` choose only capsule side; negative coordinates work and screen identity is not stored |
| Dialog geometry | Continues to choose only the shared arc opening; it does not override an edge-safe capsule side |
| Reduce Motion | New positions apply directly without interpolation; an active display-link callback is invalidated; normal mode retains latest-value following |
| Icons | Complete original AppIcon catalog plus separate monochrome template menu asset; no official artwork or generic `circle.dashed` symbol |

M8 does not alter Route A discovery, Pet core selection, panel midpoint, visual-center persistence, Usage semantics, bridge behavior, fallback hierarchy, or M7 ring radii. When either capsule side fits, every visible capsule is contained in `visibleFrame`; if neither fits, the smaller-overflow side is selected without clamping the Ring center. M9 remains the separately gated compatibility-hardening and public-beta milestone.

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

## M6 center-locked attachment contract

| Component | M6 contract |
| --- | --- |
| First use | a unique Pet attaches immediately; no saved Pet anchor and no calibration-required detour |
| Positioning | one unconditional centered mode; no Pet positional anchor can override it |
| Snapshot | `PetTargetSnapshot` contains only Pet frame and generation |
| Attachment | panel midpoint equals the raw Pet AX frame midpoint for every accepted Pet target |
| Inputs | no screen lookup, activity geometry, side, distance, fit, clamp, orientation, or hysteresis |
| Displays | center alignment uses global AppKit coordinates and supports negative-coordinate and multi-display layouts without `NSScreen.main` placement |
| Migration | startup removes the exact legacy Pet anchor key and does not alter the M4 Codex-window anchor |
| Fine-tune API | retained as an inert compatibility hook; it cannot create calibration state, persist a Pet anchor, or shift the panel |
| Presentation | Pet targeting forces Compact and rejects Expanded until M7; fallback restores normal controls and the prior card mode |
| Fallback | Pet loss or ambiguity uses the preserved M4 anchor, then M3 free-floating; Wake restores centered Pet placement |

M6 does not change the undocumented nature of Route A. Local screenshots and sanitized geometry showed that inferring a visible head/feet edge from the near-square AX Pet surface was not stable enough. The compatibility contract therefore uses only the frame midpoint and validates the Halo panel midpoint directly. The accessor observes selected Pet core surfaces and application window creation needed for Pet recreation, not activity-window geometry. The policy is deterministic and fake-driven in CI, while direct compatibility remains a local interaction gate against the installed Codex Desktop build.

M7 preserves that raw AX midpoint as the tracking basis while adding a separate fixed visual-center offset to the complete Pet Ring panel. It does not reactivate the M5 normalized anchor. M7 also observes only wide activity-window geometry as a post-selection arc-orientation hint and compares it with the calibrated visual center; it is not an M6 placement input.

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
