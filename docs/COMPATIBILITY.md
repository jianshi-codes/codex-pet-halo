# Compatibility

## Published Beta 9: fixed Pet positioning (2026-10-11)

Startup makes one visual positioning request. `Locate Pet` repeats it on demand.
After completion the ring stays fixed, including after Pet movement, Quick Chat,
hide/wake, or display changes. Failed requests preserve the previous position.
Continuous following, mouse monitoring, adaptive sampling, window fallback controls,
legacy center adjustment and orientation preview have been removed from the menu.
Beta 9 ships this behavior; prior releases retain their historical AX behavior.


Validation: 149 PetHaloTests passed; Debug and Release builds passed. A 30-second
local idle sample after single-shot startup positioning averaged 0.10% of one CPU
core and approximately 19.7 MiB physical footprint. Process-attributed energy was
approximately 0.0002 W on average (OS estimate, not whole-machine power). The prior
adaptive continuous capture trial averaged approximately 18% CPU and 0.67 W. These
are short local observations, not battery-life predictions or a universal benchmark.

## CLI compatibility policy and reviewed registry

Pet Halo separates exact reviewed evidence from bounded provisional forward compatibility. `CodexCompatibilityRegistry` contains only versions whose production-used semantics were explicitly reviewed; successful provisional runtime validation never adds reviewed evidence.

| Decision | Version boundary | Startup behavior |
| --- | --- | --- |
| Reviewed | Exact registry entry; currently `0.145.0-alpha.18` | Launch the owned app-server using the reviewed protocol semantics |
| Provisional | `>= 0.145.0-alpha.18` and `< 1.0.0`, excluding a local known-incompatible denylist | Launch, then accept the version for this session only after required runtime capabilities succeed |
| Blocked | Malformed, below the floor, explicitly denied, or major version 1 and newer | Fail closed before app-server launch |

The known-incompatible denylist is initially empty. It is a safety override for confirmed broken versions, not a second reviewed-version registry. Newer pre-1.0 versions may therefore work without a Pet Halo update, but only the exact reviewed baseline has schema and semantic review evidence.

| Component | Version | Status | Evidence boundary |
| --- | --- | --- | --- |
| Codex CLI | `0.145.0-alpha.18` | Supported | Exact reviewed baseline; all production-used schemas and semantics reviewed |
| Codex CLI | `0.146.0-alpha.3.1` | Provisional session PASS | Current installed CLI passed required read-only runtime capabilities and clean shutdown on 2026-07-25; no schema-review claim |
| Codex CLI | `0.146.0-alpha.9.2` | Provisional session PASS | Beta 4 generated current temporary schemas and passed required read-only runtime capabilities plus clean shutdown on 2026-07-31; no reviewed-registry claim |
| Codex Desktop | `26.715.31925 (5551)` | Supported | Route A Pet/window Accessibility behavior previously validated |
| Codex Desktop | `26.715.52143 (5591)` | Supported | Current M9 Route A and complete Pet-following gate validated |
| Codex Desktop | `26.721.41059 (5848)` | Supported in Beta 3 | Published structural policy plus direct Hide/Wake/center interaction, deterministic tests, final-main smoke, and CI evidence |
| Codex Desktop | `26.727.40816 (6067)` | Supported in Beta 4 | Published geometry policy and mirrored deterministic tests cover the Pet-spanning container, narrow voice/resize controls, and stacked activity cards; the user confirmed final direct two-sided opening behavior on 2026-07-31 |

The CLI registry covers these semantic groups: initialize/initialized; `account/read`; `account/rateLimits/read`; `account/rateLimits/updated`; `account/usage/read`; and JSON-RPC request, response, error, and notification envelopes. It also covers exact rate-limit window durations, sparse update behavior, Account Usage summary/daily buckets, independent component freshness, and account-data clearing boundaries.

