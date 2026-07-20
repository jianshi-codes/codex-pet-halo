# M7 — Pet Ring Surface & Target-aware Presentation

- Branch: `m7/pet-ring-presentation`
- Scope: target-aware surface state, persistent visual-center alignment, concentric Usage rings, semantic thresholds, functional dialog-aware partial arcs, fallback preservation, tests, sanitized smoke tooling, and documentation
- Gate: implementation and automated validation complete; final live interaction and current-patch CI validation pending

## Outcome

Pet is never allowed to render a card. The explicit surface model selects only `petRing` for Pet and retains `compactCard`/`expandedCard` for the M4 Codex-window and M3 free-floating fallbacks. Entering Pet records the prior card choice and switches the panel surface before applying placement. Leaving Pet restores the previous card mode and reference. Direct Compact or Expanded requests have no effect while Pet is active.

The ring is a fixed `252×252` transparent SwiftUI vector surface with three independent 6-point tracks at 104/94/84-point radii and a `162`-point transparent center. Labels use fixed overlay positions and cannot move the shared center. It has no material, rounded card, title container, ScrollView, in-panel control, panel shadow, or pointer interaction. The existing `.nonactivatingPanel`, key/main prohibitions, all-Spaces behavior, and lifecycle teardown remain unchanged.

The AX Pet midpoint remains the tracking basis. The whole panel is placed at `petFrame.center + PetVisualCenterOffset`; a versioned fixed `dx/dy` preference is adjusted through menu fine-tune actions, applies equally to every arc and label, and survives Pet movement, Tuck Away/Wake, and restart. It does not participate in Pet discovery or selection.

## Usage semantics

The Pet-specific presentation model is independent of raw `CodexUsageState` and Expanded Account Usage rows.

| Metric | M7 rule |
| --- | --- |
| Weekly | Use domain `remainingPercent` directly; retain current/stale/unavailable from rate-limit component freshness |
| Five-hour | Render only when the capability contains an exact 300-minute window; otherwise omit |
| Today tokens | Inner ring uses today tokens divided by `peakDailyTokenCount`; omit for a missing/duplicate day, missing peak, zero peak, or unavailable freshness; clamp progress to 100% while retaining actual token text |

Weekly and 5h are healthy at 50% remaining, warning from 20% through 49%, and critical below 20%. Today is healthy through 50% of peak, warning above 50% through 80%, and critical above 80%. Restrained system green/orange/red colors are centralized behind `PetRingPresentationPolicy`. Stale arcs also use reduced opacity, dashes, visible text, and per-ring accessibility values.

When a unique wide activity dialog is above Pet, all partial arcs leave the top open; when it is below, all leave the bottom open. No dialog uses one fixed default. Ambiguous geometry retains the previous direction. Direction changes are debounced and update only start/sweep angles; target selection, panel placement, offset, and fallback do not change.

## Preservation and boundaries

Compact and Expanded cards are not deleted. Expanded Account Usage rows, scrolling, non-activation, calibration behavior, and card mouse policies remain available outside Pet. `ApplicationCoordinator` is still the only bridge-state stream consumer and owns both card and ring presentation values.

M7 adds no OpenAI, ChatGPT, or Codex Pet artwork; no screenshots, OCR, Screen Recording, settings/details window, analytics, telemetry, or new protocol method. It does not add themes, glow, particles, pulse, sound, or animation. M8 owns advanced polish beyond the fixed M7 policy, themes, decorative low-usage styling, glow, motion preferences, and animations.

## Verification matrix

| Gate | Current result |
| --- | --- |
| Debug product compilation | PASS |
| Target/surface transitions, offset persistence, orientation, and fallback restoration | PASS — focused 89-test M7 bundle |
| Ring geometry, transparent-center contract, no card background, shadow, and click policy | PASS — deterministic |
| Three independent rings, thresholds, Today denominator, and component freshness | PASS — deterministic |
| M0-M6 regression and complete Swift suite | PASS — 92 Swift tests plus 14 M0 tests |
| Debug and universal Release bundle | PASS — Debug plus arm64/x86_64 Release |
| Source, privacy, generated-project, and bundle boundaries | PASS |
| Draft PR CI | Prior PASS — Protocol evidence and macOS application jobs on pushed commit `9c7a4b9`; current patch pending push |
| M5-M7 smoke | RUN / PARTIAL — visible unique Pet, automatic Pet Ring, initial offset sample, and non-activation observed; Pet movement and Tuck Away/Wake/Quit did not occur, so each script failed closed |
| Direct visible-Pet/no-rectangle confirmation | PARTIAL — current Pet Halo surface directly shows concentric partial arcs, transparent center, separated labels, optional 5h omission, and no rectangle; simultaneous underlying-Pet containment and dialog complement remain pending because the validation tool cannot operate or capture Codex itself |
| Independent review | Pending publication review |

M7 becomes PASS only after every pending row is closed with current-tree evidence. A Draft PR does not authorize merge or M8.
