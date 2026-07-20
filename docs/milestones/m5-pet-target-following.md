# M5 Pet Target Discovery & Pet-relative Following

- Branch: `m5/pet-target-following`
- Route: `ROUTE_A — PET_ACCESSIBILITY_WINDOW`
- Scope: Pet discovery, Pet-relative calibration/following, fallback/recovery, tests, smoke, privacy, and documentation
- Stop condition: M5 Draft PR; do not merge and do not begin M6

## Outcome

M5 adds deterministic Pet-relative following with optional manual Pet-relative calibration while preserving the established hierarchy: Pet first, calibrated Codex standard window second, free-floating Halo last. Pet and window calibrations use independent versioned anchors. Missing permission, no Pet, ambiguity, or observer failure never hides Usage and never triggers a broader inspection route.

The discovery evidence and route gate are recorded in [the discovery report](m5-pet-target-discovery-report.md). Production selection is based only on a unique near-square `AXWindow/AXDialog` logical frame inside the exact Codex process. The activity dialog may move above or below Pet and may expose controls; none of those details are product inputs.

## Implementation

- `PetTargetSnapshot`, `PetTargetDiscoveryState`, and `HaloFollowingTargetSource` isolate presentation from AX objects and process identity.
- `PetWindowSelector` filters and groups geometric candidates without title, identifier, or array order.
- `AccessibilityPetTargetAccessor` owns minimal observers and exactly-once teardown.
- `WindowFollowingService` prefers Pet, retains M4/M3 fallback, ignores stale generations, coalesces events, and retries stable selection after transient layered movement.
- Activity-window creation or destruction during Pet calibration first revalidates the core target. Periodic recovery and display-driven placement are paused while calibration is active, so neither path resets a valid in-progress placement.
- Cancel exits calibration exactly once, disables panel calibration, restores the pre-calibration reference point and target suppression state, clears transient calibration data, and only then resolves the preferred target. It never persists an anchor.
- Enable Pet Following, Use Codex Window Fallback, Reset Pet Position, and both begin-calibration commands are rejected while calibration is active. Finish, Cancel, Disable Following, and Quit remain valid calibration exit paths.
- `PetRelativeAnchor` stores a normalized Pet point plus fixed point offset under its own key.
- Menu status exposes only safe target and discovery enums and separate Pet/window calibration actions.
- Static checks keep content-bearing AX attributes, broad application scanning, screen capture, OCR, private IPC, databases, and Usage persistence prohibited.

## Privacy

Production M5 uses the existing explicit Accessibility permission. Startup checks trust without prompting; only the user command to enable following may request access. The Pet accessor reads only window list, role, subrole, minimized, hidden, position, and size for the exact Codex process and observes created/moved/resized/destroyed events.

No Screen Recording entitlement, ScreenCaptureKit, screenshot, image asset, OCR, title, value, description, identifier, selected text, document content, prompt, response, raw tree logging, analytics, telemetry, or new network request was added.

## Validation status

The focused deterministic M5 suite covers selection, overlap collapse, unrelated dialogs, activity UI on either side, ambiguity, invalid geometry, Pet anchors, negative coordinates, movement/resize, stale generations, target hierarchy, loss/recovery, separate calibration, cancellation event ordering and idempotency, command guards, preferences, callback coalescing, panel interaction, coordinator shutdown, and all retained M4 cases.

The discovery phase directly observed independent Pet movement with the standard Codex window stationary, Pet hide invalidation, and Wake rediscovery. Production interaction then confirmed Pet-relative following, Tuck Away fallback to the calibrated Codex window, Wake recovery without recalibration, and a calibration held open beyond the five-second recovery tick without reverting.

| Gate | Result |
| --- | --- |
| `make check` | PASS — Debug, universal Release, bundle, generated project, privacy/source boundaries, 51 Core tests, 75 application tests, and 14 M0 tests |
| `make m5-tests` | PASS — 62 focused tests |
| `make m2-smoke` | PASS — read-only bridge and owned-child shutdown |
| `make m3-smoke` | PASS — non-activating presentation regression |
| `make m4-smoke` | PASS — deterministic fallback, live Accessibility target, and bridge regression |
| `make m5-smoke` | PASS — Route A unique target, independent Pet movement, and stationary standard window |
| Direct interaction | PASS — Pet follow, window fallback, Pet recovery, and stable delayed calibration |
| Screen Recording / visual detection | Absent |
| Draft PR CI | Required for the current pushed Head before the final M5 gate |

One complete gate run exposed a pre-existing timing-sensitive M2 refresh-coalescing test once; 120 of 121 non-skipped Swift tests passed in that run. The exact failed test passed on immediate isolated retry, and the following full `make check` passed the complete suite with 121 passes and one designed local-only skip. No M2 source was changed.

## Known fragility

Codex does not document the observed AX surface composition as a compatibility API. Role/subrole or overlapping-layer behavior may change between Desktop builds. The selector deliberately fails closed; a future incompatible build will fall back to M4/M3 until a separately reviewed compatibility change is proven. Automatic attachment and center-locked placement remain M6; the final semicircular visual design, percentage label, semantic status treatment, themes, and motion remain M7; hardening and release readiness remain M8.