M9 regenerated 341 JSON schema files from its then-current local CLI into a temporary directory. All 340 individual schema files were byte-identical to the retained `0.145.0-alpha.18` evidence. The aggregate v2 schema differed only in object ordering; both canonical sorted documents had SHA-256 `d7da14579e98011d40ad9c97a376cccfd69d0da5b2eb174b32d5bb6bd9159b6b`. This confirms schema stability for the already-supported CLI version but does not replace semantic review.

Beta 4 generated 349 JSON schema files from installed CLI
`0.146.0-alpha.9.2` into a temporary directory. `InitializeResponse` and
`GetAccountTokenUsageResponse` canonically match the retained reviewed evidence.
The rate-limit response adds only the unused `ent26` plan enum value.
`GetAccountResponse` also changes unused Amazon Bedrock credential metadata.
Pet Halo decodes neither plan nor credential details: its production fields for
account availability, rate-limit windows, and Account Usage retain their
reviewed shapes. Eight additional generated method types are outside the
production request/notification set. This is bounded compatibility evidence,
not an addition to the exact reviewed registry.

Desktop `26.727.40816 (6067)` adds a wider Accessibility container spanning
the Pet plus narrow voice/resize controls below it. Beta 4 excludes those
surfaces from activity-direction resolution, groups multiple activity cards on
the same side, and preserves the prior opening when cards genuinely occupy both
sides. Direct user acceptance covered the Pet at both the top and bottom of the
screen without changing the saved visual-center offset. This geometry-only
policy is included in published Beta 4.

Beta 5 preserves that exact Desktop evidence boundary while adding a bounded
compatibility fallback for a changed topology: when near-square candidates are
absent, exactly one visible non-standard `AXWindow/AXDialog` with valid finite
geometry may be accepted, while multiple candidates remain ambiguous. The
latest direct user acceptance also covered the default visual-center baseline
and no-activity upper/lower Ring direction. No additional exact Desktop version
is added to the reviewed table without independent version evidence.

Beta 6 preserves the same CLI and Desktop compatibility boundary. Its
Accessibility changes are local state handling: an existing grant is checked
before requesting, delayed grants settle through a bounded checking state, and
transient input-method indicators are rejected as Pet targets while a stable
Pet continuity anchor is available. No new CLI or Desktop version is added to
the reviewed table by this release.

Beta 7 preserves the same runtime compatibility boundary and changes release
packaging only. The unsigned archive now carries a complete ad-hoc application
and framework signature so macOS receives a valid local code requirement when
the user grants Accessibility access. The signature is build-specific and is
neither Developer ID nor Apple notarization evidence. The published Beta 7 ZIP
passed LaunchServices launch and owned app-server cleanup on a host with CLI
`0.154.0-alpha.6.2`; that proves only the launch/child lifecycle, not a new
reviewed CLI schema, all runtime Usage capabilities, or direct Pet interaction.
Clean-machine Accessibility and Gatekeeper acceptance remain unverified.

Beta 8 changes executable discovery only. Its freshly downloaded public ZIP
passed local LaunchServices launch and owned-child cleanup without a manual CLI
link. A sanitized probe using its embedded framework and the default locator
with a GUI-style `PATH` confirmed provisional CLI `0.158.0-alpha.2.1`, a connected
bridge, and current usable Weekly data after the asynchronous initial refresh.
The optional 5h capability was unavailable and remained unestimated. This is
session evidence, not a reviewed CLI schema or new Desktop/Pet acceptance. The
user accepted this local boundary for Beta 8 publication and Latest promotion;
independent clean-machine acceptance remains not run.

For Desktop `26.715.52143 (5591)`, the consolidated M9 Pet-following gate directly observed one unique Route A Pet core moving while the resolved Codex standard window remained stationary, automatic visual-center attachment, Tuck Away fallback, Wake recovery, Pet Ring selection, non-activation, and complete Pet Halo/owned-child shutdown. M5–M7 use this one live flow rather than repeating the same interaction across milestone scripts.

