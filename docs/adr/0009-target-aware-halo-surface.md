# ADR 0009: Target-aware Halo surface

- Status: Accepted for M7
- Date: 2026-07-20

## Context

M6 center-locks one fixed panel to the Pet midpoint but temporarily renders the M3 Compact card there. Compact and Expanded are fallback-card choices, not valid Pet presentations. Reusing that two-state card mode as the target surface risks applying the `360×520` Expanded frame or its material card at the Pet midpoint during discovery, loss, or Wake.

The Pet surface also needs a much smaller data contract than Expanded Account Usage. Weekly and five-hour rates use rate-limit freshness, while Today tokens use Account Usage freshness and calendar-day semantics. Missing daily data must not become zero.

## Decision

Introduce `HaloSurfaceMode` with `petRing`, `compactCard`, and `expandedCard`. `ApplicationCoordinator` remains the sole owner of target, Usage, remembered fallback card choice, and current surface.

- Pet activation records the fallback card mode and non-Pet reference, switches directly to `petRing`, then applies the AX-center tracking layout plus the persisted visual-center offset.
- Pet loss restores a delivered M4 window reference when present; otherwise it restores the saved free-floating reference before applying the remembered card mode.
- Card commands are rejected while Pet is active.
- `HaloPanelController` applies surface-specific size, shadow, and mouse policy. Pet Ring is `252×252`, shadowless, click-through, non-activating, and cannot become key or main.
- `HaloView` routes Pet directly to `PetRingView`. Card-only padding, material, rounded clipping, calibration overlay, and scrolling remain outside that branch.

`PetRingPresentationMapper` is separate from `HaloPresentationMapper`. It accepts an injected Date plus Calendar, Locale, and TimeZone semantics. Weekly uses domain `remainingPercent`; five-hour appears only for an exact 300-minute capability; Today requires one current-day bucket and a nonzero historical peak. Today progress is clamped at 100% without changing its token text. Component freshness is never replaced by aggregate freshness.

The fixed geometry uses three independent SwiftUI vector tracks and progress arcs at 104/94/84-point radii with 6-point strokes and a 162-point transparent center. Weekly and five-hour colors use remaining thresholds of 50% and 20%; Today uses consumption thresholds of 50% and 80%. Stale metrics also use opacity, dash, visible text, and accessibility state.

The AX Pet midpoint remains the discovery and tracking basis. A separate versioned `PetVisualCenterOffset(dx, dy)` moves the complete panel, rings, and absolute-position labels together and survives movement, Tuck Away/Wake, and restart. Menu fine-tune actions call the retained calibration API while the Pet panel remains click-through. The old normalized Pet anchor remains deleted.

Wide activity-dialog geometry is evaluated only after core selection and can produce above, below, none, or ambiguous hints. All rings share one fixed partial-arc opening. Stable above/below/no-dialog hints are debounced; ambiguous hints retain the previous orientation. Orientation events update only arc angles and never placement or fallback.

## Consequences

Fallback cards and their full Account Usage presentation remain intact. The Pet model uses historical peak only as the Today denominator and cannot expose lifetime, streak, longest-turn, or recent-history fields. No screenshots, OCR, visual detection, official artwork, settings window, network request, telemetry, animation, or announcement loop is added.

M8 exclusively owns advanced visual polish beyond this fixed functional policy, themes, decorative low-usage styling, glow, motion preferences, and animations. M9 remains separately gated.
