# M4 Window Following

- Status: **PASS**
- Date: 2026-07-20
- Scope: explicit Accessibility workflow, exact Codex/window selection, calibrated relative anchoring, event-driven following, multi-display containment, safe preferences, fallback, lifecycle, tests, smoke, CI, and documentation
- Stop condition: M4 Draft PR; do not merge and do not begin M5

## Implemented architecture

`ApplicationCoordinator` remains the sole owner of the bridge-state stream, Halo panel, and window-following service. The service loads validated placement preferences, starts exact-bundle lifecycle observation, and checks Accessibility trust without prompting. Only the explicit Enable command invokes the prompt option. All UI and panel mutation stays on the main actor.

The exact `com.openai.codex` application is selected without name matching, shells, paths, or broad process parsing. Window selection is focused eligible standard, then main eligible standard, then exactly one eligible standard window. AX access is limited to role/subrole, minimized, position, size, focused/main/window list and geometry/lifecycle notifications. No title or UI content enters product logic.

The coordinate boundary converts AX Y-down geometry to AppKit Y-up geometry once. Calibration persists version 1: a normalized point inside the Codex window plus a fixed point offset to the Halo upper-right reference. Compact/expanded mode changes preserve that reference. Placement uses the anchor screen's visible frame, supports negative display origins and screen removal, and never persists a screen index.

Movement bursts are coalesced to one main-actor delivery per 50 ms. Process/window generations reject stale callbacks. Free-floating fallback preserves the visible Halo when permission, Codex, a deterministic window, or an observer is unavailable. Temporary Codex loss retains calibration. Exact lifecycle events resolve immediately; the single five-second recovery task retries a transient launch-before-window-ready state without recalibration. Shutdown cancels recovery and stops window observation before closing the panel and awaiting bridge shutdown.

## Privacy and persisted fields

Only `windowFollowing.enabled` and `windowFollowing.anchor.v1` are persisted under the full `io.github.jianshicodes.PetHalo` namespace. The anchor contains version, normalized X/Y, and point-offset width/height after finite/range validation. Usage, account identity, PID, window identity/title/frame, screen index, executable path, AX elements, and protocol data are not persisted or logged.

M4 introduces no Screen Recording, screenshots, OCR, Pet recognition, Apple Events, private IPC, analytics, telemetry, visual animation, artwork, sound, or themes.

## Automated evidence

| Evidence | Result |
| --- | --- |
| `make m4-tests` | PASS — 36 focused process/window/geometry/anchor/persistence/service/panel/coordinator tests |
| `make test` | PASS — 51 Core tests plus 49 application tests; 1 local-only bridge smoke skipped normally |
| `make check` | PASS — Debug build, universal Release build (`arm64` + `x86_64`), all automated tests, generated-project drift, source boundary, bundle, privacy, and absolute-path gates |
| `make m2-smoke` | PASS — exact supported Codex CLI, read-only handshake/Usage, one accessory Halo, unchanged activation, clean owned-child shutdown |
| `make m3-smoke` | PASS — deterministic presentation plus authenticated non-activating Halo lifecycle regression |
| `make m4-smoke` | PARTIAL — deterministic following checks and M2 live regression passed; Accessibility was unavailable, so exact live Codex window observation and direct interaction were not attempted |
| Process/window selection | PASS — exact bundle, active-candidate rule, focused/main/sole-window order, ambiguity and transient rejection |
| Coordinates/multi-display | PASS — primary, negative X, negative Y, mixed sizes, boundary crossing, screen removal, oversized frame |
| Calibration/persistence | PASS — begin/finish/cancel, no pre-Finish write, old-version/numeric validation, compact restoration |
| Observation/lifecycle | PASS — burst coalescing, invalidation priority, stale generation, post-stop rejection, coordinator shutdown order |
| Relaunch race regression | PASS — process launch may precede window availability; a later recovery tick reuses the saved anchor and returns to following without another system event or calibration write |

Draft PR CI is recorded on the PR. Direct validation and the relaunch defect/recheck are recorded below.

## Manual gate closure

Direct validation on commit `60cc14b353f9e3d5ab1ca2ddcb5bec13951bc2f6` passed explicit permission, target resolution, calibration/Cancel, physical move/resize, compact/expanded stability, click-through, scrolling, focus retention, permission recovery, Codex termination fallback, Pet Halo restart, cleanup, and multi-display behavior. It exposed one defect: a Codex relaunch could remain suspended when the launch event arrived before the new standard window. Commit `a79e0ac779d520e8e0c969ddf210157fb1b224c5` fixed that race; deterministic testing and focused physical Codex relaunch recovery both passed without recalibration. All M4 automated, CI, smoke, privacy, lifecycle, and direct interaction gates are satisfied, so M4 is **PASS**. M5 and Pet recognition remain separately gated and are not authorized by this closure.