Desktop `26.721.41059 (5848)` changed the visible-Pet Route A topology to three
`AXDialog` and three `AXSystemDialog` surfaces across five logical frames. One
near-square frame is corroborated by two coincident surfaces, while two separate
near-square `AXSystemDialog` surfaces are singletons. The larger SystemDialog is
the live Pet core; the smaller one is a control, while the coincident Dialog frame
can retain stale geometry across Tuck Away and Wake. Pet selection now chooses
the unique largest near-square SystemDialog and fails closed when the largest
area is tied. If no eligible SystemDialog exists, exactly one corroborated Dialog
frame wins, followed by the existing unique-Dialog compatibility fallback.
The production selector, Route A probe, and center-lock smoke compile the same
pure selection policy. A sanitized read-only structural probe resolves the
current topology uniquely. Direct active-branch interaction then confirmed
calibrated placement, immediate center restoration across Hide/Wake, stable
centering after a new task message, and fail-closed removal of the unverified
Live Activity ring. The final source and user-confirmed observation are included
in published Beta 3.

The M9 validation host is macOS 26.5.2 (Build 25F84), arm64, with Xcode 26.4.1 (17E202), Swift 6.3.1, Codex CLI 0.145.0-alpha.18, and Codex Desktop 26.715.52143 (5591). Host observations are evidence, not a broad compatibility promise.

On 2026-07-21, installed CLI `0.145.0-alpha.27` passed the provisional runtime path: executable discovery; version parsing and provisional decision; initialize/initialized; valid JSON-RPC envelopes; account and rate-limit reads; a usable exact Weekly window with valid percentage and decoded reset timestamp; optional 5h omission; available Account Usage; and clean owned-child shutdown. This is session runtime evidence only. It does not add `0.145.0-alpha.27` to the reviewed registry or claim a schema review.

On 2026-07-25, the same sanitized read-only smoke passed for installed CLI
`0.146.0-alpha.3.1`: provisional version decision, initialize/initialized,
JSON-RPC envelopes, account and rate-limit reads, a usable Weekly percentage and
decoded reset timestamp, optional 5h omission, available Account Usage, and clean
owned-child shutdown. This is also session-only evidence and does not add the
version to the reviewed registry.

On 2026-07-31, the sanitized read-only smoke passed for installed CLI
`0.146.0-alpha.9.2`: provisional version decision, initialize/initialized,
valid JSON-RPC envelopes, account and rate-limit reads, available exact Weekly
percentage and decoded reset timestamp, optional 5h omission, available Account
Usage, and clean owned-child shutdown. This remains session-only evidence.

## Sanitized compatibility reports

Use the GitHub compatibility-report issue form and provide only:

- macOS version and architecture;
- Pet Halo version;
- Codex CLI version;
- Codex Desktop version;
- whether Pet is visible or tucked away;
- one safe application state from the issue form;
- concise reproduction steps with no private data.

Do not attach raw protocol payloads, tokens, authorization data, account identity, conversation content, private screenshots, raw Accessibility errors or trees, executable paths, PIDs, or user-specific absolute paths. If a maintainer needs structural evidence, use generated schemas from the installed CLI and recursively sanitized synthetic fixtures.

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

The version parser compares numeric major/minor/patch components and dot-separated prerelease identifiers without a third-party dependency. The minimum is `0.145.0-alpha.18`; malformed, older, denied, and 1.x versions produce an unavailable state before a child process is launched.

For a provisional version, Pet Halo requires a valid initialize response, initialized notification send, valid JSON-RPC envelopes, decodable `account/read` behavior, decodable `account/rateLimits/read`, and one unambiguous exact 10,080-minute Weekly window using the existing `usedPercent` and nullable timestamp semantics. Unknown response fields remain tolerated. The exact 300-minute five-hour window and `account/usage/read` remain optional; missing 5h is omitted, and unsupported or failed Account Usage cannot remove valid Weekly data. Account Usage is confined to fallback cards and no longer supplies a Pet Ring Today metric. Authentication unavailable is a sign-in state, not protocol incompatibility.

