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
- `HaloPanelController` applies surface-specific size, shadow, and mouse policy. Pet Ring is a `448×252` transparent panel centered on the same Pet point, shadowless, normally click-through, non-activating, and cannot become key or main. Only explicit visual-center calibration temporarily accepts dragging.
- `HaloView` routes Pet directly to `PetRingView`. Card-only padding, material, rounded clipping, and scrolling remain outside that branch; Pet calibration adds only a temporary center outline/crosshair.

`PetRingPresentationMapper` is separate from `HaloPresentationMapper`. It accepts an injected Date plus Calendar, Locale, and TimeZone semantics. Weekly uses domain `remainingPercent`; five-hour appears only for an exact 300-minute capability; Today requires one current-day bucket and a nonzero historical peak. Today progress is clamped at 100% without changing its token text. Component freshness is never replaced by aggregate freshness.

The fixed geometry uses a `448×252` transparent surface centered on the Pet. Three independent SwiftUI vector tracks and progress arcs retain 104/94/84-point radii with 6-point strokes and a 162-point transparent center; only the transparent horizontal canvas grows to hold labels outside the rings. Weekly, five-hour, and Today labels use compact capsules in one fixed-size absolute stack; fixed identity dots and tinted keys remain separate from semantic progress colors. The right-side stack aligns its leading edge and uses short neutral dashed connectors, then mirrors to a trailing-edge-aligned left stack with the opening. Today uses one locale-aware K/M/B formatter for visible text while accessibility retains the exact token count. Weekly and five-hour colors use remaining thresholds of 50% and 20%; Today uses consumption thresholds of 50% and 80%. Stale metrics also use opacity, dash, visible text, and accessibility state.

The AX Pet midpoint remains the discovery and tracking basis. A separate versioned `PetVisualCenterOffset(dx, dy)` moves the complete panel, rings, and absolute-position labels together and survives movement, Tuck Away/Wake, and restart. `Adjust Ring Center` uses the retained calibration API: drag/nudge changes only the temporary panel reference, Save persists only the offset, Cancel restores the saved offset, and Reset persists zero. The old normalized Pet anchor remains deleted. Automatic visual containment is not claimed; it remains a manual acceptance check.

Wide activity geometry is evaluated only after core selection and can produce above, below, none, or ambiguous hints. A unique wide `AXSystemDialog` is preferred for the current activity surface, while a unique wide `AXDialog` remains the compatibility fallback. Auto compares its vertical delta with the persisted visual-center offset so the direction is relative to the rendered Pet, without feeding the offset or activity geometry into discovery, tracking, or placement. All rings share one fixed partial-arc opening. Stable above/below/no-activity hints use a dedicated `180 ms` debounce; ambiguous hints retain the previous orientation. A DEBUG-only Auto/Force Gap Above/Force Gap Below override changes only effective arc and label angles and is never persisted.

Pet geometry callbacks have no fixed coalescing sleep. When a callback races an unavailable event-path sample, one latest-value retry occurs after `16 ms`. `HaloPanelController` owns one display-linked follower: a movement notification wakes it, and each active refresh synchronously samples only the already-selected coincident core elements through a generation-checked layout seam. Four unchanged refreshes pause the sampler. Continuous movement replaces one latest target and applies it exactly, so intermediate samples are never replayed and no multi-frame chase is added. Moves within `1.25 pt` snap immediately, as do first attachment, target replacement, Wake, Reduce Motion, or jumps of at least `96 pt`. It never queues NSWindow animations. Accessibility attribute freshness remains an external latency limit.

## Consequences

Fallback cards and their full Account Usage presentation remain intact. The Pet model uses historical peak only as the Today denominator and cannot expose lifetime, streak, longest-turn, or recent-history fields. No screenshots, OCR, visual detection, official artwork, settings window, network request, telemetry, decorative animation, or announcement loop is added.

M8 exclusively owns advanced visual polish beyond this fixed functional policy, themes, decorative low-usage styling, glow, motion preferences, and animations. M9 remains separately gated.
