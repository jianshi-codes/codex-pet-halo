# M7 — Pet Ring Surface & Target-aware Presentation

- Branch: `m7/pet-ring-presentation`
- Scope: target-aware surface state, persistent visual-center alignment, concentric Usage rings, semantic thresholds, functional dialog-aware partial arcs, fallback preservation, tests, sanitized smoke tooling, and documentation
- Status: **PASS**
- Gate: implementation, automated validation, direct live interaction, live smoke, independent review, Draft PR publication, and current-head CI complete; no unresolved review threads

## Outcome

Pet is never allowed to render a card. The explicit surface model selects only `petRing` for Pet and retains `compactCard`/`expandedCard` for the M4 Codex-window and M3 free-floating fallbacks. Entering Pet records the prior card choice and switches the panel surface before applying placement. Pet loss hides Halo by default; the Codex-window card appears only after explicit menu selection. Direct Compact or Expanded requests have no effect while Pet is active.

The ring uses a fixed `448×252` transparent SwiftUI vector surface whose midpoint remains the Pet visual center. Its three independent 6-point tracks retain 104/94/84-point radii and a `162`-point transparent center; the added horizontal canvas is only for labels. Horizontal Weekly/5h/Today capsules use fixed identity dots and tinted keys while progress arcs retain status-driven system colors. Their fixed-size absolute stack uses the top-to-bottom order Today / optional 5h / Weekly, sits outside the rings, aligns its leading edge on the right, uses short neutral dashed connectors, and mirrors to a trailing-edge-aligned left stack without reversing order when the opening flips; fixed frames and scale floors keep it inside the panel without moving the shared center. It has no material, rounded card, title container, ScrollView, in-panel control, or panel shadow. Normal mode remains pointer-transparent; only explicit center adjustment temporarily accepts drag events, without key/main eligibility.

The AX Pet midpoint remains the tracking basis. Pet core selection prefers the unique stable near-square `AXSystemDialog` and uses near-square `AXDialog` only as a compatibility fallback. The whole panel is placed at `petFrame.center + PetVisualCenterOffset`; `Adjust Ring Center` exposes a temporary crosshair plus drag/4-point nudges, Save, Cancel, and Reset. Save persists only the fixed `dx/dy`; it applies equally to every arc and label and survives Pet movement, Tuck Away/Wake, Codex restart, and Pet Halo restart. The current versioned offset ignores values saved against the incompatible earlier core basis. It does not participate in Pet discovery or selection, and direct manual validation passed visible-Pet containment.

## Usage semantics

The Pet-specific presentation model is independent of raw `CodexUsageState` and Expanded Account Usage rows.

| Metric | M7 rule |
| --- | --- |
| Weekly | Use domain `remainingPercent` directly; retain current/stale/unavailable from rate-limit component freshness |
| Five-hour | Render only when the capability contains an exact 300-minute window; otherwise omit |
| Today tokens | Inner ring uses the Codex UTC account day's tokens divided by `peakDailyTokenCount`; omit for a missing/duplicate day, missing peak, zero peak, or unavailable freshness; clamp progress to 100%, show locale-aware K/M/B plus the truthful ratio, and retain the exact count in accessibility |

Weekly and 5h are healthy at 50% remaining, warning from 20% through 49%, and critical below 20%. Today is healthy through 50% of peak, warning above 50% through 80%, and critical above 80%. Restrained system green/orange/red colors are centralized behind `PetRingPresentationPolicy`. Stale arcs also use reduced opacity, dashes, visible text, and per-ring accessibility values.

Auto prefers the current unique wide `AXSystemDialog` activity surface and falls back to the earlier unique wide `AXDialog` form. Its above/below comparison uses the calibrated visual Pet center rather than the padded raw AX midpoint. Activity above that center leaves the top open; activity below leaves the bottom open. No activity uses one fixed default, and ambiguous geometry retains the previous direction. Direction changes are debounced and update only start/sweep angles; target selection, panel placement, offset, and fallback do not change.

DEBUG builds expose Auto, Force Gap Above, and Force Gap Below previews. The override changes only effective arc and mirrored label angles and is not written to preferences. Production remains Auto.

Pet movement uses an immediate main-run-loop AX callback path and one latest-value display-linked follower. A notification wakes the follower; while active it re-reads only the already-selected coincident Pet core frames and stops after four unchanged refreshes, without enumerating windows or changing target selection. A missing event-path snapshot is retried after `16 ms`; dialog orientation alone retains a `180 ms` debounce. Medium continuous moves apply only the newest target exactly; they do not replay intermediate samples or add a multi-frame chase. Moves within `1.25 pt` snap immediately, as do first attachment, Wake/target replacement, Reduce Motion, and jumps of at least `96 pt`. A bounded recovery health check detects Codex process replacement and silent selected-frame changes, rejects stale generations, and snaps to the newest attachment without needing a first message event. Synchronous macOS Accessibility attribute freshness remains an external latency limit.

## Preservation and boundaries

Compact and Expanded cards are not deleted. Expanded Account Usage rows, scrolling, non-activation, calibration behavior, and card mouse policies remain available outside Pet. `ApplicationCoordinator` is still the only bridge-state stream consumer and owns both card and ring presentation values.

M7 adds no OpenAI, ChatGPT, or Codex Pet artwork; no screenshots, OCR, Screen Recording, settings/details window, analytics, telemetry, or new protocol method. It does not add themes, glow, particles, pulse, sound, or decorative animation. M8 owns advanced polish beyond the fixed M7 policy, themes, decorative low-usage styling, glow, motion preferences, and decorative animations.

## Verification matrix

| Gate | Current result |
| --- | --- |
| Debug product compilation | PASS |
| Target/surface transitions, offset persistence, orientation, movement following, and fallback restoration | PASS — focused 106-test M7 bundle |
| Ring geometry, transparent-center contract, no card background, shadow, and click policy | PASS — deterministic |
| Three independent rings, thresholds, Today denominator, and component freshness | PASS — deterministic |
| M0-M6 regression and complete Swift suite | PASS — 160 Swift tests executed: 159 passed and one designed local-only authenticated Codex integration smoke skipped; 14 retained M0 tests passed |
| Debug and universal Release bundle | PASS — Debug plus arm64/x86_64 Release |
| Source, privacy, generated-project, and bundle boundaries | PASS |
| Draft PR CI | PASS — latest Protocol evidence and macOS application jobs on the complete M7 head; PR remains Draft |
| M7 smoke | PASS — fast independent movement with saved visual offset and bounded selected-frame sampling, Tuck Away/Wake recovery, explicit fallback restoration, non-activation, Quit, observer shutdown, and owned app-server cleanup directly observed |
| Visible Pet containment and calibrated center | PASS — user-operated calibration and restart/idle/position checks confirmed the Pet remains inside the transparent center without a first-message trigger |
| Final capsule-label screenshot | PASS — Today / optional 5h / Weekly ordering, fixed identity dots, neutral connectors, concentric arcs, mirrored placement, transparent center, and no rectangle accepted |
| Independent review | PASS — no unresolved review threads |

M7 is closed with PASS. M8 — Visual Polish, Themes & Motion — is the next milestone and has not started. The Draft PR remains unmerged, and M7 closeout does not authorize M8.