Required method-not-found errors, invalid required envelopes or response shapes, and rate-limit semantics without a usable Weekly capability make a provisional version runtime incompatible for the current connection. Pet Halo closes the owned child, cancels periodic/debounce/reconnect work, and does not automatically reconnect for that failure. A user-initiated **Refresh Usage** or application restart may retry. Transport closure, timeout, and process-start failures retain their existing transient reconnect treatment. Only safe state names and the parsed CLI version may be surfaced; raw errors, payloads, account data, environment values, and executable paths remain private.

The executable locator accepts an injected URL for tests, absolute executable entries from inherited `PATH`, standard Homebrew prefixes, and the resource directories of installed Codex or ChatGPT applications. Beta 8 additionally checks their nested `codex-cli/CodexCLI.app/Contents/MacOS` directories after every existing common prefix, so application launch does not require a shell-provided CLI path or a manually installed compatibility symlink. Relative entries such as `.` and `relative/bin` are ignored. Candidates are resolved and checked as executable files. Version detection and app-server launch use `Foundation.Process` directly with argument arrays and working directory `/`; no shell command is constructed. The version probe defaults to 5 seconds and 4 KiB stdout, discards stderr, and confirms child exit after termination or SIGKILL before returning.

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
| Visual center | AX midpoint plus one persisted fixed `dx/dy`; every arc and absolute-position label shares the panel midpoint; the current default baseline is `(-25.5, -1.5)` points |
| Pet interaction | Normally click-through and temporarily draggable only during explicit `Adjust Ring Center`; always shadowless, non-activating, and unable to become key or main |
| Card fallback | Compact/Expanded, Account Usage, scrolling, and non-activation remain unchanged outside Pet |
| Weekly | Domain `remainingPercent` with rate-limit component freshness |
| Five-hour | Present only for an available exact 300-minute capability |
| Reserved context slot | The inner 84-point slot remains hidden. Current wide AX surfaces persist across idle and working states, so geometry cannot truthfully supply Live Activity |
| Semantic policy | Weekly and five-hour remaining: healthy ≥50%, warning 20–49%, critical <20% |
| Orientation | Fixed 260-degree partial arcs; without activity, the selected display's visible-frame midpoint chooses the visible arc above or below the visual Pet; activity direction overrides that screen-half rule (activity above keeps the Ring below, activity below keeps it above); ambiguous geometry retains the prior orientation after debounce |
| Accessibility | Every visible quota ring owns its label/value; stale quota metrics also use opacity/dash/text and an explicit stale accessibility state |

`ApplicationCoordinator` remains the single owner of target, Usage, and presentation state. It records both the fallback card choice and non-Pet reference before entering Pet. On Pet loss, a delivered M4 reference is retained; otherwise the pre-Pet free-floating reference is restored before the card is resized. A direct Compact/Expanded command cannot change the Pet Ring, and `360×520` can never be applied at the Pet midpoint.

Activity orientation is derived only after the near-square Pet core has been selected and cannot change discovery, tracking, placement, offset, or fallback. Wide activity candidates must be wider than the Pet core and cannot substantially contain it, excluding the current Pet-spanning container; narrow voice/resize controls are also excluded. `AXSystemDialog` remains the preferred current activity type, with `AXDialog` retained as a compatibility fallback. Multiple preferred activity surfaces resolve only when every surface is on the same side, using the nearest surface for the vertical delta; mixed-side activity remains ambiguous. The vertical comparison includes the saved visual-center offset so Auto matches the rendered Pet rather than the padded raw AX midpoint. When no activity surface is available, the selected display's visible frame chooses the Ring's upper/lower visible-arc placement from that same visual center; an activity surface always overrides this screen-half default. Pet movement uses one latest-value display-linked direct follower without queued `NSWindow` animations. During an active movement burst it re-reads only the coincident selected core frames and stops after four unchanged refreshes; this fast path cannot enumerate candidates or change selection.

