# M7 — Pet Ring Surface & Target-aware Presentation

- Branch: `m7/pet-ring-presentation`
- Scope: target-aware surface state, persistent visual-center alignment, concentric Usage rings, semantic thresholds, functional dialog-aware partial arcs, fallback preservation, tests, sanitized smoke tooling, and documentation
- Gate: implementation, automated validation, and direct live interaction complete; current patch publication, CI, and independent review pending

## Outcome

Pet is never allowed to render a card. The explicit surface model selects only `petRing` for Pet and retains `compactCard`/`expandedCard` for the M4 Codex-window and M3 free-floating fallbacks. Entering Pet records the prior card choice and switches the panel surface before applying placement. Leaving Pet restores the previous card mode and reference. Direct Compact or Expanded requests have no effect while Pet is active.

The ring is a fixed `252×252` transparent SwiftUI vector surface with three independent 6-point tracks at 104/94/84-point radii and a `162`-point transparent center. Horizontal labels use distinct polar anchors tied to those radii and mirror when the opening flips; fixed frames and scale floors keep them inside the panel without moving the shared center. It has no material, rounded card, title container, ScrollView, in-panel control, or panel shadow. Normal mode remains pointer-transparent; only explicit center adjustment temporarily accepts drag events, without key/main eligibility.

The AX Pet midpoint remains the tracking basis. The whole panel is placed at `petFrame.center + PetVisualCenterOffset`; `Adjust Ring Center` exposes a temporary crosshair plus drag/4-point nudges, Save, Cancel, and Reset. Save persists only the fixed `dx/dy`; it applies equally to every arc and label and survives Pet movement, Tuck Away/Wake, Codex restart, and Pet Halo restart. It does not participate in Pet discovery or selection, and visual containment remains a required manual check.

## Usage semantics

The Pet-specific presentation model is independent of raw `CodexUsageState` and Expanded Account Usage rows.

| Metric | M7 rule |
| --- | --- |
| Weekly | Use domain `remainingPercent` directly; retain current/stale/unavailable from rate-limit component freshness |
| Five-hour | Render only when the capability contains an exact 300-minute window; otherwise omit |
| Today tokens | Inner ring uses today tokens divided by `peakDailyTokenCount`; omit for a missing/duplicate day, missing peak, zero peak, or unavailable freshness; clamp progress to 100%, show locale-aware K/M/B plus the truthful ratio, and retain the exact count in accessibility |

Weekly and 5h are healthy at 50% remaining, warning from 20% through 49%, and critical below 20%. Today is healthy through 50% of peak, warning above 50% through 80%, and critical above 80%. Restrained system green/orange/red colors are centralized behind `PetRingPresentationPolicy`. Stale arcs also use reduced opacity, dashes, visible text, and per-ring accessibility values.

Auto prefers the current unique wide `AXSystemDialog` activity surface and falls back to the earlier unique wide `AXDialog` form. Its above/below comparison uses the calibrated visual Pet center rather than the padded raw AX midpoint. Activity above that center leaves the top open; activity below leaves the bottom open. No activity uses one fixed default, and ambiguous geometry retains the previous direction. Direction changes are debounced and update only start/sweep angles; target selection, panel placement, offset, and fallback do not change.

DEBUG builds expose Auto, Force Gap Above, and Force Gap Below previews. The override changes only effective arc and mirrored label angles and is not written to preferences. Production remains Auto.

Pet movement uses an immediate main-run-loop AX callback path and one latest-value display-linked follower. A notification wakes the follower; while active it re-reads only the already-selected coincident Pet core frames and stops after four unchanged refreshes, without enumerating windows or changing target selection. A missing event-path snapshot is retried after `16 ms`; dialog orientation alone retains a `180 ms` debounce. Medium continuous moves apply only the newest target exactly; they do not replay intermediate samples or add a multi-frame chase. Moves within `1.25 pt` snap immediately, as do first attachment, Wake/target replacement, Reduce Motion, and jumps of at least `96 pt`. Synchronous macOS Accessibility attribute freshness remains an external latency limit.

## Preservation and boundaries

Compact and Expanded cards are not deleted. Expanded Account Usage rows, scrolling, non-activation, calibration behavior, and card mouse policies remain available outside Pet. `ApplicationCoordinator` is still the only bridge-state stream consumer and owns both card and ring presentation values.

M7 adds no OpenAI, ChatGPT, or Codex Pet artwork; no screenshots, OCR, Screen Recording, settings/details window, analytics, telemetry, or new protocol method. It does not add themes, glow, particles, pulse, sound, or decorative animation. M8 owns advanced polish beyond the fixed M7 policy, themes, decorative low-usage styling, glow, motion preferences, and decorative animations.

## Verification matrix

| Gate | Current result |
| --- | --- |
| Debug product compilation | PASS |
| Target/surface transitions, offset persistence, orientation, movement following, and fallback restoration | PASS — focused 105-test M7 bundle |
| Ring geometry, transparent-center contract, no card background, shadow, and click policy | PASS — deterministic |
| Three independent rings, thresholds, Today denominator, and component freshness | PASS — deterministic |
| M0-M6 regression and complete Swift suite | PASS — 158 Swift tests with one local-only authenticated smoke skipped, plus 14 M0 tests |
| Debug and universal Release bundle | PASS — Debug plus arm64/x86_64 Release |
| Source, privacy, generated-project, and bundle boundaries | PASS |
| Draft PR CI | PASS — Protocol evidence and macOS application jobs on implementation commit `063a73a` |
| M7 smoke | PASS — fast independent movement with saved visual offset and bounded selected-frame sampling, Tuck Away fallback, Wake recovery, surface restoration, non-activation, Quit, observer shutdown, and owned app-server cleanup directly observed |
| Direct visible-Pet/no-rectangle confirmation | PASS — user-operated calibration confirmed visible Pet containment; forced openings retained the calibrated center; Auto directly mirrored for the activity surface below the calibrated visual Pet center; final fast-drag tracking feel was accepted; supplied/current screenshots show concentric partial arcs, transparent center, separated labels, optional 5h omission, and no rectangle |
| Independent review | Pending publication review |

M7 becomes PASS only after every pending row is closed with current-tree evidence. A Draft PR does not authorize merge or M8.
