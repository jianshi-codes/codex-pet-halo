# ADR 0009: Target-aware Halo surface

- Status: Accepted for M7
- Date: 2026-07-20

## Context

M6 center-locks one fixed panel to the Pet midpoint but temporarily renders the M3 Compact card there. Compact and Expanded are fallback-card choices, not valid Pet presentations. Reusing that two-state card mode as the target surface risks applying the `360×520` Expanded frame or its material card at the Pet midpoint during discovery, loss, or Wake.

The Pet surface also needs a much smaller data contract than Expanded Account Usage. Weekly and five-hour rates use rate-limit freshness, while Today tokens use Account Usage freshness and calendar-day semantics. Missing daily data must not become zero.

## Decision

Introduce `HaloSurfaceMode` with `petRing`, `compactCard`, and `expandedCard`. `ApplicationCoordinator` remains the sole owner of target, Usage, remembered fallback card choice, and current surface.

- Pet activation records the fallback card mode and non-Pet reference, switches directly to `petRing`, then applies the centered ring layout.
- Pet loss restores a delivered M4 window reference when present; otherwise it restores the saved free-floating reference before applying the remembered card mode.
- Card commands are rejected while Pet is active.
- `HaloPanelController` applies surface-specific size, shadow, and mouse policy. Pet Ring is `208×208`, shadowless, click-through, non-activating, and cannot become key or main.
- `HaloView` routes Pet directly to `PetRingView`. Card-only padding, material, rounded clipping, calibration overlay, and scrolling remain outside that branch.

`PetRingPresentationMapper` is separate from `HaloPresentationMapper`. It accepts an injected Date plus Calendar, Locale, and TimeZone semantics. Weekly uses domain `remainingPercent`; five-hour appears only for an exact 300-minute capability; Today tokens require exactly one daily bucket in the injected current day. Missing or ambiguous buckets are unavailable, while an explicit zero stays zero. Component freshness is never replaced by aggregate freshness.

The fixed geometry uses SwiftUI vector paths only: a 84-point primary radius, 10-point primary stroke, 5-point secondary stroke, fixed full sweep, and a 158-point transparent center. Text exposes freshness and normal/low/critical state so meaning is not color-only. Decorative arcs are accessibility-hidden and the ring is one coherent accessibility group.

## Consequences

Fallback cards and their full Account Usage presentation remain intact. The Pet model cannot expose lifetime, peak, streak, longest-turn, or recent-history fields. No screenshots, OCR, visual detection, official artwork, settings window, persistence, network request, telemetry, animation, or announcement loop is added.

M8 exclusively owns advanced visual polish, arc angle/orientation changes, themes, low-usage styling, glow, motion preferences, and animations. M9 remains separately gated.