During an explicit following enable, the permission adapter checks the current trust state before requesting access. If macOS publishes a grant asynchronously, the service enters a bounded `Checking Accessibility` state, suppresses duplicate enable commands, and resumes target resolution only after trust is observed. A transient input-method indicator is rejected by the Pet-size predicate; while a Pet is tracked, the selected AX elements remain the continuity anchor, and target replacement requires two stable observations before the fallback hierarchy can take over.

## M8 release UI compatibility contract

| Component | M8 contract |
| --- | --- |
| System appearance | SwiftUI/system colors update live for light/dark, Increase Contrast, Differentiate Without Color, and Reduce Transparency; there is no theme system |
| Identity colors | Dot palette remains Weekly `#5865F2`, 5h `#00B8D9`, and reserved context slot `#A855F7`; appearance-aware related key text has a tested practical contrast floor; numeric values use system label text |
| Freshness/status | Stale remains dashed and visibly glyph-marked; unavailable uses `N/A`, a missing arc, and a glyph; semantic status colors remain system green/orange/red and Differentiate Without Color adds a shape glyph |
| Edge placement | The already-centered panel and selected display `visibleFrame` choose capsule side and the no-activity upper/lower visible-arc default; negative coordinates work and screen identity is not stored |
| Dialog geometry | Chooses the shared arc opening and overrides the no-activity screen-half default; it does not override an edge-safe capsule side |
| Reduce Motion | New positions apply directly without interpolation; an active display-link callback is invalidated; normal mode retains latest-value following |
| Icons | Complete original AppIcon catalog plus separate monochrome template menu asset; no official artwork or generic `circle.dashed` symbol |

Published Beta 3 updates Route A Pet core selection for the current multi-surface
Desktop topology and restores saved center placement immediately after Wake. It
preserves the Pet → calibrated-window → free-floating hierarchy, panel midpoint,
visual-center persistence, bridge behavior, and M7 ring radii. It removes the
former Today presentation and leaves the reserved inner slot empty. When either
capsule side fits, every visible capsule is contained in `visibleFrame`; if
neither fits, the smaller-overflow side is selected without clamping the Ring
center. M9 remains complete with its signed-binary gate blocked.

Published Beta 4 adds only current-Desktop activity-direction
filtering after Pet selection. It excludes the Pet-spanning container and narrow
controls, treats same-side activity cards as a stack, and keeps mixed-side
ambiguity fail-closed. It does not change the selected Pet frame, panel center,
saved visual-center offset, target hierarchy, protocol behavior, or Usage
presentation.

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

### 2026-10-11 compatibility observation

Codex `26.1007.30912 (20156)` exposes one Pet `AXWindow/AXDialog`
covering a full 2560×1440-point display. A bounded read-only inspection of
its descendants found six `AXGroup` nodes, all with that same frame;
this observation provides no Pet-body position. The former non-square
Dialog fallback selected this overlay and placed the Ring at the display
midpoint. It does not establish a change to the Pet's default position.

Pet candidates now require both dimensions to be at least 64 points and
neither dimension to exceed 640 points. The upper bound conservatively
retains the previously supported compact and tall Pet surfaces while
rejecting large containers, including square overlays. The same predicate
applies to retained targets and display-linked frame reads, so a tracked
window cannot resize into a screen overlay and remain a Pet target.
Larger Pet surfaces are intentionally unsupported until independently
validated. When only this overlay is available, the existing Codex-window
fallback (or free-floating mode without a calibrated window) applies.
Precise Pet following on this topology remains unsupported; visual-center
calibration cannot recover a position absent from AX geometry.

Follow-up read-only probes on the same build checked two alternatives:

