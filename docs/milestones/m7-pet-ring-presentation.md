# M7 — Pet Ring Surface & Target-aware Presentation

- Branch: `m7/pet-ring-presentation`
- Scope: target-aware surface state, functional Pet Ring, basic Usage metrics, fallback preservation, tests, sanitized smoke tooling, and documentation
- Gate: implementation complete; final automated/live/CI validation pending

## Outcome

Pet is no longer allowed to render a card. The explicit surface model selects only `petRing` for Pet and retains `compactCard`/`expandedCard` for the M4 Codex-window and M3 free-floating fallbacks. Entering Pet records the prior card choice, switches the panel surface before applying the Pet layout, and remains center-locked at every accepted geometry update. Leaving Pet restores the previous card mode. If M4 supplied a fallback reference first, that reference is retained; otherwise the saved free-floating reference is restored before card resizing. Direct Compact or Expanded requests have no effect while Pet is active.

The ring is a fixed `208×208` transparent SwiftUI vector surface with an 84-point primary radius, 10-point primary line, 5-point secondary line, and a `158`-point transparent center. It has no material, rounded card, title container, ScrollView, control, panel shadow, or pointer interaction. The existing `.nonactivatingPanel`, key/main prohibitions, all-Spaces behavior, and lifecycle teardown remain unchanged.

## Usage semantics

The Pet-specific presentation model is independent of raw `CodexUsageState` and Expanded Account Usage rows.

| Metric | M7 rule |
| --- | --- |
| Weekly | Use domain `remainingPercent` directly; retain current/stale/unavailable from rate-limit component freshness |
| Five-hour | Render only when the capability contains an exact 300-minute window; otherwise omit |
| Today tokens | Select exactly one Account Usage daily bucket matching the injected Date in the injected Calendar/TimeZone; missing or duplicate match is unavailable; explicit zero displays `0` |

Normal, low, and critical remaining levels are deterministic. Stale arcs use a line-style difference, and visible/accessibility text names freshness and low/critical state. The surface is one accessibility group; decorative arcs are hidden. Periodic updates change the value without generating announcements.

## Preservation and boundaries

Compact and Expanded cards are not deleted. Expanded Account Usage rows, scrolling, non-activation, calibration behavior, and card mouse policies remain available outside Pet. `ApplicationCoordinator` is still the only bridge-state stream consumer and owns both card and ring presentation values.

M7 adds no OpenAI, ChatGPT, or Codex Pet artwork; no screenshots, OCR, Screen Recording, settings/details window, analytics, telemetry, persistence, or new protocol method. It does not add themes, glow, particles, pulse, sound, or animation. M8 owns advanced polish, arc angle/orientation changes, themes, low-usage styling, glow, motion preferences, and animations.

## Verification matrix

| Gate | Current result |
| --- | --- |
| Debug product compilation | PASS |
| Target/surface transitions and fallback restoration | PASS — focused 79-test M7 bundle |
| Ring geometry, transparent-center contract, no card background, shadow, and click policy | PASS — deterministic |
| Weekly/five-hour/Today mapping and component freshness | PASS — deterministic |
| M0-M6 regression and complete Swift suite | PASS — 82 Swift tests plus 14 M0 tests |
| Debug and universal Release bundle | PASS — Debug plus arm64/x86_64 Release |
| Source, privacy, generated-project, and bundle boundaries | PASS |
| Draft PR CI | PASS — Protocol evidence and macOS application jobs on pushed commit `9c7a4b9` |
| M2-M7 smoke | M2/M3 PASS; M4 completes with standard window unavailable; M5-M7 blocked until a unique visible Pet and normal Codex window are present |
| Direct visible-Pet/no-rectangle confirmation | Pending observer confirmation; screenshots and visual detection are out of scope |
| Independent review | Pending publication review |

M7 becomes PASS only after every pending row is closed with current-tree evidence. A Draft PR does not authorize merge or M8.