- WindowServer metadata (`CGWindowListCopyWindowInfo`) showed only two
  currently visible related windows: the standard application window and
  the full-display layer-3 overlay. The all-window list contained other
  non-visible windows, but no verified visible Pet-sized window. No window
  titles or pixels were read, and no Screen Recording prompt was requested.
- The Pet overlay's AX attribute names and element-valued relations were
  inspected, including navigation-order children, sections, title/control
  elements, and row/header relations. `AXContents`, visible children, and
  linked elements were not advertised. The complete reachable graph
  contained the overlay plus six full-display groups; no traversal bound
  was reached. Activation points were display-edge or out-of-display
  coordinates, not a usable Pet position. Text, DOM identifiers, values,
  and parameterized text attributes were not read.

Neither alternative provided a Pet-body location in the observed state.
The initial result was a snapshot. No WindowServer or expanded AX
traversal was added to production.

### Dynamic geometry follow-up

On 2026-10-11, the user manually dragged the Pet to two positions, hid and
woke it, and opened/closed Quick Chat while a temporary read-only probe
sampled visible WindowServer windows and non-standard AX window graphs.
The observation lasted approximately 125 seconds and recorded 295
samples; none reported an unfinished AX traversal. Sampling was roughly
every 0.4 seconds plus query time, so brief states may be missed and CG/AX
reads are not atomic.

- Dragging: the first 28 samples were identical despite the user's
  completed drag operation. No motion-correlated Pet-body frame appeared.
- Hide/Wake: the full-display overlay disappeared from the visible window
  list and returned with the same full-display frame. AX temporarily
  exposed no non-standard window; recovery again exposed the full-display
  window plus its six full-display groups.
- Quick Chat and surrounding interactions: local geometry did appear for
  transient layer-20 windows containing `AXList`/`AXButton` nodes, and
  layer-103 `AXHelpTag` windows. The former CG surfaces were 28 points high;
  their AX lists could extend to 144 points high. Help tags were 18 or 47
  points high. These are local UI surfaces, not a verified Pet-body frame.
  Their exact semantic identity was not read, and no stable relationship
  between their coordinates and the Pet center was established. The Pet
  overlay and its groups retained the full-display frame whenever exposed.

The tested transitions did not produce a reliable Pet-center coordinate.
Transient controls or help tags must not be used to guess the Pet position.
This does not rule out other states or future builds exposing usable
geometry. No screenshots, text values, or chat contents were read.

### Historical visual-following experiment (superseded by single-shot positioning)

The user subsequently authorized screen capture and image-based following.
A single-window ScreenCaptureKit capture of the unique exact-process
layer-3 overlay preserved transparency and excluded the desktop behind it.
The overlay's own status bubble and controls remained in the captured
pixels. Alpha-connected components separated a roughly 73×115-point Pet
body from a 330×56-point status bubble and a 120×40-point toolbar.

The initial Debug experiment used an explicit opt-in launch flag. That continuous
capture route and flag have since been removed. The following records its historical
results rather than the current default behavior.

With both Accessibility and Screen Recording permission granted to that
build, unavailable AX discovery starts a serial single-window capture
fallback. Captures are requested at half the overlay's point dimensions
and converted back to global AppKit coordinates after local alpha-only
component detection. A unique body-shaped region is required; opaque,
missing, or ambiguous images do not supply a target. The legacy AX padding
offset is not applied to visual body bounds. Visual-center calibration is
session-only for this route and does not overwrite saved AX calibration.

The user confirmed successful Pet following, dragging to two positions,
opening/closing Quick Chat, and hiding/waking the Pet. An independent probe
recorded 113 stable-body paired measurements, each within 1.2 points of the
Ring midpoint (median approximately 0.7 points). "Stable" means the current
body center was within two points of the preceding three paired samples.
Moving-frame measurements were not atomic and included transient lag;
neither capture rate nor end-to-end latency has been established. The
experiment is not equivalent to the AX display-linked tracking path.

Validation: all 146 `PetHaloTests` passed again after the final
permission-request and session-calibration refinements.
Debug and Release builds succeeded. The Release binary did not link
ScreenCaptureKit. No installed application was replaced, no release was
published, and no capture image was committed. Runtime frames remain in
memory; the one temporary feasibility inspection image was removed.

Known limits: current character and scale only; other artwork, fragmented
or wide animation poses, similarly shaped controls, multiple overlays,
large displays, and every Quick Chat layout are not validated. Capture
permissions are specific to the experimental build; launching the installed
Beta 8 application restores the old installed behavior.

| Component | M5 contract |
| --- | --- |
| Route | `ROUTE_A — PET_ACCESSIBILITY_WINDOW` on the validated Codex Desktop build |
| Process boundary | Reuse exact `com.openai.codex` selection; no generic process or window-server scan |
| Pet selection | visible, non-minimized, finite positive near-square `AXWindow/AXDialog` or `AXWindow/AXSystemDialog`; half-point overlap collapse; substantially containing wrappers are removed only among unknown-subrole compatibility candidates; unique largest SystemDialog first, otherwise one corroborated Dialog frame, then one Dialog frame; if near-square candidates are absent, one unique non-standard `AXWindow/AXDialog` with valid geometry is accepted as a bounded compatibility fallback; fail closed for ties or persistent ambiguity |
| AX data | application window list, role, subrole, minimized, hidden, position, and size only |
| AX events | Pet moved, resized, destroyed, and application window created |
| Burst handling | 80 ms callback coalescing; 160 ms stability recheck for non-atomic overlapping layers |
| Placement | separate version-1 normalized Pet point plus fixed point offset to the Halo logical reference |
| Hierarchy | Pet target, then calibrated M4 Codex window, then M3 free-floating |
| Recovery | preserve Pet anchor; retry Pet discovery every five seconds while fallback is active; stale generations ignored |
| Interaction | existing non-activating panel, compact click-through, expanded scrolling, and display containment remain unchanged |

Direct discovery observed the Pet core move independently while the standard Codex window stayed stationary, disappear on Tuck Away, and return on Wake. Activity UI could move above or below Pet and expose separate controls, so neither relative position nor button count is used. Current Desktop exposes one larger near-square SystemDialog Pet core and one smaller near-square SystemDialog control; the unique area ordering remains stable across idle and activity states. Coincident Dialog identities are only a compatibility fallback because their frame may remain stale after Wake. The selector also tolerates a changed subrole only when exactly one non-standard near-square surface remains, and removes a larger near-square surface that substantially contains another only when both are unknown-subrole compatibility candidates. For the newer observed topology, when no near-square candidate exists, exactly one visible non-standard `AXDialog` with valid finite geometry is accepted; multiple such frames remain ambiguous. Known SystemDialog/Dialog ordering is unchanged so embedded controls cannot displace the Pet core. A tied largest SystemDialog, multiple corroborated or unknown fallback frames, or persistent unresolved ambiguity activates fallback rather than guessing.

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

M7 preserves that raw AX midpoint as the tracking basis while adding a separate fixed visual-center offset to the complete Pet Ring panel. It does not reactivate the M5 normalized anchor. M7 also observes only wide activity-window geometry as a post-selection arc-orientation hint and compares it with the calibrated visual center; when activity is absent, the selected display's visible-frame midpoint supplies the upper/lower default. Neither input changes the M6 center-locked panel placement.

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

### Beta 9 publication compatibility boundary — 2026-10-11

Codex Desktop `26.1007.30912 (20156)` was the directly accepted positioning host.
The local installed CLI reported `0.162.0-alpha.17.2`; lifecycle startup/shutdown
passed, but no new CLI schema review or registry entry is claimed. The reviewed
baseline remains `0.145.0-alpha.18`; protocol semantics are unchanged. Public
Beta 9 notes are frozen, and capture permission/clean-machine acceptance remains
distinct from the instrumented release lifecycle smoke.
